import app/handle/decoders
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/otp/actor
import gleam/result
import gleam/string
import youid/uuid.{type Uuid}

type Store =
  dict.Dict(String, Uuid)

pub type Cache =
  process.Subject(Message)

pub type Message {
  Set(key: String, value: Uuid)
  Get(key: String, reply_with: Subject(Result(Uuid, Nil)))
  Shutdown
}

fn handle_message(message: Message, store: Store) -> actor.Next(Message, Store) {
  case message {
    Get(key, reply) -> {
      process.send(reply, dict.get(store, key))
      actor.continue(store)
    }
    Set(key, value) -> {
      dict.insert(store, key, value)
      |> actor.continue()
    }
    Shutdown -> actor.Stop(process.Normal)
  }
}

const timeout = 1000

pub fn new() {
  actor.start(dict.new(), handle_message)
}

pub fn get(cache: Cache, key: String) {
  actor.call(cache, Get(key, _), timeout)
}

pub fn set(cache: Cache, key: String, uuid: Uuid) {
  actor.send(cache, Set(key, uuid))
}

pub fn shutdown(cache: Cache) {
  process.send(cache, Shutdown)
}

pub fn fetch(cache: Cache, name: String) -> Result(Uuid, String) {
  case get(cache, name) {
    Ok(it) -> Ok(it)
    Error(_) -> {
      let assert Ok(req) =
        request.to("https://api.mojang.com/users/profiles/minecraft/" <> name)
      use res <- result.try(
        httpc.send(req)
        |> result.map_error(fn(err) {
          "Failed to send request to mojang API: "
          <> { err |> string.inspect() }
        }),
      )

      let body = case res.status {
        200 -> Ok(res.body)
        code -> Error("Mojang sent non 200 code: " <> code |> int.to_string)
      }
      use body <- result.try(body)
      use json <- result.try(
        json.parse(body, mojang_response_decoder())
        |> result.map_error(fn(err) {
          "Error parsing mojang json: " <> err |> string.inspect
        }),
      )
      set(cache, json.name, json.id)
      Ok(json.id)
    }
  }
}

type MojangResponse {
  MojangResponse(id: Uuid, name: String)
}

fn mojang_response_decoder() -> decode.Decoder(MojangResponse) {
  use id <- decode.field("id", decoders.decode_uuid())
  use name <- decode.field("name", decode.string)
  decode.success(MojangResponse(id:, name:))
}
