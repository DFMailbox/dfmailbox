import ed25519/public_key
import ed25519/signature
import gleam/dynamic/decode
import youid/uuid

pub fn decode_uuid() -> decode.Decoder(uuid.Uuid) {
  use str <- decode.then(decode.string)
  case uuid.from_string(str) {
    Ok(it) -> decode.success(it)
    Error(Nil) -> decode.failure(uuid.v4(), "valid uuid")
  }
}

pub fn decode_public_key() -> decode.Decoder(public_key.PublicKey) {
  use str <- decode.then(decode.string)
  case public_key.from_base64_url(str) {
    Ok(it) -> decode.success(it)
    Error(_) ->
      decode.failure(
        public_key.default(),
        "base64 url encoded ed25519 public key",
      )
  }
}

pub fn decode_signature() -> decode.Decoder(signature.Signature) {
  use str <- decode.then(decode.string)
  case signature.from_base64(str) {
    Ok(it) -> decode.success(it)
    Error(_) -> decode.failure(signature.default(), "base64 ed25519 signature")
  }
}
