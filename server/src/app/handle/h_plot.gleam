import app/ctx
import app/handle/helper
import gleam/bit_array
import gleam/function
import gleam/json
import gleam/list
import gleam/option
import sql
import wisp
import youid/uuid

pub fn get_plot(
  query: List(#(String, String)),
  ctx: ctx.Context,
) -> wisp.Response {
  use id <- helper.require_id(query)
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
                json.string(key |> bit_array.base64_url_encode(False)),
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
