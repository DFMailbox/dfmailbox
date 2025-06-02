import app/ctx
import app/handle/helper
import app/struct/trust
import app/web
import gleam/dynamic
import gleam/json
import gleam/list
import sql
import wisp

pub fn trust_plot(
  json: dynamic.Dynamic,
  auth: web.Authentication,
  ctx: ctx.Context,
) {
  use body <- helper.guard_json(json, trust.trust_plot_body_decoder())
  use plot <- helper.try_res(web.match_generic(auth))
  use res <- helper.guard_db(sql.trust_plot(ctx.conn, plot.id, body.trust))
  case res.count {
    0 -> wisp.response(409)
    1 -> wisp.created()
    _ -> panic as "unreachable"
  }
}

pub fn untrust_plot(
  json: dynamic.Dynamic,
  auth: web.Authentication,
  ctx: ctx.Context,
) {
  use body <- helper.guard_json(json, trust.trust_plot_body_decoder())
  use plot <- helper.try_res(web.match_generic(auth))
  use res <- helper.guard_db(sql.remove_trust(ctx.conn, plot.id, body.trust))
  case res.count {
    0 -> wisp.response(409)
    1 -> wisp.created()
    _ -> panic as "unreachable"
  }
}

pub fn get_trusted(auth: web.Authentication, ctx: ctx.Context) {
  use plot <- helper.try_res(web.match_generic(auth))
  use trusted_plots <- helper.guard_db(sql.list_trust(ctx.conn, plot.id))
  trusted_plots.rows
  |> list.map(fn(x) { x.trusted })
  |> trust.GetTrustsResponse()
  |> trust.encode_get_trusts_response()
  |> json.to_string_tree()
  |> wisp.json_response(200)
}
