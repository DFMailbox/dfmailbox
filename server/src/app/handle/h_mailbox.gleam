import actor/cache
import actor/plot_mailbox
import app/ctx
import app/handle/helper
import app/struct/mailbox
import app/web
import gleam/bool
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import sql
import wisp

pub fn peek(query: helper.Query, auth: web.Authentication, ctx: ctx.Context) {
  use msg_id <- helper.require_id(query)
  let limit =
    list.key_find(query, "limit")
    // maybe this should be a 400
    |> result.map(int.parse)
    |> result.flatten
    |> option.from_result()

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

  let items = plot_mailbox.recieve(mailbox, msg_id, limit, False)

  mailbox.PeekMailboxResponse(
    items: items.result,
    until: items.until,
    current_id: items.current_id,
  )
  |> mailbox.encode_peek_mailbox_response()
  |> json.to_string_tree()
  |> wisp.json_response(200)
}

pub fn enqueue_other(
  dest_plot: Int,
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
    |> cache.get(dest_plot)
  {
    Ok(it) -> it
    Error(Nil) -> {
      let box = plot_mailbox.new(plot.mailbox_msg_id)
      cache.set(ctx.mailbox_map, dest_plot, box)
      box
    }
  }
  use res <- helper.guard_db(sql.check_trust(ctx.conn, dest_plot, plot.id))
  use <- bool.guard(
    res.count != 1,
    helper.construct_error("Your plot is not trusted", 400),
  )

  let id =
    mailbox
    |> plot_mailbox.send(body.data, plot.id)

  use _ <- helper.guard_db(sql.set_mailbox_msg_id(
    ctx.conn,
    dest_plot,
    id + { body.data |> list.length() },
  ))

  id
  |> mailbox.PostMailboxResponse
  |> mailbox.encode_post_mailbox_response()
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
    |> plot_mailbox.send(body.data, plot.id)

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
  let limit =
    list.key_find(query, "limit")
    // maybe this should be a 400
    |> result.map(int.parse)
    |> result.flatten
    |> option.from_result()
  let return = list.key_find(query, "return") |> result.is_ok()

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

  case return {
    True -> {
      plot_mailbox.cleanup(mailbox, msg_id)
      wisp.ok()
    }
    False -> {
      let items = plot_mailbox.recieve(mailbox, msg_id, limit, True)

      mailbox.PeekMailboxResponse(
        items: items.result,
        until: items.until,
        current_id: items.current_id,
      )
      |> mailbox.encode_peek_mailbox_response()
      |> json.to_string_tree()
      |> wisp.json_response(200)
    }
  }
}
