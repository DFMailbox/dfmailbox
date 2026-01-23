import app/address
import app/ctx
import ed25519/public_key
import ed25519/signature
import ewe
import fed/error
import fed/msg.{JsonProtocol, MsgPackProtocol}
import gleam/bool
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import gleam/string
import gleam/time/timestamp
import logging
import pog
import sql

pub const json_protocol_name = "json.v1"

pub const msgpack_protocol_name = "json.v1"

pub fn handle_ewe(
  req: request.Request(ewe.Connection),
  ctx: ctx.Context,
) -> ewe.Response {
  case request.path_segments(req) {
    ["federation"] ->
      case
        {
          use protocols <- result.try(request.get_header(
            req,
            "Sec-WebSocket-Protocol",
          ))

          use selected <- result.try(
            string.split(protocols, ",")
            |> list.map(string.trim)
            |> list.fold(None, fn(acc, it) {
              let identified = case it {
                it if it == json_protocol_name -> Some(msg.JsonProtocol)
                it if it == msgpack_protocol_name -> Some(MsgPackProtocol)
                _ -> None
              }
              case acc {
                Some(proto) ->
                  case proto {
                    MsgPackProtocol -> MsgPackProtocol
                    JsonProtocol ->
                      case identified {
                        Some(MsgPackProtocol) -> MsgPackProtocol
                        _ -> JsonProtocol
                      }
                  }
                  |> Some
                None -> identified
              }
            })
            |> option.to_result(Nil),
          )

          ewe.upgrade_websocket(
            req,
            on_init: fn(conn, selector) {
              logging.log(logging.Info, "WebSocket connection opened")

              let client = process.new_subject()

              let state = WebsocketState(client:, phase: AwaitHello)
              let selector = process.select(selector, client)

              case selected {
                JsonProtocol -> {
                  let _ =
                    ewe.send_text_frame(
                      conn,
                      msg.Hello(
                        ctx.instance,
                        public_key.derive_key(ctx.private_key),
                        msg.ProtocolSetting(1, 1),
                      )
                        |> msg.hello_to_json
                        |> json.to_string,
                    )
                  Nil
                }
                MsgPackProtocol -> todo as "messagepack hasn't been implemented"
              }

              #(state, selector)
            },
            handler: handle_generic(ctx, selected),
            on_close: fn(_conn, state) {
              let assert Ok(_pid) = process.subject_owner(state.client)
              logging.log(logging.Info, "WebSocket connection closed")
            },
          )
          |> Ok
        }
      {
        Ok(it) -> it
        Error(Nil) ->
          response.new(400)
          |> response.set_body(ewe.TextData("No supported protocols"))
      }

    _ ->
      response.new(404)
      |> response.set_body(ewe.Empty)
  }
}

pub type DfmWsMessage(msg) {
  Incoming(msg)
  User(Broadcast)
}

type Handler =
  fn(ewe.WebsocketConnection, WebsocketState, ewe.WebsocketMessage(Broadcast)) ->
    ewe.WebsocketNext(WebsocketState, Broadcast)

/// Looks at the current state and does the things nessesary
///
/// ex. Send auth_challenge
fn do_tasks(
  conn: ewe.WebsocketConnection,
  state: WebsocketState,
  ctx: ctx.Context,
  selected: msg.Protocol,
) -> WebsocketState {
  todo
}

fn handle_generic(ctx: ctx.Context, selected: msg.Protocol) -> Handler {
  case selected {
    JsonProtocol -> fn(
      conn: ewe.WebsocketConnection,
      state: WebsocketState,
      msg: ewe.WebsocketMessage(Broadcast),
    ) {
      // TODO: Add exception handling to close the request
      case msg {
        ewe.Binary(_) ->
          ewe.send_close_frame(
            conn,
            ewe.InvalidPayloadData(
              json_protocol_name <> " only supports text data",
            ),
          )
        ewe.Text(text) ->
          case state.phase {
            AwaitHello -> {
              case msg.parse_json_hello_msg(text) {
                Ok(msg) -> handle_hello(conn, state, Incoming(msg), ctx)
                Error(err) ->
                  ewe.send_close_frame(
                    conn,
                    ewe.PolicyViolation("Failed to parse introduction message"),
                  )
              }
            }
            Handshake(_) -> {
              case msg.parse_json_handshake_msg(text) {
                Ok(msg) ->
                  handle_handshake(conn, state, Incoming(msg), ctx, selected)
                Error(err) ->
                  ewe.send_close_frame(
                    conn,
                    ewe.InvalidPayloadData(
                      "Json decode error " <> string.inspect(err),
                    ),
                  )
              }
            }
            Messages(_, _, _, _) -> todo
          }
        ewe.User(d) ->
          case state.phase {
            AwaitHello -> handle_hello(conn, state, User(d), ctx)
            Handshake(_) ->
              handle_handshake(conn, state, User(d), ctx, selected)
            Messages(_, _, _, _) -> todo
          }
      }
    }
    MsgPackProtocol -> todo as "messagepack hasn't been implemented"
  }
}

