import app/address
import app/decoders
import ed25519/public_key
import ed25519/signature
import gleam/bit_array
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/pair
import gleam/result
import gleam/time/timestamp
import json_value

pub fn parse_json_handshake_msg(data: String) {
  json.parse(data, handshake_message_decoder())
}

pub fn parse_json_hello_msg(data: String) {
  json.parse(data, hello_decoder())
}

pub fn parse_json_message(data: String) {
  use parsed <- result.try(json.parse(data, decode.dynamic))
  let receive_decoder = {
    use kind <- decode.field("type", decode.string)
    use id <- decode.field("id", decode.int)
    case kind == "r" {
      True -> decode.success(id)
      False -> decode.failure(0, "ReceiveType")
    }
  }

  decode.one_of(send_message_decoder(), [
    receive_decoder
    |> decode.map(fn(id) {
      let assert Ok(json_value.Object(dict)) = json_value.parse(data)
      Response(
        id,
        dict
          |> dict.drop(["type", "id"])
          |> json_value.Object,
      )
    }),
  ])
  |> decode.run(parsed, _)
  |> result.map_error(json.UnableToDecode)
}

pub type Protocol {
  JsonProtocol
  MsgPackProtocol
}

pub type SendMessage {
  SendMessage(
    id: Int,
    from: Int,
    to_plot: Int,
    to_key: String,
    sent_at: timestamp.Timestamp,
    data: List(String),
  )
}

pub type Message {
  Send(SendMessage)
  Response(id: Int, content: json_value.JsonValue)
}

fn send_message_decoder() -> decode.Decoder(Message) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "s" -> {
      use id <- decode.field("id", decode.int)
      use from <- decode.field("from", decode.int)
      use to_plot <- decode.field("to_plot", decode.int)
      use to_key <- decode.field("to_key", decode.string)
      use sent_at <- decode.field(
        "sent_at",
        decode.map(decode.int, timestamp.from_unix_seconds),
      )
      use data <- decode.field("data", decode.list(decode.string))
      decode.success(
        SendMessage(id:, from:, to_plot:, to_key:, sent_at:, data:) |> Send,
      )
    }
    _ -> decode.failure(Response(id: 0, content: json_value.Null), "Message")
  }
}

pub type Hello {
  Hello(
    host: address.InstanceAddress,
    pubkey: public_key.PublicKey,
    protocol: ProtocolSetting,
  )
}

pub fn hello_decoder() -> decode.Decoder(Hello) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "hello" -> {
      use host <- decode.field("host", address.decode_address())
      use pubkey <- decode.field("pubkey", decoders.decode_public_key())
      use protocol <- decode.field("protocol", federation_protocol_decoder())
      decode.success(Hello(host:, pubkey:, protocol:))
    }
    _ ->
      decode.failure(
        Hello(
          host: address.InstanceAddress(host: "", port: option.None),
          pubkey: public_key.default(),
          protocol: ProtocolSetting(0, 0),
        ),
        "msg.Hello",
      )
  }
}

pub type Handshake {
  HostChallenge(token: String)
  HostReady(token: String)
  HostVerified
  AuthChallenge(nonce: BitArray, expires_at: timestamp.Timestamp)
  AuthResponse(nonce: BitArray, sig: signature.Signature)
  AuthVerified
}

pub fn hello_to_json(hello: Hello) {
  let Hello(host:, pubkey:, protocol:) = hello
  json.object([
    #("type", json.string("hello")),
    #("host", address.instance_address_to_json(host)),
    #("pubkey", pubkey |> public_key.to_base64 |> json.string),
    #("protocol", federation_protocol_to_json(protocol)),
  ])
}

pub fn handshake_to_json(handshake: Handshake) -> json.Json {
  case handshake {
    HostChallenge(token:) ->
      json.object([
        #("type", json.string("host_challenge")),
        #("token", json.string(token)),
      ])
    HostReady(token:) ->
      json.object([
        #("type", json.string("host_ready")),
        #("token", json.string(token)),
      ])
    HostVerified ->
      json.object([
        #("type", json.string("host_verified")),
      ])
    AuthChallenge(nonce:, expires_at:) ->
      json.object([
        #("type", json.string("auth_challenge")),
        #("nonce", json.string(nonce |> bit_array.base64_encode(True))),
        #(
          "expires_at",
          expires_at
            |> timestamp.to_unix_seconds_and_nanoseconds
            |> pair.first
            |> json.int,
        ),
      ])
    AuthResponse(nonce:, sig:) ->
      json.object([
        #("type", json.string("auth_response")),
        #("nonce", json.string(nonce |> bit_array.base64_encode(True))),
        #("sig", sig |> signature.to_base64 |> json.string),
      ])
    AuthVerified ->
      json.object([
        #("type", json.string("auth_verified")),
      ])
  }
}

pub fn handshake_message_decoder() -> decode.Decoder(Handshake) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "host_challenge" -> {
      use token <- decode.field("token", decode.string)
      decode.success(HostChallenge(token:))
    }
    "host_ready" -> {
      use token <- decode.field("token", decode.string)
      decode.success(HostReady(token:))
    }
    "host_verified" -> decode.success(HostVerified)
    "auth_challenge" -> {
      use nonce <- decode.field("nonce", decoders.decode_bit_array())
      use expires_at <- decode.field(
        "expires_at",
        decode.map(decode.int, timestamp.from_unix_seconds),
      )
      decode.success(AuthChallenge(nonce:, expires_at:))
    }
    "auth_response" -> {
      use nonce <- decode.field("nonce", decoders.decode_bit_array())
      use sig <- decode.field("sig", decoders.decode_signature())
      decode.success(AuthResponse(nonce:, sig:))
    }
    "auth_verified" -> decode.success(AuthVerified)
    _ -> decode.failure(HostVerified, "HandshakeMessage")
  }
}

pub type ProtocolSetting {
  ProtocolSetting(send_message_max_length: Int, receive_max_length: Int)
}

fn federation_protocol_to_json(
  federation_protocol: ProtocolSetting,
) -> json.Json {
  let ProtocolSetting(send_message_max_length:, receive_max_length:) =
    federation_protocol
  json.object([
    #("send_message_max_length", json.int(send_message_max_length)),
    #("receive_max_length", json.int(receive_max_length)),
  ])
}

fn federation_protocol_decoder() -> decode.Decoder(ProtocolSetting) {
  use send_message_max_length <- decode.field(
    "send_message_max_length",
    decode.int,
  )
  use receive_max_length <- decode.field("receive_max_length", decode.int)
  decode.success(ProtocolSetting(send_message_max_length:, receive_max_length:))
}
