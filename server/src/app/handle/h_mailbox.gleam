import actor/cache
import actor/plot_mailbox
import app/address
import app/ctx
import app/ext/cross_send
import app/handle/helper
import app/role
import app/struct/mailbox
import ed25519/public_key
import gleam/bool
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import sql
import wisp

pub fn peek(query: helper.Query, role: role.Role, ctx: ctx.Context) {
  use msg_id <- helper.require_id(query, "msg_id")
  let limit =
    list.key_find(query, "limit")
    // maybe this should be a 400
    |> result.map(int.parse)
    |> result.flatten
    |> option.from_result()

  use plot <- helper.try_res(role |> role.match_host)
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
  role: role.Role,
  ctx: ctx.Context,
) {
  use body <- helper.guard_json(payload, mailbox.post_mailbox_body_decoder())
  use auth_plot <- helper.try_res(role |> role.match_host)

  use plot <- helper.guard_db(sql.get_plot(ctx.conn, dest_plot))
  use plot <- helper.try_res(
    list.first(plot.rows)
    |> helper.replace_construct_error("dest_plot doesn't exist", 400),
  )
  case plot.public_key {
    option.Some(key) -> {
      use instance <- helper.guard_db(sql.get_instance(ctx.conn, key))
      // panic means sql constraints don't work 
      let assert Ok(instance) = list.first(instance.rows)
      // panic means instance is compromised
      let assert option.Some(address) = instance.address
      let assert Ok(address) = address.parse(address)

      let assert Ok(key) = public_key.deserialize_all(key)
      let send = fn() {
        use identity_token <- result.try(cache.get(ctx.identity_key_map, key))
        case
          cross_send.send(
            address,
            identity_token,
            auth_plot.id,
            dest_plot,
            body.data,
          )
        {
          Ok(id) ->
            id
            |> mailbox.PostMailboxResponse
            |> mailbox.encode_post_mailbox_response()
            |> json.to_string_tree()
            |> wisp.json_response(200)
            |> Ok
          Error(err) ->
            case err {
              cross_send.CSHttpError(err) ->
                helper.construct_error(
                  "http error: " <> string.inspect(err),
                  400,
                )
                |> Ok

              cross_send.InvalidIdentity -> Error(Nil)
              cross_send.PostError(err) ->
                helper.construct_error("Post error: " <> err, 400)
                |> Ok
            }
        }
      }
      case send() {
        Ok(res) -> res
        Error(Nil) -> {
          todo as "identity token didn't work"
        }
      }
    }
    option.None -> {
      let mailbox = ctx.get_mailbox(ctx, dest_plot, auth_plot.mailbox_msg_id)

      use res <- helper.guard_db(sql.check_trust(
        ctx.conn,
        dest_plot,
        auth_plot.id,
      ))
      use <- bool.guard(
        res.count != 1,
        helper.construct_error("Your plot is not trusted", 400),
      )

      let id =
        mailbox
        |> plot_mailbox.send(body.data, auth_plot.id)

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
  }
}

pub fn enqueue(payload: dynamic.Dynamic, role: role.Role, ctx: ctx.Context) {
  use body <- helper.guard_json(payload, mailbox.post_mailbox_body_decoder())
  use plot <- helper.try_res(role |> role.match_host)
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

pub fn cleanup(query: helper.Query, role: role.Role, ctx: ctx.Context) {
  use msg_id <- helper.require_id(query, "msg_id")
  let limit =
    list.key_find(query, "limit")
    // maybe this should be a 400
    |> result.map(int.parse)
    |> result.flatten
    |> option.from_result()
  let return = list.key_find(query, "return")

  use plot <- helper.try_res(role |> role.match_host)
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

  let return = case return {
    Ok(str) -> str == "false"
    Error(Nil) -> True
  }
  case return {
    False -> {
      plot_mailbox.cleanup(mailbox, msg_id)
      wisp.ok()
    }
    True -> {
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
