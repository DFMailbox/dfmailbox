import actor/plot_mailbox
import app/ctx
import app/handle/helper
import dynjson
import ed25519/public_key
import gleam/bool
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import sql
import wisp

pub fn post(
  json: dynamic.Dynamic,
  identity: public_key.PublicKey,
  ctx: ctx.Context,
) {
  use body <- helper.guard_json(json, post_ext_mailbox_body_decoder())
  use from <- helper.guard_db(sql.get_plot(ctx.conn, body.from))
  // TODO: Improve errors, not sure about having them this "human"
  use from <- helper.try_res(
    list.first(from.rows)
    |> helper.replace_construct_error("'from' isn't registered for me", 409),
  )
  use from_key <- helper.try_res(
    from.public_key
    |> option.to_result(helper.construct_error("I own 'from'", 400)),
  )
  let assert Ok(from_key) = public_key.deserialize_all(from_key)

  use <- bool.guard(
    identity != from_key,
    helper.construct_error("'from' is not from your instance", 400),
  )
  use to <- helper.guard_db(sql.get_plot(ctx.conn, body.to))
  use to <- helper.try_res(
    list.first(to.rows)
    |> helper.replace_construct_error("'to' isn't registered for me", 400),
  )
  use Nil <- helper.try_res_error(
    to.public_key
    |> option.to_result(Nil)
    |> result.replace(helper.construct_error("I don't own 'to'", 400)),
  )
  let assert Ok(mailbox) = ctx.get_mailbox_lazy(ctx, to.id)
  // dont forget to check trust

  plot_mailbox.send(mailbox, body.data, from.id)
  |> PostExtMailboxResponse()
  |> post_ext_mailbox_response_to_json()
  |> json.to_string()
  |> wisp.json_response(200)
}

pub type PostExtMailboxResponse {
  PostExtMailboxResponse(msg_id: Int)
}

pub fn post_ext_mailbox_response_to_json(
  post_ext_mailbox_response: PostExtMailboxResponse,
) -> json.Json {
  let PostExtMailboxResponse(msg_id:) = post_ext_mailbox_response
  json.object([#("msg_id", json.int(msg_id))])
}

pub fn post_ext_mailbox_response_decoder() -> decode.Decoder(
  PostExtMailboxResponse,
) {
  use msg_id <- decode.field("msg_id", decode.int)
  decode.success(PostExtMailboxResponse(msg_id:))
}

pub type PostExtMailboxBody {
  PostExtMailboxBody(from: Int, to: Int, data: List(dynjson.DynJson))
}

pub fn post_ext_mailbox_body_to_json(
  post_ext_mailbox_body: PostExtMailboxBody,
) -> json.Json {
  let PostExtMailboxBody(from:, to:, data:) = post_ext_mailbox_body
  json.object([
    #("from", json.int(from)),
    #("to", json.int(to)),
    #("data", json.array(data, dynjson.to_json)),
  ])
}

fn post_ext_mailbox_body_decoder() -> decode.Decoder(PostExtMailboxBody) {
  use from <- decode.field("from", decode.int)
  use to <- decode.field("to", decode.int)
  use data <- decode.field("data", decode.list(dynjson.decoder()))
  decode.success(PostExtMailboxBody(from:, to:, data:))
}
