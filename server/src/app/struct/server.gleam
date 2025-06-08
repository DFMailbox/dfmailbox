import app/handle/decoders
import app/instance
import ed25519/public_key
import ed25519/signature
import gleam/dynamic/decode
import gleam/json
import youid/uuid

pub type IdentifyInstanceBody {
  IdentifyInstanceBody(
    public_key: public_key.PublicKey,
    host: instance.InstanceDomain,
    challenge: uuid.Uuid,
  )
}

pub fn identify_instance_body_to_json(
  identify_instance_body: IdentifyInstanceBody,
) -> json.Json {
  let IdentifyInstanceBody(public_key:, host:, challenge:) =
    identify_instance_body
  json.object([
    #("public_key", public_key |> public_key.to_base64() |> json.string),
    #("host", instance.instance_domain_to_json(host)),
    #("challenge", challenge |> uuid.to_string |> json.string),
  ])
}

pub fn identify_instance_body_decoder() -> decode.Decoder(IdentifyInstanceBody) {
  use public_key <- decode.field("public_key", decoders.decode_public_key())
  use host <- decode.field("host", instance.decode_instance())
  use challenge <- decode.field("challenge", decoders.decode_uuid())
  decode.success(IdentifyInstanceBody(public_key:, host:, challenge:))
}

pub type IdentifyInstanceResponse {
  IdentifyInstanceResponse(
    identity_key: String,
    public_key: public_key.PublicKey,
    signature: signature.Signature,
  )
}

pub fn identify_instance_response_decoder() -> decode.Decoder(
  IdentifyInstanceResponse,
) {
  use identity_key <- decode.field("identity_key", decode.string)
  use public_key <- decode.field("public_key", decoders.decode_public_key())
  use signature <- decode.field("signature", decoders.decode_signature())
  decode.success(IdentifyInstanceResponse(
    identity_key:,
    public_key:,
    signature:,
  ))
}

pub fn encode_identify_instance_response(
  identify_instance_response: IdentifyInstanceResponse,
) -> json.Json {
  let IdentifyInstanceResponse(identity_key:, public_key:, signature:) =
    identify_instance_response
  json.object([
    #("identity_key", json.string(identity_key)),
    #("server_key", json.string(public_key |> public_key.to_base64_url())),
    #("signature", json.string(signature |> signature.to_base64())),
  ])
}

pub type SigningResponse {
  SigningResponse(
    server_key: public_key.PublicKey,
    signature: signature.Signature,
  )
}

pub fn encode_signing_response(signing_response: SigningResponse) -> json.Json {
  let SigningResponse(server_key:, signature:) = signing_response
  json.object([
    #("server_key", json.string(server_key |> public_key.to_base64_url())),
    #("signature", json.string(signature |> signature.to_base64())),
  ])
}

pub fn signing_response_decoder() -> decode.Decoder(SigningResponse) {
  use server_key <- decode.field("server_key", decoders.decode_public_key())
  use signature <- decode.field("signature", decoders.decode_signature())
  decode.success(SigningResponse(server_key:, signature:))
}
