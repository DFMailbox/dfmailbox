import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import sql
import youid/uuid

/// Misnomer probably gonna change
pub type InstanceDomain {
  InstanceDomain(host: String, port: option.Option(Int))
}

pub fn instance_domain_to_json(instance_domain: InstanceDomain) -> json.Json {
  let InstanceDomain(host:, port:) = instance_domain
  case port {
    option.None -> json.string(host)
    option.Some(port) -> json.string(host <> ":" <> int.to_string(port))
  }
}

pub fn generate_challenge(instance: InstanceDomain, uuid: uuid.Uuid) {
  bit_array.append(to_bit_array(instance), uuid.to_bit_array(uuid))
}

fn to_bit_array(instance: InstanceDomain) {
  case instance.port {
    option.None -> bit_array.from_string(instance.host)
    option.Some(port) ->
      bit_array.from_string(instance.host <> ":" <> int.to_string(port))
  }
}

pub fn decode_instance() -> decode.Decoder(InstanceDomain) {
  use str <- decode.then(decode.string)
  case parse(str) {
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

pub fn parse(str: String) -> Result(InstanceDomain, Nil) {
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
