import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/pair
import gleam/result

pub type DynJson {
  Str(String)
  Integer(Int)
  Decimal(Float)
  Boolean(Bool)
  Array(List(DynJson))
  Object(dict.Dict(String, DynJson))
  Null
}

pub fn to_json(dynjson: DynJson) {
  case dynjson {
    Null -> json.null()
    Str(str) -> json.string(str)
    Decimal(num) -> json.float(num)
    Integer(num) -> json.int(num)
    Boolean(bool) -> json.bool(bool)

    Array(list) -> json.array(list, to_json)
    Object(obj) ->
      obj
      |> dict.to_list
      |> list.map(pair.map_second(_, to_json))
      |> json.object()
  }
}

fn try_error(
  result: Result(a, e),
  apply fun: fn(e) -> Result(a, g),
) -> Result(a, g) {
  case result {
    Ok(x) -> Ok(x)
    Error(e) -> fun(e)
  }
}

const zero = Null

fn determine(data: dynamic.Dynamic) -> Result(DynJson, List(decode.DecodeError)) {
  use _ <- try_error(decode.run(data, decode.string) |> result.map(Str))
  use _ <- try_error(decode.run(data, decode.int) |> result.map(Integer))
  use _ <- try_error(decode.run(data, decode.float) |> result.map(Decimal))
  use _ <- try_error(
    decode.run(data, decode.optional(decode.failure(Nil, "Failure")))
    |> result.replace(Null),
  )
  use _ <- try_error(decode.run(data, decode.bool) |> result.map(Boolean))
  use _ <- try_error(
    decode.run(data, decode.list(decoder())) |> result.map(Array),
  )
  use _ <- try_error(
    decode.run(data, decode.dict(decode.string, decoder()))
    |> result.map(Object),
  )
  Error(decode.decode_error("", data))
}

/// Only pass in json for it to not fail
pub fn decoder() -> decode.Decoder(DynJson) {
  use then <- decode.then(decode.dynamic)
  case determine(then) {
    Ok(it) -> decode.success(it)
    Error(_) -> decode.failure(zero, "DynJson")
  }
}

pub fn from_json(json: String) {
  json.parse(json, decoder())
}