fn handle_hello(
  conn: ewe.WebsocketConnection,
  state: WebsocketState,
  msg: DfmWsMessage(msg.Hello),
  ctx: ctx.Context,
) -> ewe.WebsocketNext(WebsocketState, Broadcast) {
  case msg {
    Incoming(msg.Hello(host:, pubkey:, protocol:)) -> {
      let assert Ok(pog.Returned(_c, rows)) =
        sql.get_instance(ctx.conn, public_key.serialize_to_bits(pubkey))
      let first = list.first(rows)

      use <- bool.guard(
        case first {
          Ok(sql.GetInstanceRow(None)) -> True
          _ -> False
        },
        // TODO: Make a codes system for this protocol
        ewe.send_close_frame(conn, ewe.CustomCloseCode(4000, "Compromised key")),
      )

      let host_challenged = case first {
        Ok(row) -> {
          let assert option.Some(addr) = row.address
          let assert Ok(addr) = address.parse(addr)
          case addr == host {
            True -> HostRemembered
            False -> HostAwaiting
          }
        }
        Error(Nil) -> HostAwaiting
      }

      WebsocketState(
        state.client,
        Handshake(HandshakeState(
          addr: host,
          pubkey:,
          protocol:,
          auth_challenge: AuthAwaiting,
          auth_challenged: AuthAwaiting,
          host_challenge: HostAwaiting,
          host_challenged:,
        )),
      )
      |> ewe.websocket_continue()
    }
    User(message) -> {
      logging.log(
        logging.Info,
        "Message "
          <> string.inspect(message)
          <> " has been sent during AwaitHello",
      )
      ewe.send_close_frame(conn, ewe.InternalError("Bad state"))
    }
  }
}

