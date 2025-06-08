import actor/cache
import app/ctx
import app/ext
import app/handle/helper
import app/struct/instance
import gleam/dynamic
import gleam/result
import wisp

pub fn introduce(json: dynamic.Dynamic, ctx: ctx.Context) {
  use body <- helper.guard_json(
    json,
    instance.introduce_instance_body_decoder(),
  )
  use key <- helper.try_res(
    ext.request_key_exchange(body.public_key, body.host, ctx.instance)
    |> result.map_error(ext.serialize_ping_error)
    |> result.map_error(helper.construct_error(_, 400)),
  )
  cache.set(ctx.ext_identity_key_map, key, body.public_key)
  wisp.ok()
}
