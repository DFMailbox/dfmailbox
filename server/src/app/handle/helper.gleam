import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import pog
import wisp

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

pub fn get_id(query: List(#(String, String))) -> Result(Int, String) {
  use id <- result.try(
    query
    |> list.find(fn(x) { x.0 == "id" })
    |> result.replace_error("Cannot find id in query"),
  )
  use int <- result.try(
    id.1 |> int.parse |> result.replace_error("id is not an int"),
  )
  Ok(int)
}

pub fn require_id(
  query: List(#(String, String)),
  body: fn(Int) -> wisp.Response,
) -> wisp.Response {
  case get_id(query) {
    Ok(id) -> {
      body(id)
    }
    Error(err) -> {
      construct_error(err, 400)
    }
  }
}

pub fn construct_error(msg: String, code: Int) -> wisp.Response {
  wisp.json_response(
    json.object([#("error", json.string(msg))]) |> json.to_string_tree,
    code,
  )
}
