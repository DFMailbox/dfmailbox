import app/ctx
import app/handle/helper
import app/struct/api_key
import app/web
import gleam/bit_array
import gleam/crypto
import gleam/json
import gleam/result
import gleam/string
import sql
import wisp

pub fn add(auth: web.Authentication, ctx: ctx.Context) {
  use auth <- helper.try_res(
    web.match_generic(auth)
    |> result.replace_error(helper.construct_error("Plot auth required", 403)),
  )
  let gen =
    crypto.strong_random_bytes(48)
    |> bit_array.base64_encode(False)
    |> string.append("dfm_key_", _)
  use _ <- helper.guard_db(sql.add_api_key(
    ctx.conn,
    auth.id,
    gen |> bit_array.from_string(),
  ))
  api_key.CreateApiKeyResponse(api_key: gen)
  |> api_key.encode_create_api_key_response()
  |> json.to_string_tree()
  |> wisp.json_response(200)
}
