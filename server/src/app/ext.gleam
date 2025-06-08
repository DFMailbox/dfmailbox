import app/instance
import app/struct/server
import ed25519/public_key
import ed25519/signature
import gleam/bit_array
import gleam/bool
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/result
import youid/uuid

pub fn ping_sign(
  domain: instance.InstanceDomain,
) -> Result(public_key.PublicKey, PingInstanceError) {
  let uuid = uuid.v4()
  let challenge =
    bit_array.append(instance.to_bit_array(domain), uuid.to_bit_array(uuid))

  let req =
    instance.request(domain)
    |> request.set_path("/v0/federation/instance")
    |> request.set_query([#("challenge", uuid |> uuid.to_string)])
  use res <- result.try(httpc.send(req) |> result.map_error(HttpError))
  use <- bool.guard(res.status != 200, Error(UnexpectedStatus(res.status)))

  use json <- result.try(
    json.parse(res.body, server.signing_response_decoder())
    |> result.map_error(JsonDecodeError),
  )
  let valid =
    signature.validate_signature(json.signature, challenge, json.server_key)
  use <- bool.guard(!valid, Error(MismatchedKey(json)))
  Ok(json.server_key)
}

pub type PingInstanceError {
  HttpError(httpc.HttpError)
  JsonDecodeError(json.DecodeError)
  UnexpectedStatus(Int)
  MismatchedKey(server.SigningResponse)
}
