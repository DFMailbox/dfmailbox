import app/instance
import gleam/option.{Some}
import gleeunit/should

pub fn instance_parse_test() {
  let inst =
    instance.parse("google.com")
    |> should.be_ok
  inst.host
  |> should.equal("google.com")
}

pub fn instance_port_test() {
  let lh =
    instance.parse("localhost:8080")
    |> should.be_ok
  lh.host |> should.equal("localhost")
  lh.port |> should.equal(Some(8080))

  let inst =
    instance.parse("127.0.0.1")
    |> should.be_ok
  inst.host
  |> should.equal("127.0.0.1")
}

pub fn instance_malicious_parse_test() {
  instance.parse("sus.com/scary_path")
  |> should.be_error
  instance.parse("sus.com bad")
  |> should.be_error
}
