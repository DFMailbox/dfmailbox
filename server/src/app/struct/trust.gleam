import gleam/dynamic/decode
import gleam/json

pub type TrustPlotBody {
  TrustPlotBody(trusted: List(Int))
}

pub fn trust_plot_body_decoder() -> decode.Decoder(TrustPlotBody) {
  use trusted <- decode.then(decode.list(decode.int))
  decode.success(TrustPlotBody(trusted:))
}

pub type GetTrustsResponse {
  GetTrustsResponse(trusted_plots: List(Int))
}

pub fn encode_get_trusts_response(
  get_trusts_response: GetTrustsResponse,
) -> json.Json {
  let GetTrustsResponse(trusted_plots:) = get_trusts_response
  json.object([#("trusted_plots", json.array(trusted_plots, json.int))])
}
