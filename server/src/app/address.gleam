import compile_time
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
pub type InstanceAddress {
  InstanceAddress(host: String, port: option.Option(Int))
}

pub fn decode_address() -> decode.Decoder(InstanceAddress) {
  use str <- decode.then(decode.string)
  case parse(str) {
    Ok(inst) -> decode.success(inst)
    Error(_) -> decode.failure(InstanceAddress("", option.None), "address")
  }
}

pub fn instance_address_to_json(instance_address: InstanceAddress) -> json.Json {
  instance_address
  |> to_string()
  |> json.string()
}

pub fn to_string(instance_address: InstanceAddress) -> String {
  let InstanceAddress(host:, port:) = instance_address
  case port {
    option.Some(port) -> host <> ":" <> int.to_string(port)
    option.None -> host
  }
}

pub fn generate_challenge(address: InstanceAddress, uuid: uuid.Uuid) {
  bit_array.append(
    to_string(address) |> bit_array.from_string,
    uuid.to_bit_array(uuid),
  )
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

pub fn parse(str: String) -> Result(InstanceAddress, Nil) {
  case regexp.check(regex(), str) {
    True -> {
      case string.split_once(str, ":") {
        Ok(it) -> {
          use port <- result.try(int.parse(it.1))
          Ok(InstanceAddress(it.0, option.Some(port)))
        }
        Error(Nil) -> {
          Ok(InstanceAddress(str, option.None))
        }
      }
    }
    False -> Error(Nil)
  }
}

pub fn request(address: InstanceAddress) -> request.Request(String) {
  let req =
    request.new()
    |> request.set_host(address.host)
    |> request.set_scheme(compile_time.scheme)
  let req = case address.port {
    option.None -> req
    option.Some(port) -> req |> request.set_port(port)
  }
  req
}

/// Use this instead of sql.indentify_instance
/// This will not bite me in the ass
pub fn identify(
  conn,
  public_key,
  address: InstanceAddress,
  this_address: InstanceAddress,
) {
  case this_address == address {
    True -> Nil
    False -> {
      let assert Ok(_) =
        sql.identify_instance(conn, public_key, to_string(address))
      Nil
    }
  }
}
