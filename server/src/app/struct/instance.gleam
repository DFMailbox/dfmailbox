import app/address
import app/handle/decoders
import ed25519/public_key
import gleam/dynamic/decode

pub type IntroduceInstanceBody {
  IntroduceInstanceBody(
    public_key: public_key.PublicKey,
    address: address.InstanceAddress,
  )
}

pub fn introduce_instance_body_decoder() -> decode.Decoder(
  IntroduceInstanceBody,
) {
  use public_key <- decode.field("public_key", decoders.decode_public_key())
  use address <- decode.field("address", address.decode_address())
  decode.success(IntroduceInstanceBody(public_key:, address:))
}
