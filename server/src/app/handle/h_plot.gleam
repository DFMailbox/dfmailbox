import actor/cache
import actor/plot_mailbox
import actor/profiles
import app/ctx
import app/handle/helper
import app/struct/plot
import app/web
import ed25519/public_key
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import sql
import wisp

pub fn update_plot(
  json: dynamic.Dynamic,
  auth: web.Authentication,
  ctx: ctx.Context,
) -> wisp.Response {
  use body <- helper.guard_json(json, plot.update_plot_body_decoder())
  use plot <- helper.try_res(
    web.match_authenticated(auth)
    |> result.replace_error(helper.construct_error("No auth present", 401)),
  )
  let _ = case body.instance {
    option.Some(inst) -> {
      let _nil =
        ctx.mailbox_map
        |> cache.get(plot)
        |> result.map(plot_mailbox.shutdown)
      let Nil = cache.remove(ctx.mailbox_map, plot)

      let assert Ok(_) =
        sql.update_plot_instance_ext(
          ctx.conn,
          public_key.serialize_to_bits(inst),
          plot,
        )
    }
    option.None -> {
      let assert Ok(_) = sql.update_plot_instance_int(ctx.conn, plot)
    }
  }
  wisp.ok()
}

pub fn get_plot(auth: web.Authentication, ctx: ctx.Context) {
  use plot <- helper.try_res(web.match_generic(auth))
  get_other_plot(plot.id, ctx)
}

pub fn get_other_plot(id: Int, ctx: ctx.Context) -> wisp.Response {
  use plot_row <- helper.guard_db(sql.get_plot(ctx.conn, id))
  let plot = list.first(plot_row.rows)
  case plot {
    Ok(it) -> {
      plot.GetPlotResponse(
        plot_id: it.id,
        owner: it.owner,
        public_key: it.public_key
          |> option.map(fn(a) {
            let assert Ok(k) = public_key.deserialize_all(a)
            k
          }),
        domain: it.domain,
        mailbox_msg_id: it.mailbox_msg_id,
      )
      |> plot.encode_get_plot_response()
      |> json.to_string_tree()
      |> wisp.json_response(200)
    }
    Error(_) -> wisp.not_found()
  }
}

pub fn register_plot(
  json: dynamic.Dynamic,
  auth: web.Authentication,
  ctx: ctx.Context,
) {
  use #(plot_id, name) <- helper.try_res(case auth {
    web.UnregisteredPlot(plot_id, name) -> Ok(#(plot_id, name))
    web.NoAuth ->
      Error(helper.construct_error("No authentication present", 401))
    _ -> Error(helper.construct_error("Plot already registered", 403))
  })
  use body <- helper.guard_json(json, plot.register_plot_body_decoder())

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
  use res <- helper.guard_db_constraint(
    res,
    "plot_instance_fkey",
    helper.construct_error("instance not registered", 409),
  )

  case echo res.count {
    1 -> wisp.created()
    _ -> panic as "unreachable error: auth should block this"
  }
}
