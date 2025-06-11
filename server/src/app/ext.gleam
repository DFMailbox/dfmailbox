import app/address
import app/handle/helper
import app/struct/server
import ed25519/public_key
import ed25519/signature
import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import youid/uuid

pub fn ping_sign(
  address: address.InstanceAddress,
) -> Result(public_key.PublicKey, PingInstanceError) {
  let uuid = uuid.v4()
  let challenge = address.generate_challenge(address, uuid)

  let req =
    address.request(address)
    |> request.set_path("/v0/federation/instance")
    |> request.set_query([#("challenge", uuid |> uuid.to_string)])
    |> request.set_method(http.Get)
  use res <- result.try(httpc.send(req) |> result.map_error(HttpError))
  use <- bool.guard(
    res.status != 200,
    Error(UnexpectedStatus(res.status, res.body)),
  )

  use json <- result.try(
    json.parse(res.body, server.signing_response_decoder())
    |> result.map_error(JsonDecodeError(_, res.body)),
  )
  let valid =
    signature.validate_signature(json.signature, challenge, json.public_key)
  use <- bool.guard(!valid, Error(MismatchedKey(json.public_key)))
  Ok(json.public_key)
}

pub type PingInstanceError {
  HttpError(httpc.HttpError)
  JsonDecodeError(json.DecodeError, String)
  UnexpectedStatus(Int, String)
  MismatchedKey(public_key.PublicKey)
  Other(String)
}

pub fn serialize_ping_error(err: PingInstanceError) {
  case err {
    HttpError(err) -> string.inspect(err)
    JsonDecodeError(err, body) -> {
      body
      <> " with error "
      <> {
        case err {
          json.UnableToDecode(err) ->
            list.map(err, helper.decode_error_format)
            |> json.array(of: json.string)
            |> json.to_string
          err -> string.inspect(err)
        }
      }
    }
    MismatchedKey(key) -> "Invalid key: " <> public_key.to_base64_url(key)
    UnexpectedStatus(code, body) ->
      "Invalid code " <> int.to_string(code) <> " with body " <> body
    Other(str) -> str
  }
}

pub fn request_key_exchange(
  public_key: public_key.PublicKey,
  address: address.InstanceAddress,
  my_address: address.InstanceAddress,
) {
  let uuid = uuid.v4()
  let challenge = address.generate_challenge(address, uuid)
  let body =
    server.IdentifyInstanceBody(
      public_key:,
      address: my_address,
      challenge: uuid,
    )
  let req =
    address.request(address)
    |> request.set_path("/v0/federation/instance")
    |> request.set_method(http.Post)
    |> request.prepend_header("content-type", "application/json")
    |> request.set_body(
      body |> server.identify_instance_body_to_json |> json.to_string,
    )
  use res <- result.try(httpc.send(req) |> result.map_error(HttpError))
  use <- bool.guard(
    res.status != 200,
    Error(UnexpectedStatus(res.status, res.body)),
  )

  use json <- result.try(
    json.parse(res.body, server.identify_instance_response_decoder())
    |> result.map_error(JsonDecodeError(_, res.body)),
  )
  use <- bool.guard(
    json.address != address,
    Error(Other(
      "Expected address "
      <> address.to_string(json.address)
      <> " got address "
      <> address.to_string(address),
    )),
  )
  let valid =
    signature.validate_signature(json.signature, challenge, json.public_key)
  use <- bool.guard(!valid, Error(MismatchedKey(json.public_key)))

  crypto.hash(crypto.Sha256, json.identity_key |> bit_array.from_string)
  |> Ok
}