fn handle_handshake(
  conn: ewe.WebsocketConnection,
  state: WebsocketState,
  msg: DfmWsMessage(msg.Handshake),
  ctx: ctx.Context,
  protocol: msg.Protocol,
) -> ewe.WebsocketNext(WebsocketState, Broadcast) {
  let assert Handshake(handshake_phase) = state.phase
  case msg {
    Incoming(msg) -> {
      let state = case msg {
        msg.AuthChallenge(nonce:, expires_at:) ->
          {
            let auth_challenged = handshake_phase.auth_challenged
            case auth_challenged {
              AuthChallenged(_, _) | AuthAwaiting -> {
                HandshakeState(..handshake_phase, auth_challenged:)
                |> Handshake
                |> WebsocketState(client: state.client, phase: _)
              }
              AuthVerified -> {
                error.send(conn, error.AuthAlreadyVerified, protocol)
                state
              }
            }
          }
          |> Ok
        msg.AuthResponse(nonce:, sig:) -> {
          let auth_challenge = handshake_phase.auth_challenge
          case auth_challenge {
            AuthAwaiting -> panic as "invalid"
            AuthChallenged(nonce:, expires_at:) -> {
              use <- bool.lazy_guard(
                case timestamp.compare(timestamp.system_time(), expires_at) {
                  order.Eq | order.Gt -> True
                  order.Lt -> False
                },
                fn() {
                  error.send(conn, error.AuthExpired(expires_at), protocol)
                  HandshakeState(
                    ..handshake_phase,
                    auth_challenge: AuthAwaiting,
                  )
                  |> Handshake
                  |> WebsocketState(client: state.client, phase: _)
                  |> Ok
                },
              )

              use <- bool.guard(
                !signature.validate_signature(
                  sig,
                  nonce,
                  handshake_phase.pubkey,
                ),
                Error(ewe.PolicyViolation("Peer failed to verify pubkey")),
              )
              HandshakeState(..handshake_phase, auth_challenge: AuthVerified)
              |> Handshake
              |> WebsocketState(client: state.client, phase: _)
              |> Ok
            }
            AuthVerified -> {
              error.send(conn, error.AuthAlreadyVerified, protocol)
              Ok(state)
            }
          }
        }
        msg.AuthVerified -> {
          // Just take it, auth_challenged shouldn't need to be protected with that much scrutiny
          HandshakeState(..handshake_phase, auth_challenged: AuthVerified)
          |> Handshake
          |> WebsocketState(client: state.client, phase: _)
          |> Ok
        }
        msg.HostChallenge(token:) ->
          {
            let host_challenged = handshake_phase.host_challenged
            case host_challenged {
              HostAwaiting | HostChallenged(_token) -> {
                HandshakeState(..handshake_phase, host_challenged:)
                |> Handshake
                |> WebsocketState(client: state.client, phase: _)
              }
              HostSettingUp(_) | HostReady(_) -> {
                error.send(conn, error.HostReady, protocol)
                state
              }
              HostVerified | HostRemembered -> {
                error.send(conn, error.HostAlreadyVerified, protocol)
                state
              }
            }
          }
          |> Ok
        msg.HostReady(token:) ->
          {
            let host_challenge = handshake_phase.host_challenge
            case handshake_phase.host_challenge {
              HostAwaiting -> panic as "todo error"
              HostChallenged(token: curr_token) -> {
                assert curr_token == token
                // TODO: Spin up another process that will fetch the url and respond within 5 seconds.
                // This process will respond by sending in a message to the websocket actor with the Broadcast type

                HandshakeState(..handshake_phase, host_challenge:)
                |> Handshake
                |> WebsocketState(client: state.client, phase: _)
              }
              HostSettingUp(_) | HostReady(_) ->
                panic as "todo error already ready"
              HostRemembered | HostVerified -> {
                error.send(conn, error.HostAlreadyVerified, protocol)
                state
              }
            }
          }
          |> Ok
        msg.HostVerified -> {
          // Just take it, host_challenged shouldn't need to be protected with that much scrutiny
          HandshakeState(..handshake_phase, host_challenged: HostVerified)
          |> Handshake
          |> WebsocketState(client: state.client, phase: _)
          |> Ok
        }
      }
      case state {
        Ok(state) -> {
          let state = do_tasks(conn, state, ctx, protocol)
          ewe.websocket_continue(state)
        }
        Error(err) -> ewe.send_close_frame(conn, err)
      }
    }
    User(_) ->
      ewe.send_close_frame(conn, ewe.PolicyViolation("Introduce yourself"))
  }
}

type WebsocketState {
  WebsocketState(client: Subject(Broadcast), phase: WebsocketPhase)
}

type HandshakeState {
  HandshakeState(
    addr: address.InstanceAddress,
    pubkey: public_key.PublicKey,
    protocol: msg.ProtocolSetting,
    /// The host challenge state of the peer.
    /// MUST be set with SCRUTINY
    host_challenge: HostChallengePhase,
    /// The host challenge state of this server
    host_challenged: HostChallengePhase,
    /// The auth challenge state of the peer.
    /// MUST be set with SCRUTINY
    auth_challenge: AuthChallengePhase,
    /// The auth challenge state of this server
    auth_challenged: AuthChallengePhase,
  )
}

type WebsocketPhase {
  AwaitHello
  Handshake(HandshakeState)
  Messages(
    addr: address.InstanceAddress,
    pubkey: public_key.PublicKey,
    pending: dict.Dict(Int, msg.SendMessage),
    protocol: msg.ProtocolSetting,
  )
}

type HostChallengePhase {
  HostRemembered
  HostAwaiting
  HostChallenged(token: String)
  HostSettingUp(token: String)
  HostReady(token: String)
  HostVerified
}

type AuthChallengePhase {
  AuthAwaiting
  AuthChallenged(nonce: BitArray, expires_at: timestamp.Timestamp)
  AuthVerified
}

pub type Broadcast
