import app/address
import app/struct/server
import ed25519/public_key
import ed25519/signature
import gleam/bool
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import youid/uuid

/// Hit another instance's `GET /v0/federation/instance`
pub fn ping_sign(
  address: address.InstanceAddress,
) -> Result(#(public_key.PublicKey, address.InstanceAddress), PingInstanceError) {
  let uuid = uuid.v4()
  let challenge = address.generate_challenge(address, uuid)

  let req =
    address.request(address)
    |> request.set_path("/v0/federation/instance")
    |> request.set_query([#("challenge", uuid |> uuid.to_string)])
    |> request.set_method(http.Get)
  use res <- result.try(
    httpc.send(req) |> result.map_error(InstanceUnreachable),
  )
  use <- bool.guard(
    res.status != 200,
    Error(UnexpectedStatus(res.status, req, res)),
  )

  use json <- result.try(
    json.parse(res.body, server.signing_response_decoder())
    |> result.map_error(JsonDecodeError(_, req, res)),
  )
  let valid =
    signature.validate_signature(json.signature, challenge, json.public_key)
  use <- bool.guard(!valid, Error(ChallengeFailed(req, res)))
  Ok(#(json.public_key, json.address))
}

pub type PingInstanceError {
  InstanceUnreachable(httpc.HttpError)
  JsonDecodeError(
    json.DecodeError,
    request.Request(String),
    response.Response(String),
  )
  UnexpectedStatus(Int, request.Request(String), response.Response(String))
  ChallengeFailed(request.Request(String), response.Response(String))
}

pub fn ping_instance_error_to_json(error: PingInstanceError) {
  case error {
    InstanceUnreachable(err) -> {
      json.object([
        #("error", json.string("instance_unreachable")),
        #("error_message", err |> string.inspect |> json.string),
      ])
    }
    JsonDecodeError(err_msg, req, res) -> {
      json.object([
        #("error", json.string("non_compliance")),
        #(
          "error_message",
          ["Json parse error: ", err_msg |> string.inspect]
            |> append_req_res(req, res)
            |> string.join("")
            |> json.string,
        ),
      ])
    }
    UnexpectedStatus(code, req, res) -> {
      json.object([
        #("error", json.string("non_compliance")),
        #(
          "error_message",
          ["Incorrect status code: ", code |> int.to_string]
            |> append_req_res(req, res)
            |> string.join("")
            |> json.string,
        ),
      ])
    }
    ChallengeFailed(req, res) -> {
      json.object([
        #("error", json.string("non_compliance")),
        #(
          "error_message",
          ["Signing challenge failed"]
            |> append_req_res(req, res)
            |> string.join("")
            |> json.string,
        ),
      ])
    }
  }
}

fn append_req_res(list, req, res) -> List(String) {
  // this is fine because
  // 1. its a small list
  // 2. Rarely called
  list.append(list, [
    "\nRequest: ",
    req |> string.inspect,
    "\nResponse: ",
    res |> string.inspect,
  ])
}
