import actor/plot_mailbox
import dfjson
import gleam/dynamic/decode
import gleam/json

pub type PostMailboxBody {
  PostMailboxBody(data: List(dfjson.DFJson))
}

pub fn post_mailbox_body_decoder() -> decode.Decoder(PostMailboxBody) {
  use data <- decode.field("data", decode.list(dfjson.df_json_decoder()))
  decode.success(PostMailboxBody(data:))
}

pub type PostMailboxResponse {
  PostMailboxResponse(msg_id: Int)
}

pub fn encode_post_mailbox_response(
  post_mailbox_response: PostMailboxResponse,
) -> json.Json {
  let PostMailboxResponse(msg_id:) = post_mailbox_response
  json.object([#("msg_id", json.int(msg_id))])
}

pub type PeekMailboxResponse {
  PeekMailboxResponse(
    items: List(plot_mailbox.StoreRow),
    until: Int,
    current_id: Int,
  )
}

pub fn encode_peek_mailbox_response(
  peek_mailbox_response: PeekMailboxResponse,
) -> json.Json {
  let PeekMailboxResponse(items:, until:, current_id:) = peek_mailbox_response
  json.object([
    #("items", json.array(items, plot_mailbox.encode_store_row)),
    #("until", json.int(until)),
    #("current_id", json.int(current_id)),
  ])
}
