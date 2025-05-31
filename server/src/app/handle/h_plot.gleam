import app/ctx
import app/handle/decoders
import app/handle/helper
import app/profiles
import app/web
import ed25519/public_key
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/function
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import pog
import sql
import wisp
import youid/uuid

pub fn get_plot(id: Int, ctx: ctx.Context) -> wisp.Response {
  use plot_row <- helper.guard_db(sql.get_plot(ctx.conn, id))
  let plot = list.first(plot_row.rows)
  case plot {
    Ok(it) -> {
      let instance = case it.public_key {
        option.Some(key) -> {
          let assert option.Some(domain) = it.domain
          option.Some(
            json.object([
              #(
                "public_key",
                json.string(key |> bit_array.base64_encode(False)),
              ),
              #("domain", json.string(domain)),
            ]),
          )
        }
        option.None -> option.None
      }
      json.object([
        #("id", json.int(it.id)),
        #("owner", json.string(it.owner |> uuid.to_string)),
        #("instance", json.nullable(instance, of: function.identity)),
      ])
      |> json.to_string_tree
      |> wisp.json_response(200)
    }
    Error(_) -> wisp.not_found()
  }
}

pub type RegisterPlotBody {
  RegisterPlotBody(instance: option.Option(public_key.PublicKey))
}

fn register_plot_body_decoder() -> decode.Decoder(RegisterPlotBody) {
  use instance <- decode.field(
    "instance",
    decode.optional(decoders.decode_public_key()),
  )
  decode.success(RegisterPlotBody(instance:))
}

pub fn register_plot(
  json: dynamic.Dynamic,
  auth: web.Authentication,
  ctx: ctx.Context,
) {
  use #(plot_id, name) <- helper.try_res(case auth {
    web.UnregisteredPlot(plot_id, name) -> Ok(#(plot_id, name))
    _ -> Error(helper.construct_error("Unregistered plot auth required", 403))
  })
  use body <- helper.guard_json(json, register_plot_body_decoder())

  let assert Ok(uuid) = profiles.fetch(ctx.profiles, name)

  let res = case body.instance {
    option.Some(instance) ->
      sql.register_plot_ext(
        ctx.conn,
        plot_id,
        uuid,
        instance |> public_key.serialize_to_bits(),
      )
    option.None -> sql.register_plot_int(ctx.conn, plot_id, uuid)
  }
  use res <- helper.try_res(
    res
    |> result.map_error(fn(err) {
      case err {
        pog.ConstraintViolated(_, constraint, _) -> {
          case constraint {
            "plot_instance_fkey" -> {
              helper.construct_error("instance not registered", 409)
            }
            _ -> {
              wisp.log_error(err |> string.inspect)
              helper.construct_error("database error", 500)
            }
          }
        }
        _ -> {
          wisp.log_error(err |> string.inspect)
          helper.construct_error("database error", 500)
        }
      }
    }),
  )
  case echo res.count {
    1 -> wisp.created()
    _ ->
      helper.construct_error("unreachable error: auth should block this", 500)
  }
}
