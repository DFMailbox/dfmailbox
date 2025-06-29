import app/address
import app/handle/decoders
import ed25519/public_key
import gleam/dynamic/decode
import gleam/json
import gleam/option
import youid/uuid

pub type RegisterPlotBody {
  RegisterPlotBody(instance: option.Option(public_key.PublicKey))
}

pub fn register_plot_body_decoder() -> decode.Decoder(RegisterPlotBody) {
  use instance <- decode.field(
    "instance",
    decode.optional(decoders.decode_public_key()),
  )
  decode.success(RegisterPlotBody(instance:))
}

pub type GetPlotResponse {
  GetPlotResponse(
    plot_id: Int,
    owner: uuid.Uuid,
    public_key: option.Option(public_key.PublicKey),
    address: option.Option(address.InstanceAddress),
    mailbox_msg_id: Int,
  )
}

pub fn encode_get_plot_response(get_plot_response: GetPlotResponse) -> json.Json {
  let GetPlotResponse(plot_id:, owner:, public_key:, address:, mailbox_msg_id:) =
    get_plot_response
  json.object([
    #("plot_id", json.int(plot_id)),
    #("owner", uuid.to_string(owner) |> json.string()),
    #("public_key", case public_key {
      option.None -> json.null()
      option.Some(value) -> value |> public_key.to_base64_url() |> json.string
    }),
    #("address", json.nullable(address, address.instance_address_to_json)),
    #("mailbox_msg_id", json.int(mailbox_msg_id)),
  ])
}

pub type UpdatePlotBody {
  UpdatePlotBody(instance: option.Option(public_key.PublicKey))
}

pub fn update_plot_body_decoder() -> decode.Decoder(UpdatePlotBody) {
  use instance <- decode.field(
    "instance",
    decode.optional(decoders.decode_public_key()),
  )
  decode.success(UpdatePlotBody(instance:))
}
