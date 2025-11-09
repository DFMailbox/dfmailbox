import app/ctx
import app/handle/helper
import app/role
import app/struct/trust
import gleam/dynamic
import gleam/json
import gleam/list
import sql
import wisp

pub fn trust_plot(json: dynamic.Dynamic, role: role.Role, ctx: ctx.Context) {
  use body <- helper.guard_json(json, trust.trust_plot_body_decoder())
  use plot <- helper.try_res(role.match_host(role))
  use _res <- helper.guard_db_constraint(
    sql.trust_plot(ctx.conn, plot.id, body.trusted),
    "trust_trusted_fkey",
    fn() { helper.construct_error("Plot doesn't exist", 400) },
  )
  wisp.ok()
}

pub fn untrust_plot(json: dynamic.Dynamic, role: role.Role, ctx: ctx.Context) {
  use body <- helper.guard_json(json, trust.trust_plot_body_decoder())
  use plot <- helper.try_res(role.match_host(role))
  use _res <- helper.guard_db(sql.remove_trust(ctx.conn, plot.id, body.trusted))
  wisp.ok()
}

pub fn get_trusted(role: role.Role, ctx: ctx.Context) {
  use plot <- helper.try_res(role.match_host(role))
  use trusted_plots <- helper.guard_db(sql.list_trust(ctx.conn, plot.id))
  trusted_plots.rows
  |> list.map(fn(x) { x.trusted })
  |> trust.GetTrustsResponse()
  |> trust.encode_get_trusts_response()
  |> json.to_string
  |> wisp.json_response(200)
}
