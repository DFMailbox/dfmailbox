import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/otp/actor

type Store(k, v) =
  dict.Dict(k, v)

pub type Cache(k, v) =
  process.Subject(Message(k, v))

pub type Message(k, v) {
  Set(key: k, value: v)
  Get(key: k, reply_with: Subject(Result(v, Nil)))
  Remove(key: k)
  Shutdown
}

fn handle_message(store: Store(k, v), message: Message(k, v)) {
  case message {
    Get(key, reply) -> {
      process.send(reply, dict.get(store, key))
      actor.continue(store)
    }
    Set(key, value) -> {
      dict.insert(store, key, value)
      |> actor.continue()
    }
    Remove(key) -> {
      dict.drop(store, [key])
      |> actor.continue()
    }
    Shutdown -> actor.stop()
  }
}

const timeout = 1000

pub fn new() {
  let assert Ok(it) =
    actor.new(dict.new())
    |> actor.on_message(handle_message)
    |> actor.start()
  it
}

pub fn get(cache: Cache(k, v), key: k) {
  actor.call(cache, timeout, Get(key, _))
}

pub fn set(cache: Cache(k, v), key: k, mailbox: v) {
  actor.send(cache, Set(key, mailbox))
}

pub fn remove(cache: Cache(k, v), key: k) {
  actor.send(cache, Remove(key))
}

pub fn shutdown(cache: Cache(k, v)) {
  process.send(cache, Shutdown)
}
