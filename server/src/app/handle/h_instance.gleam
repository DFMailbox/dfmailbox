import app/address
import app/ctx
import app/ext/verify_instance
import app/handle/helper
import app/problem
import app/struct/instance
import ed25519/public_key
import gleam/bool
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option
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
      |> problem.to_response
    }),
  )
  use <- bool.guard(
    key != body.public_key,
    problem.intro_mismatched_public_key(400, key, body.public_key)
      |> problem.to_response,
  )
  use <- bool.guard(
    address != body.address,
    problem.intro_mismatched_address(400, address, body.address)
      |> problem.to_response,
  )
  case body.update {
    True -> {
      let assert Ok(res) =
        sql.replace_instance(
          ctx.conn,
          key |> public_key.serialize_to_bits,
          address |> address.to_string,
        )
      case res.count {
        1 -> wisp.ok()
        0 ->
          problem.no_update_effect(409)
          |> problem.to_response()
        _ -> panic as "unreachable"
      }
    }
    False ->
      case
        address.identify(
          ctx.conn,
          key |> public_key.serialize_to_bits,
          address,
          ctx.instance,
        )
      {
        1 -> wisp.ok()
        0 ->
          problem.already_exists(409)
          |> problem.to_response()
        _ -> panic as "unreachable"
      }
  }
}

pub fn get_instance(query: helper.Query, ctx: ctx.Context) {
  let key = query |> list.key_find("public_key")
  case key {
    Ok(key) -> {
      use key <- helper.try_res(
        key
        |> public_key.from_base64_url()
        |> result.map_error(fn(x) {
          problem.invalid_request_paramater(400, [
            problem.Paramater("public_key", x),
          ])
          |> problem.to_response()
        }),
      )
      use instance <- helper.guard_db(sql.get_instance(
        ctx.conn,
        key |> public_key.serialize_to_bits(),
      ))
      use instance <- helper.try_res(
        list.first(instance.rows)
        |> result.map_error(fn(_) {
          problem.unknown_instance(404, key) |> problem.to_response
        }),
      )
      let instance =
        instance.address
        |> option.map(fn(addr) {
          let assert Ok(addr) = address.parse(addr)
          addr
        })
        |> instance.AddressKeyPair(key)
        |> instance.address_key_pair_to_json()

      json.object([#("instance", instance)])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(Nil) -> {
      use instance <- helper.guard_db(sql.list_instances(ctx.conn))
      let instances =
        json.array(instance.rows, fn(inst) {
          let assert Ok(public_key) =
            inst.public_key |> public_key.deserialize_all
          inst.address
          |> option.map(fn(s) {
            let assert Ok(s) = address.parse(s)
            s
          })
          |> instance.AddressKeyPair(public_key)
          |> instance.address_key_pair_to_json()
        })
      json.object([#("instances", instances)])
      |> json.to_string
      |> wisp.json_response(200)
    }
  }
}
