import app/ctx
import app/handle/helper
import ed25519/public_key
import ed25519/signature
import gleam/bit_array
import gleam/dict
import gleam/json
import gleam/result
import wisp

pub fn sign(query: helper.Query, ctx: ctx.Context) {
  let query = dict.from_list(query)
  use to_sign <- helper.require_query(query, "to_sign")
  use to_sign <- helper.try_res(
    bit_array.base64_url_decode(to_sign)
    |> result.replace_error(helper.construct_error("to_sign is not base64", 400)),
  )

  let public_key =
    ctx.private_key
    |> public_key.derive_key
  let sig =
    signature.create(ctx.private_key, public_key, to_sign)
    |> signature.to_base64()

  json.object([
    #("server_key", json.string(public_key |> public_key.to_base64_url)),
    #("signature", json.string(sig)),
  ])
  |> json.to_string_tree()
  |> wisp.json_response(200)
}
