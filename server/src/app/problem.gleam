import app/address
import ed25519/public_key
import gleam/bit_array
import gleam/dict
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import wisp
import youid/uuid

/// Represents an RFC 9457 problem
pub type Problem {
  Problem(
    kind: String,
    title: String,
    status: Int,
    detail: option.Option(String),
    instance: option.Option(String),
    extension: dict.Dict(String, json.Json),
  )
}

pub fn to_response(problem: Problem) {
  wisp.response(problem.status)
  |> wisp.set_header("content-type", "application/problem+json; charset=utf-8")
  |> wisp.set_body(wisp.Text(problem |> to_json |> json.to_string))
}

fn optional_push(dict: List(#(a, b)), a: a, b: option.Option(b)) {
  case b {
    Some(b) -> list.prepend(dict, #(a, b))
    None -> dict
  }
}

pub fn to_json(problem p: Problem) -> json.Json {
  dict.drop(p.extension, ["type", "status", "title", "detail", "instance"])
  |> dict.to_list
  |> optional_push("detail", p.detail |> option.map(json.string))
  |> optional_push("instance", p.instance |> option.map(json.string))
  |> list.prepend(#("type", p.kind |> json.string))
  |> list.prepend(#("status", p.status |> json.int))
  |> list.prepend(#("title", p.title |> json.string))
  |> list.reverse
  |> json.object
}

/// public_key - url base64 key
pub fn unknown_instance(status: Int, public_key: public_key.PublicKey) {
  let public_key = public_key.to_base64_url(public_key)
  Problem(
    kind: "/v0/problems/unknown-instance",
    title: "Specified instance has not been identified",
    status:,
    detail: Some(
      "Instance with public key " <> public_key <> " is not identified",
    ),
    instance: None,
    extension: dict.from_list([#("public_key", public_key |> json.string)]),
  )
}

pub fn unregistered_plot(status: Int, plot_id: Int) {
  Problem(
    kind: "/v0/problems/unregistered-plot",
    title: "Target plot is not registered",
    status:,
    detail: Some(
      "The plot with id " <> int.to_string(plot_id) <> "is not registered",
    ),
    instance: None,
    extension: dict.from_list([#("plot_id", plot_id |> json.int)]),
  )
}

pub fn unregistered_plots(status: Int, plot_ids: List(Int)) {
  Problem(
    kind: "/v0/problems/unregistered-plots",
    title: "There are unregistered plots",
    status:,
    detail: Some(
      "Plots with ids ["
      <> { plot_ids |> list.map(int.to_string) |> string.join(", ") }
      <> "] are not registered",
    ),
    instance: None,
    extension: dict.from_list([#("plot_ids", json.array(plot_ids, json.int))]),
  )
}

pub fn invalid_challenge(status: Int, challenge: uuid.Uuid) {
  Problem(
    kind: "/v0/problems/invalid-challenge",
    title: "Challenge isn't valid",
    status:,
    detail: None,
    instance: None,
    extension: dict.from_list([
      #("challenge", challenge |> uuid.to_string |> json.string),
    ]),
  )
}

pub fn challenge_failed(status: Int, challenge: BitArray) {
  let challenge = challenge |> bit_array.base64_encode(True)
  Problem(
    kind: "/v0/problems/challenge-failed",
    title: "Invalid challenge signature",
    status:,
    detail: Some(
      "Challenge bytes " <> challenge <> " have not been signed correctly",
    ),
    instance: None,
    extension: dict.from_list([#("challenge_bytes", challenge |> json.string)]),
  )
}

pub fn sender_not_registered(status: Int, sender: Int) {
  Problem(
    kind: "/v0/problems/send/sender-not-registered",
    title: "Sender in receiver instance is not registered",
    status:,
    detail: Some(
      "The plot with id "
      <> int.to_string(sender)
      <> " is not registered on this instance.\n",
      // <> "Register this plot on this instance with your host public key to use.",
    ),
    instance: None,
    extension: dict.from_list([#("sender", sender |> json.int)]),
  )
}

pub fn sender_is_owned(status: Int, sender: Int) {
  Problem(
    kind: "/v0/problems/send/sender-is-owned",
    title: "Plot sender is owned by receiver instance",
    status:,
    detail: Some(
      "Sender plot with id "
      <> int.to_string(sender)
      <> " is owned by this instance.\n",
      // <> "Use this instance to send mail instead.",
    ),
    instance: None,
    extension: dict.from_list([#("sender", sender |> json.int)]),
  )
}

pub fn sender_key_mismatch(
  status: Int,
  sender: Int,
  expected_key: public_key.PublicKey,
  actual_key: public_key.PublicKey,
) {
  Problem(
    kind: "/v0/problems/send/sender-key-mismatch",
    title: "Sender's public key does not match receiver's instance's registered sender public key",
    status:,
    detail: Some(
      "Sender plot with id "
      <> int.to_string(sender)
      <> " has mismatched keys on the receiver's instance.\n"
      <> "This error may be hard to understand and it is advised to look at the \"type\" field url",
    ),
    instance: None,
    extension: dict.from_list([
      #("sender", sender |> json.int),
      #("expected_key", expected_key |> public_key.to_base64_url |> json.string),
      #("actual_key", actual_key |> public_key.to_base64_url |> json.string),
    ]),
  )
}

pub fn receiver_not_registered(status: Int, receiver: Int) {
  Problem(
    kind: "/v0/problems/send/receiver-not-registered",
    title: "Receiver is not registered",
    status:,
    detail: Some(
      "Receiver plot with id "
      <> int.to_string(receiver)
      <> " is not registered.",
    ),
    instance: None,
    extension: dict.from_list([#("receiver", receiver |> json.int)]),
  )
}

pub fn receiver_not_owned(status: Int, receiver: Int) {
  Problem(
    kind: "/v0/problems/send/receiver-not-owned",
    title: "Receiver is not owned by receiver's instance",
    status:,
    detail: Some(
      "Receiver plot with id " <> int.to_string(receiver) <> " is not owned.",
    ),
    instance: None,
    extension: dict.from_list([#("receiver", receiver |> json.int)]),
  )
}

pub fn sender_isnt_trusted(status: Int, sender: Int, receiver: Int) {
  Problem(
    kind: "/v0/problems/send/sender-not-trusted",
    title: "Sender is not trusted",
    status:,
    detail: Some(
      "Receiver "
      <> int.to_string(receiver)
      <> " does not trust sender "
      <> int.to_string(sender),
    ),
    instance: None,
    extension: dict.from_list([
      #("sender", sender |> json.int),
      #("reciever", receiver |> json.int),
    ]),
  )
}

pub fn instance_key_compromised(status: Int, public_key: public_key.PublicKey) {
  let public_key = public_key.to_base64_url(public_key)
  Problem(
    kind: "/v0/problems/instance-key-compromised",
    title: "Instance key has been compromised",
    status:,
    detail: Some(
      "The private key has been compromised for the instance with the public key of "
      <> public_key,
    ),
    instance: None,
    extension: dict.from_list([#("instance_key", public_key |> json.string)]),
  )
}

pub fn instance_unreachable(
  status: Int,
  address: address.InstanceAddress,
  message: String,
) {
  Problem(
    kind: "/v0/problems/federation/instance-unreachable",
    title: "Cannot reach the introduced instance",
    status:,
    detail: Some(message),
    instance: None,
    extension: dict.from_list([
      #("address", address |> address.instance_address_to_json),
    ]),
  )
}

pub fn non_compliance(status: Int, detail: String) {
  Problem(
    kind: "/v0/problems/federation/non-compliance",
    title: "Instance is not complying with protocol",
    status:,
    detail: Some(detail),
    instance: None,
    extension: dict.new(),
  )
}

pub fn intro_mismatched_address(
  status: Int,
  expected_address: address.InstanceAddress,
  actual_address: address.InstanceAddress,
) {
  Problem(
    kind: "/v0/problems/instance-introduction/mismatched-address",
    title: "Provided address does not match server's primary address",
    status:,
    detail: Some(
      "Address "
      <> address.to_string(actual_address)
      <> " does not match primary address "
      <> address.to_string(expected_address),
    ),
    instance: None,
    extension: dict.from_list([
      #(
        "expected_address",
        expected_address |> address.instance_address_to_json,
      ),
      #("actual_address", actual_address |> address.instance_address_to_json),
    ]),
  )
}

pub fn intro_mismatched_public_key(
  status: Int,
  expected_public_key: public_key.PublicKey,
  actual_public_key: public_key.PublicKey,
) {
  let expected_public_key = public_key.to_base64_url(expected_public_key)
  let actual_public_key = public_key.to_base64_url(actual_public_key)
  Problem(
    kind: "/v0/problems/instance-introduction/mismatched-public-key",
    title: "Provided public key does not match server's public key",
    status:,
    detail: Some(
      "Server provided "
      <> expected_public_key
      <> " but provided and verified "
      <> actual_public_key,
    ),
    instance: None,
    extension: dict.from_list([
      #("expected_public_key", expected_public_key |> json.string),
      #("actual_public_key", actual_public_key |> json.string),
    ]),
  )
}

pub fn already_exists(status: Int) {
  Problem(
    kind: "/v0/problems/already-exists",
    title: "The resource being created already exists",
    status:,
    detail: None,
    instance: None,
    extension: dict.new(),
  )
}

pub fn no_update_effect(status: Int) {
  Problem(
    kind: "/v0/problems/no-effect-update",
    title: "The update had no effect",
    status:,
    detail: None,
    instance: None,
    extension: dict.new(),
  )
}

pub type Paramater {
  Paramater(paramater: String, detail: String)
}

fn paramater_to_json(paramater: Paramater) -> json.Json {
  let Paramater(paramater:, detail:) = paramater
  json.object([
    #("paramater", json.string(paramater)),
    #("detail", json.string(detail)),
  ])
}

pub fn invalid_request_paramater(status: Int, params: List(Paramater)) {
  Problem(
    kind: "/v0/problems/invalid-request-parameter-format",
    title: "Invalid request parameter format",
    status:,
    detail: Some("The request contains a malformed query parameter."),
    instance: None,
    extension: dict.from_list([
      #("errors", params |> json.array(paramater_to_json)),
    ]),
  )
}
