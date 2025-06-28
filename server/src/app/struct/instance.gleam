import app/address
import app/handle/decoders
import ed25519/public_key
import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type IntroduceInstanceBody {
  IntroduceInstanceBody(
    public_key: public_key.PublicKey,
    address: address.InstanceAddress,
    update: Bool,
  )
}

pub fn introduce_instance_body_decoder() -> decode.Decoder(
  IntroduceInstanceBody,
) {
  use public_key <- decode.field("public_key", decoders.decode_public_key())
  use address <- decode.field("address", address.decode_address())
  use update <- decode.optional_field("update", False, decode.bool)
  decode.success(IntroduceInstanceBody(public_key:, address:, update:))
}

pub type AddressKeyPair {
  AddressKeyPair(
    address: option.Option(address.InstanceAddress),
    public_key: public_key.PublicKey,
  )
}

pub fn address_key_pair_to_json(address_key_pair: AddressKeyPair) -> json.Json {
  let AddressKeyPair(address:, public_key:) = address_key_pair
  json.object([
    #("address", address |> json.nullable(address.instance_address_to_json)),
    #("public_key", public_key |> public_key.to_base64_url |> json.string),
  ])
}
