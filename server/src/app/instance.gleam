import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/regexp
import sql

pub opaque type InstanceDomain {
  InstanceDomain(host: String)
}

pub fn decode_instance() -> decode.Decoder(InstanceDomain) {
  use str <- decode.then(decode.string)
  case new(str) {
    Ok(inst) -> decode.success(inst)
    Error(_) -> decode.failure(InstanceDomain(""), "domain")
  }
}

pub fn new(str: String) -> Result(InstanceDomain, Nil) {
  let assert Ok(regex) =
    regexp.compile(
      "^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$",
      with: regexp.Options(True, False),
    )
  case regexp.check(regex, str) {
    True -> Ok(InstanceDomain(str))
    False -> Error(Nil)
  }
}

pub fn request(domain: InstanceDomain) -> request.Request(String) {
  request.new()
  |> request.set_host(domain.host)
  |> request.set_scheme(http.Http)
}

pub fn identify(conn, public_key, domain: InstanceDomain) {
  sql.identify_instance(conn, public_key, domain.host)
}
