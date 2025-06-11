import actor/cache
import app/ctx
import app/ext
import app/handle/helper
import app/struct/instance
import ed25519/public_key
import gleam/dict
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/result
import sql
import wisp

pub fn introduce(json: dynamic.Dynamic, ctx: ctx.Context) {
  use body <- helper.guard_json(
    json,
    instance.introduce_instance_body_decoder(),
  )
  use key <- helper.try_res(
    ext.request_key_exchange(body.public_key, body.address, ctx.instance)
    |> result.map_error(ext.serialize_ping_error)
    |> result.map_error(helper.construct_error(_, 400)),
  )
  cache.set(ctx.ext_identity_key_map, key, body.public_key)
  wisp.ok()
}

pub fn get_instance(query: helper.Query, ctx: ctx.Context) {
  use key <- helper.require_query(query |> dict.from_list(), "public_key")
  use key <- helper.try_res(
    key
    |> public_key.from_base64_url()
    |> result.map_error(helper.construct_error(_, 400)),
  )
  use instance <- helper.guard_db(sql.get_instance(
    ctx.conn,
    key |> public_key.serialize_to_bits(),
  ))
  use instance <- helper.try_res(
    list.first(instance.rows)
    |> result.replace_error(helper.construct_error("Unknown instance", 404)),
  )
  instance.address
  |> json.nullable(json.string)
  |> json.to_string_tree()
  |> wisp.json_response(200)
}
