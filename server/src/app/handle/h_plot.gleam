import actor/cache
import actor/plot_mailbox
import actor/profiles
import app/address
import app/ctx
import app/handle/helper
import app/problem
import app/role
import app/struct/plot
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
  role: role.Role,
  ctx: ctx.Context,
) -> wisp.Response {
  use body <- helper.guard_json(json, plot.update_plot_body_decoder())
  use plot <- helper.try_res(role.match_authenticated(role))
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

pub fn delete_plot(role: role.Role, ctx: ctx.Context) {
  case role {
    role.Host(id:, owner: _, mailbox_msg_id: _) -> {
      let _nil =
        ctx.mailbox_map
        |> cache.get(id)
        |> result.map(plot_mailbox.shutdown)
      let Nil = cache.remove(ctx.mailbox_map, id)

      let _ = sql.purge_api_keys(ctx.conn, id)
      let _ = sql.delete_trust(ctx.conn, id)
      let _ = sql.delete_plot(ctx.conn, id)
      wisp.ok()
    }

    role.Registered(id:, owner: _, instance: _, address: _, mailbox_msg_id: _) -> {
      let _ = sql.purge_api_keys(ctx.conn, id)
      let _ = sql.delete_trust(ctx.conn, id)
      let _ = sql.delete_plot(ctx.conn, id)
      wisp.ok()
    }
    role.Unregistered(_, _) ->
      helper.construct_error("Plot not registered", 409)
    role.NoAuth -> role.unauthorized() |> problem.to_response()
  }
}

pub fn get_plot(role: role.Role) {
  use res <- helper.try_res(
    role.match_registered_callback(
      role,
      host: fn(plot) {
        plot.GetPlotResponse(
          plot_id: plot.id,
          owner: plot.owner,
          mailbox_msg_id: plot.mailbox_msg_id,
          public_key: option.None,
          address: option.None,
        )
      },
      registered: fn(plot, pubkey, address) {
        plot.GetPlotResponse(
          plot_id: plot.id,
          owner: plot.owner,
          mailbox_msg_id: plot.mailbox_msg_id,
          public_key: pubkey |> option.Some,
          address: address |> option.Some,
        )
      },
    ),
  )
  res
  |> plot.encode_get_plot_response()
  |> json.to_string
  |> wisp.json_response(200)
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
        address: option.map(it.address, fn(addr) {
          let assert Ok(addr) = address.parse(addr)
          addr
        }),
        mailbox_msg_id: it.mailbox_msg_id,
      )
      |> plot.encode_get_plot_response()
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> wisp.not_found()
  }
}

pub fn register_plot(json: dynamic.Dynamic, role: role.Role, ctx: ctx.Context) {
  use #(plot_id, name) <- helper.try_res(role.match_unregistered(role))
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
  use res <- helper.guard_db_constraint(res, "plot_instance_fkey", fn() {
    let assert option.Some(instance) = body.instance
    problem.unknown_instance(409, instance) |> problem.to_response
  })

  case echo res.count {
    1 -> wisp.created()
    _ -> panic as "unreachable error: auth should block this"
  }
}
