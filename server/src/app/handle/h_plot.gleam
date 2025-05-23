import app/ctx
import app/handle/helper
import gleam/json
import gleam/list
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
    Ok(it) ->
      json.object([
        #("id", json.int(it.id)),
        #("owner", json.string(it.owner |> uuid.to_string)),
        // TODO: domain, public_key
      ])
      |> json.to_string_tree
      |> wisp.json_response(200)
    Error(_) -> wisp.not_found()
  }
}
