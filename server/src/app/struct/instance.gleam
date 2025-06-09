import app/handle/decoders
import app/instance
import ed25519/public_key
import gleam/dynamic/decode

pub type IntroduceInstanceBody {
  IntroduceInstanceBody(
    public_key: public_key.PublicKey,
    host: instance.InstanceDomain,
  )
}

pub fn introduce_instance_body_decoder() -> decode.Decoder(
  IntroduceInstanceBody,
) {
  use public_key <- decode.field("public_key", decoders.decode_public_key())
  use host <- decode.field("host", instance.decode_instance())
  decode.success(IntroduceInstanceBody(public_key:, host:))
}
