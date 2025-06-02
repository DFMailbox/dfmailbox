import gleam/json

pub type CreateApiKeyResponse {
  CreateApiKeyResponse(api_key: String)
}

pub fn encode_create_api_key_response(
  create_api_key_response: CreateApiKeyResponse,
) -> json.Json {
  let CreateApiKeyResponse(api_key:) = create_api_key_response
  json.object([#("api_key", json.string(api_key))])
}
