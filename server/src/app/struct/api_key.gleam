import gleam/bit_array
import gleam/float
import gleam/json
import gleam/time/timestamp
import sql

pub type CreateApiKeyResponse {
  CreateApiKeyResponse(api_key: String)
}

pub fn encode_create_api_key_response(
  create_api_key_response: CreateApiKeyResponse,
) -> json.Json {
  let CreateApiKeyResponse(api_key:) = create_api_key_response
  json.object([#("api_key", json.string(api_key))])
}

pub type GetKeysResponse {
  GetAllApiKeysResponse(keys: List(sql.GetApiKeysRow))
}

/// Doesn't encode everything
pub fn encode_keys_row(get_api_keys_row: sql.GetApiKeysRow) -> json.Json {
  let sql.GetApiKeysRow(id: _, plot: _, hashed_key:, created_at:) =
    get_api_keys_row

  json.object([
    // #("id", json.int(id)),
    // #("plot", json.int(plot)),
    #(
      "hashed_key",
      hashed_key |> bit_array.base64_encode(True) |> json.string(),
    ),
    #(
      "created_at",
      created_at |> timestamp.to_unix_seconds |> float.round |> json.int(),
    ),
  ])
}

pub fn encode_get_keys_response(
  get_all_api_keys_response: GetKeysResponse,
) -> json.Json {
  let GetAllApiKeysResponse(keys:) = get_all_api_keys_response
  json.object([#("keys", json.array(keys, encode_keys_row))])
}
