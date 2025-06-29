import app/address
import app/problem.{Problem}
import ed25519/public_key
import gleam/dict
import gleam/json
import gleam/option.{None}
import wisp
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

/// ✓ host
/// x registered, unregistered, no auth
pub fn match_host(role: Role) -> Result(GenericPlot, wisp.Response) {
  case role {
    Host(a, b, c) -> Ok(GenericPlot(a, b, c))
    role -> Error(expected_role_host(role) |> problem.to_response)
  }
}

/// ✓ host, registered, unregistered
/// x no auth
pub fn match_authenticated(role: Role) -> Result(Int, wisp.Response) {
  case role {
    Unregistered(id, _) -> Ok(id)
    Host(id, _, _) -> Ok(id)
    Registered(id, _, _, _, _) -> Ok(id)
    NoAuth -> Error(unauthorized() |> problem.to_response)
  }
}

/// ✓ host, registered
/// x unregistered, no auth
pub fn match_registered(role: Role) -> Result(GenericPlot, wisp.Response) {
  case role {
    Host(a, b, c) -> GenericPlot(a, b, c) |> Ok
    Registered(a, b, c, _, _) -> GenericPlot(a, b, c) |> Ok
    Unregistered(_, _) -> Error(expected_role_any() |> problem.to_response)
    NoAuth -> Error(unauthorized() |> problem.to_response)
  }
}

/// ✓ host, registered
/// x unregistered, no auth
pub fn match_registered_callback(
  role: Role,
  host host: fn(GenericPlot) -> a,
  registered registered: fn(
    GenericPlot,
    public_key.PublicKey,
    address.InstanceAddress,
  ) ->
    a,
) -> Result(a, wisp.Response) {
  case role {
    Host(a, b, c) -> GenericPlot(a, b, c) |> host |> Ok
    Registered(a, b, c, key, addr) ->
      GenericPlot(a, b, c) |> registered(key, addr) |> Ok
    Unregistered(_, _) -> Error(expected_role_any() |> problem.to_response)
    NoAuth -> Error(unauthorized() |> problem.to_response)
  }
}

/// ✓ unregistered
/// x host, registered, no auth
pub fn match_unregistered(role: Role) -> Result(#(Int, String), wisp.Response) {
  case role {
    Unregistered(id, name) -> #(id, name) |> Ok
    NoAuth -> Error(unauthorized() |> problem.to_response)
    role -> Error(expected_role_unregistered(role) |> problem.to_response)
  }
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
