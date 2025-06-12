import actor/cache
import app/address
import app/ctx
import app/ext
import app/handle/helper
import app/struct/server
import ed25519/public_key
import ed25519/signature
import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/dict
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import sql
import wisp
import youid/uuid

pub fn sign(query: helper.Query, ctx: ctx.Context) {
  let query = dict.from_list(query)
  use challenge <- helper.require_query(query, "challenge")
  use challenge <- helper.try_res(
    uuid.from_string(challenge)
    |> result.replace_error(helper.construct_error("challenge is not uuid", 400)),
  )

  let public_key =
    ctx.private_key
    |> public_key.derive_key()

  let challenge = address.generate_challenge(ctx.instance, challenge)

  let sig = signature.create(ctx.private_key, public_key, challenge)

  server.SigningResponse(public_key, sig, ctx.instance)
  |> server.signing_response_to_json
  |> json.to_string_tree()
  |> wisp.json_response(200)
}

pub fn identity_key(json: dynamic.Dynamic, ctx: ctx.Context) {
  use body <- helper.guard_json(json, server.identify_instance_body_decoder())
  use requester_key <- helper.try_res(
    ext.ping_sign(body.address)
    |> result.map_error(fn(err) {
      helper.construct_error(err |> ext.serialize_ping_error, 400)
    }),
  )
  let req_key_bits = requester_key |> public_key.serialize_to_bits

  use found_address <- helper.guard_db(sql.get_address(ctx.conn, req_key_bits))
  let res = case list.first(found_address.rows) {
    Ok(row) ->
      case row.address {
        option.Some(address) -> {
          use address <- result.try(
            address.parse(address)
            |> result.replace_error(helper.construct_error(
              "Address isn't valid",
              409,
            )),
          )
          use <- bool.guard(
            body.address != address,
            Error(helper.construct_error(
              // Maybe change this
              "Key does not match address",
              409,
            )),
          )
          Ok(Nil)
        }
        option.None ->
          Error(helper.construct_error("key marked as compromised", 400))
      }
    Error(Nil) -> {
      // Register this
      address.identify(ctx.conn, req_key_bits, body.address, ctx.instance)
      Ok(Nil)
    }
  }
  use Nil <- helper.try_res(res)

  let my_pubkey = public_key.derive_key(ctx.private_key)
  use <- bool.guard(
    my_pubkey != body.public_key,
    helper.construct_error("Not my key", 400),
  )

  let challenge = address.generate_challenge(ctx.instance, body.challenge)

  let sig = signature.create(ctx.private_key, my_pubkey, challenge)

  let source =
    crypto.strong_random_bytes(48) |> bit_array.base64_url_encode(False)
  let actual_key = crypto.hash(crypto.Sha256, source |> bit_array.from_string)
  cache.set(ctx.identity_key_map, actual_key, requester_key)

  server.IdentifyInstanceResponse(
    identity_key: source,
    signature: sig,
    public_key: my_pubkey,
    address: ctx.instance,
  )
  |> server.encode_identify_instance_response()
  |> json.to_string_tree()
  |> wisp.json_response(200)
}
