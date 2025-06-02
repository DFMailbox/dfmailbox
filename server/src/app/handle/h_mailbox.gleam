import actor/cache
import actor/plot_mailbox
import app/ctx
import app/handle/helper
import app/struct/mailbox
import app/web
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/result
import sql
import wisp

pub fn peek(query: helper.Query, auth: web.Authentication, ctx: ctx.Context) {
  use msg_id <- helper.require_id(query)
  use plot <- helper.try_res(
    auth
    |> web.match_generic()
    |> result.replace_error(helper.construct_error("Plot auth required", 403)),
  )
  let mailbox = case
    ctx.mailbox_map
    |> cache.get(plot.id)
  {
    Ok(it) -> it
    Error(Nil) -> {
      let box = plot_mailbox.new(plot.mailbox_msg_id)
      cache.set(ctx.mailbox_map, plot.id, box)
      box
    }
  }

  plot_mailbox.peek(mailbox, msg_id)
  |> json.array(of: plot_mailbox.encode_store_row)
  |> json.to_string_tree()
  |> wisp.json_response(200)
}

pub fn enqueue(
  payload: dynamic.Dynamic,
  auth: web.Authentication,
  ctx: ctx.Context,
) {
  use body <- helper.guard_json(payload, mailbox.post_mailbox_body_decoder())
  use plot <- helper.try_res(
    auth
    |> web.match_generic(),
  )
  let mailbox = case
    ctx.mailbox_map
    |> cache.get(plot.id)
  {
    Ok(it) -> it
    Error(Nil) -> {
      let box = plot_mailbox.new(plot.mailbox_msg_id)
      cache.set(ctx.mailbox_map, plot.id, box)
      box
    }
  }

  let id =
    mailbox
    |> plot_mailbox.post(body.data)

  use _ <- helper.guard_db(sql.set_mailbox_msg_id(
    ctx.conn,
    plot.id,
    id + { body.data |> list.length() },
  ))

  id
  |> mailbox.PostMailboxResponse
  |> mailbox.encode_post_mailbox_response()
  |> json.to_string_tree()
  |> wisp.json_response(200)
}

pub fn cleanup(query: helper.Query, auth: web.Authentication, ctx: ctx.Context) {
  use msg_id <- helper.require_id(query)
  use plot <- helper.try_res(
    auth
    |> web.match_generic(),
  )
  let mailbox = case
    ctx.mailbox_map
    |> cache.get(plot.id)
  {
    Ok(it) -> it
    Error(Nil) -> {
      let box = plot_mailbox.new(plot.mailbox_msg_id)
      cache.set(ctx.mailbox_map, plot.id, box)
      box
    }
  }
  plot_mailbox.cleanup(mailbox, msg_id)

  wisp.ok()
}
