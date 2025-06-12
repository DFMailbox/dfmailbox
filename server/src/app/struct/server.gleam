import app/address
import app/handle/decoders
import ed25519/public_key
import ed25519/signature
import gleam/dynamic/decode
import gleam/json
import youid/uuid

pub type IdentifyInstanceBody {
  IdentifyInstanceBody(
    public_key: public_key.PublicKey,
    address: address.InstanceAddress,
    challenge: uuid.Uuid,
  )
}

pub fn identify_instance_body_to_json(
  identify_instance_body: IdentifyInstanceBody,
) -> json.Json {
  let IdentifyInstanceBody(public_key:, address:, challenge:) =
    identify_instance_body
  json.object([
    #("public_key", public_key |> public_key.to_base64() |> json.string),
    #("address", address.to_string(address) |> json.string),
    #("challenge", challenge |> uuid.to_string |> json.string),
  ])
}

pub fn identify_instance_body_decoder() -> decode.Decoder(IdentifyInstanceBody) {
  use public_key <- decode.field("public_key", decoders.decode_public_key())
  use address <- decode.field("address", address.decode_address())
  use challenge <- decode.field("challenge", decoders.decode_uuid())
  decode.success(IdentifyInstanceBody(public_key:, address:, challenge:))
}

pub type IdentifyInstanceResponse {
  IdentifyInstanceResponse(
    identity_key: String,
    public_key: public_key.PublicKey,
    signature: signature.Signature,
    address: address.InstanceAddress,
  )
}

pub fn identify_instance_response_decoder() -> decode.Decoder(
  IdentifyInstanceResponse,
) {
  use identity_key <- decode.field("identity_key", decode.string)
  use public_key <- decode.field("public_key", decoders.decode_public_key())
  use signature <- decode.field("signature", decoders.decode_signature())
  use address <- decode.field("address", address.decode_address())
  decode.success(IdentifyInstanceResponse(
    identity_key:,
    public_key:,
    signature:,
    address:,
  ))
}

pub fn encode_identify_instance_response(
  identify_instance_response: IdentifyInstanceResponse,
) -> json.Json {
  let IdentifyInstanceResponse(identity_key:, public_key:, signature:, address:) =
    identify_instance_response
  json.object([
    #("identity_key", json.string(identity_key)),
    #("public_key", json.string(public_key |> public_key.to_base64_url())),
    #("signature", json.string(signature |> signature.to_base64())),
    #("address", address |> address.to_string |> json.string),
  ])
}

pub type SigningResponse {
  SigningResponse(
    public_key: public_key.PublicKey,
    signature: signature.Signature,
    address: address.InstanceAddress,
  )
}

pub fn signing_response_to_json(signing_response: SigningResponse) -> json.Json {
  let SigningResponse(public_key:, signature:, address:) = signing_response
  json.object([
    #("public_key", public_key |> public_key.to_base64_url |> json.string),
    #("signature", signature |> signature.to_base64 |> json.string),
    #("address", address |> address.to_string |> json.string),
  ])
}

pub fn signing_response_decoder() -> decode.Decoder(SigningResponse) {
  use public_key <- decode.field("public_key", decoders.decode_public_key())
  use signature <- decode.field("signature", decoders.decode_signature())
  use address <- decode.field("address", address.decode_address())
  decode.success(SigningResponse(public_key:, signature:, address:))
}
