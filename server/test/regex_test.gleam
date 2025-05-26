import app/instance
import gleam/option.{Some}
import gleeunit/should

pub fn instance_parse_test() {
  instance.new("google.com")
  |> should.be_ok
  |> instance.host
  |> should.equal("google.com")
}

pub fn instance_port_test() {
  let lh =
    instance.new("localhost:8080")
    |> should.be_ok
  lh |> instance.host |> should.equal("localhost")
  lh |> instance.port |> should.equal(Some(8080))

  instance.new("127.0.0.1")
  |> should.be_ok
  |> instance.host
  |> should.equal("127.0.0.1")
}

pub fn instance_malicious_parse_test() {
  instance.new("sus.com/scary_path")
  |> should.be_error
  instance.new("sus.com bad")
  |> should.be_error
}
