import ewe
import fed/msg
import gleam/float
import gleam/json
import gleam/time/timestamp

pub type ProtocolError {
  HostAlreadyVerified
  /// The host is ready, ignoring token change
  HostReady
  AuthAlreadyVerified
  AuthResponded
  AuthExpired(at: timestamp.Timestamp)
}

fn protocol_error_to_json(protocol_error: ProtocolError) -> json.Json {
  case protocol_error {
    HostAlreadyVerified ->
      json.object([
        #("type", json.string("host_already_verified")),
      ])
    HostReady ->
      json.object([
        #("type", json.string("host_ready")),
      ])
    AuthAlreadyVerified ->
      json.object([
        #("type", json.string("auth_already_verified")),
      ])
    AuthResponded ->
      json.object([
        #("type", json.string("auth_responded")),
      ])
    AuthExpired(at:) ->
      json.object([
        #("type", json.string("auth_expired")),
        #("at", timestamp.to_unix_seconds(at) |> float.round |> json.int),
      ])
  }
}

pub fn send(conn, error: ProtocolError, protocol: msg.Protocol) {
  let assert Ok(Nil) = case protocol {
    msg.JsonProtocol ->
      protocol_error_to_json(error)
      |> json.to_string()
      |> ewe.send_text_frame(conn, _)

    msg.MsgPackProtocol -> todo as "not implemented"
  }
  Nil
}
