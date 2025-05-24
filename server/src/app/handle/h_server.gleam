import app/ctx
import app/handle/helper
import ed25519/public_key
import ed25519/signature
import gleam/dict
import gleam/json
import gleam/result
import wisp
import youid/uuid

pub fn sign(query: helper.Query, ctx: ctx.Context) {
  let query = dict.from_list(query)
  use challenge <- helper.require_query(query, "challenge")
  use challenge <- helper.try_res(
    uuid.from_string(challenge)
    |> result.replace_error(helper.construct_error("challenge is not uuid", 400)),
  )

  let public_key =
    ctx.private_key
    |> public_key.derive_key()

  let sig =
    signature.create(
      ctx.private_key,
      public_key,
      challenge |> uuid.to_bit_array(),
    )
    |> signature.to_base64()

  json.object([
    #("server_key", json.string(public_key |> public_key.to_base64_url)),
    #("signature", json.string(sig)),
  ])
  |> json.to_string_tree()
  |> wisp.json_response(200)
}
