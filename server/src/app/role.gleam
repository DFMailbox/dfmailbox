import app/address
import app/problem.{Problem}
import ed25519/public_key
import gleam/dict
import gleam/json
import gleam/option.{None}
import youid/uuid

pub type Role {
  NoAuth
  Unregistered(id: Int, owner: String)
  Host(id: Int, owner: uuid.Uuid, mailbox_msg_id: Int)
  Registered(
    id: Int,
    owner: uuid.Uuid,
    mailbox_msg_id: Int,
    instance: public_key.PublicKey,
    address: address.InstanceAddress,
  )
}

pub fn to_string(role: Role) {
  case role {
    Host(_, _, _) -> "host"
    NoAuth -> "none"
    Registered(_, _, _, _, _) -> "registered"
    Unregistered(_, _) -> "unregistered"
  }
}

pub type GenericPlot {
  GenericPlot(id: Int, owner: uuid.Uuid, mailbox_msg_id: Int)
}

pub fn expected_role_any() {
  Problem(
    kind: "/v0/problems/expected-role/any",
    title: "Expected any registration",
    status: 403,
    detail: None,
    instance: None,
    extension: dict.from_list([
      #("expected", ["host", "registered"] |> json.array(json.string)),
      #("received", "unregistered" |> json.string),
    ]),
  )
}

pub fn expected_role_unregistered(received: Role) {
  Problem(
    kind: "/v0/problems/expected-role/unregistered",
    title: "Expected no registion",
    status: 403,
    detail: None,
    instance: None,
    extension: dict.from_list([
      #("expected", ["unregistered"] |> json.array(json.string)),
      #("received", received |> to_string |> json.string),
    ]),
  )
}

pub fn expected_role_host(received: Role) {
  Problem(
    kind: "/v0/problems/expected-role/host",
    title: "Expected host registion",
    status: 403,
    detail: None,
    instance: None,
    extension: dict.from_list([
      #("expected", ["host"] |> json.array(json.string)),
      #("received", received |> to_string |> json.string),
    ]),
  )
}

pub fn unauthorized() {
  Problem(
    kind: "https://tools.ietf.org/html/rfc9110#section-15.5.2",
    title: "Unauthorized",
    status: 401,
    detail: None,
    instance: None,
    extension: dict.new(),
  )
}
