import app/address
import app/ctx
import app/ext/verify_instance
import app/handle/helper
import app/struct/instance
import ed25519/public_key
import gleam/bit_array
import gleam/bool
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
  use #(key, address) <- helper.try_res(
    verify_instance.ping_sign(body.address)
    |> result.map_error(fn(err) {
      err
      |> verify_instance.ping_instance_error_to_json
      |> json.to_string_tree
      |> wisp.json_response(400)
    }),
  )
  use <- bool.guard(
    key != body.public_key,
    json.object([
      #("error", "mismatched_address" |> json.string),
      #("expected_address", address |> address.to_string |> json.string),
    ])
      |> json.to_string_tree
      |> wisp.json_response(400),
  )
  use <- bool.guard(
    address != body.address,
    json.object([
      #("error", "mismatched_public_key" |> json.string),
      #("expected_key", address |> address.to_string |> json.string),
    ])
      |> json.to_string_tree
      |> wisp.json_response(400),
  )
  // sql.identify_instance(ctx.conn)
  wisp.ok()
}

pub fn get_instance(query: helper.Query, ctx: ctx.Context) {
  let key = query |> list.key_find("public_key")
  case key {
    Ok(key) -> {
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
    Error(Nil) -> {
      use instance <- helper.guard_db(sql.list_instances(ctx.conn))
      json.array(instance.rows, fn(inst) {
        json.object([
          #(
            "public_key",
            inst.public_key |> bit_array.base64_url_encode(True) |> json.string,
          ),
          #("address", inst.address |> json.nullable(json.string)),
        ])
      })
      |> json.to_string_tree()
      |> wisp.json_response(200)
    }
  }
}
