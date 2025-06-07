import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import sql

pub opaque type InstanceDomain {
  InstanceDomain(host: String, port: option.Option(Int))
}

pub fn port(instance: InstanceDomain) {
  instance.port
}

pub fn host(instance: InstanceDomain) {
  instance.host
}

pub fn decode_instance() -> decode.Decoder(InstanceDomain) {
  use str <- decode.then(decode.string)
  case new(str) {
    Ok(inst) -> decode.success(inst)
    Error(_) -> decode.failure(InstanceDomain("", option.None), "domain")
  }
}

pub fn regex() -> regexp.Regexp {
  // It's just a regex? always has been
  let assert Ok(regex) =
    regexp.compile(
      "^(?:[a-zA-Z0-9]+(?:(?:\\-|\\.)[a-zA-Z0-9]+)*)(:(\\d+))?$",
      with: regexp.Options(True, False),
    )
  regex
}

pub fn new(str: String) -> Result(InstanceDomain, Nil) {
  case regexp.check(regex(), str) {
    True -> {
      case string.split_once(str, ":") {
        Ok(it) -> {
          use port <- result.try(int.parse(it.1))
          Ok(InstanceDomain(it.0, option.Some(port)))
        }
        Error(Nil) -> {
          Ok(InstanceDomain(str, option.None))
        }
      }
    }
    False -> Error(Nil)
  }
}

pub fn request(domain: InstanceDomain) -> request.Request(String) {
  let req =
    request.new()
    |> request.set_host(domain.host)
    |> request.set_scheme(http.Https)
  let req = case domain.port {
    option.None -> req
    option.Some(port) -> req |> request.set_port(port)
  }
  req
}

/// Use this instead of sql.indentify_instance
/// This will not bite me in the ass
pub fn identify(conn, public_key, domain: InstanceDomain) {
  sql.identify_instance(conn, public_key, domain.host)
}
