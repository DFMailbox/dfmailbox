import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import pog
import wisp

pub type QueryDict =
  dict.Dict(String, String)

pub type Query =
  List(#(String, String))

pub fn guard_db(
  res: Result(a, pog.QueryError),
  body: fn(a) -> wisp.Response,
) -> wisp.Response {
  case res {
    Ok(it) -> body(it)
    Error(err) -> {
      wisp.log_error(err |> string.inspect)
      construct_error("database error", 500)
    }
  }
}

pub fn guard_db_constraint(
  result: Result(a, pog.QueryError),
  constraint: String,
  error_response: fn() -> wisp.Response,
  body: fn(a) -> wisp.Response,
) {
  case result {
    Ok(it) -> body(it)
    Error(err) -> {
      let error = fn() {
        wisp.log_error(err |> string.inspect)
        construct_error("database error", 500)
      }
      case err {
        pog.ConstraintViolated(_, constr, _) ->
          case constr == constraint {
            True -> error_response()
            False -> error()
          }
        _ -> error()
      }
    }
  }
}

pub fn get_id(query: Query, location: String) -> Result(Int, String) {
  use id <- result.try(
    list.key_find(query, location)
    |> result.replace_error("Cannot find " <> location <> "in query"),
  )
  id |> int.parse |> result.replace_error(location <> " is not an int")
}

pub fn require_id(
  query: Query,
  location: String,
  body: fn(Int) -> wisp.Response,
) -> wisp.Response {
  case get_id(query, location) {
    Ok(id) -> {
      body(id)
    }
    Error(err) -> {
      construct_error(err, 400)
    }
  }
}

pub fn require_query(
  query: QueryDict,
  key: String,
  body: fn(String) -> wisp.Response,
) -> wisp.Response {
  case query |> dict.get(key) {
    Ok(it) -> body(it)
    Error(Nil) -> query_error(key)
  }
}

/// Construct a query not found error
pub fn query_error(key: String) {
  { "Cannot find " <> key <> " in query" }
  |> construct_error(400)
}

pub fn construct_error(msg: String, code: Int) -> wisp.Response {
  wisp.json_response(
    json.object([#("error", json.string(msg))]) |> json.to_string,
    code,
  )
}

pub fn replace_construct_error(
  result: Result(a, b),
  msg: String,
  code: Int,
) -> Result(a, wisp.Response) {
  result
  |> result.replace_error(construct_error(msg, code))
}

pub fn try_res(res: Result(a, wisp.Response), body: fn(a) -> wisp.Response) {
  result.map(res, body)
  |> result.unwrap_both
}

pub fn try_res_error(
  res: Result(wisp.Response, b),
  body: fn(b) -> wisp.Response,
) {
  result.map_error(res, body)
  |> result.unwrap_both
}

pub fn guard_json(
  json: decode.Dynamic,
  decoder: decode.Decoder(a),
  body: fn(a) -> wisp.Response,
) -> wisp.Response {
  decode.run(json, decoder)
  |> result.map_error(transform_decode_err)
  |> result.map(body)
  |> result.unwrap_both
}

pub fn decode_error_format(err: decode.DecodeError) {
  "Decode failed in '"
  <> string.join(err.path, ", ")
  <> "' expected '"
  <> err.expected
  <> "', got '"
  <> err.found
  <> "'"
}

fn transform_decode_err(err: List(decode.DecodeError)) {
  list.map(err, decode_error_format)
  |> json.array(of: json.string)
  |> json.to_string
  |> wisp.json_body(wisp.response(400), _)
}
