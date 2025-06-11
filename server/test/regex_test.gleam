import app/address
import gleam/option.{Some}
import gleeunit/should

pub fn instance_parse_test() {
  let inst =
    address.parse("google.com")
    |> should.be_ok
  inst.host
  |> should.equal("google.com")
}

pub fn instance_port_test() {
  let lh =
    address.parse("localhost:8080")
    |> should.be_ok
  lh.host |> should.equal("localhost")
  lh.port |> should.equal(Some(8080))

  let inst =
    address.parse("127.0.0.1")
    |> should.be_ok
  inst.host
  |> should.equal("127.0.0.1")
}

pub fn instance_malicious_parse_test() {
  address.parse("sus.com/scary_path")
  |> should.be_error
  address.parse("sus.com bad")
  |> should.be_error
}
