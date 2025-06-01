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
