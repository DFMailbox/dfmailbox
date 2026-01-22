import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/json
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/time/timestamp
import json_value

type Store {
  Store(list: List(StoreRow), id: Int)
}

pub type StoreRow {
  StoreRow(
    id: Int,
    time: timestamp.Timestamp,
    plot_origin: Int,
    val: json_value.JsonValue,
  )
}

pub fn encode_store_row(store_row: StoreRow) -> json.Json {
  let StoreRow(id:, time:, plot_origin:, val:) = store_row
  json.object([
    #("id", json.int(id)),
    #("time", time |> timestamp.to_unix_seconds |> float.round |> json.int()),
    #("plot_origin", json.int(plot_origin)),
    #("val", json_value.to_json(val)),
  ])
}

pub type ReadResult {
  ReadResult(result: List(StoreRow), until: Int, current_id: Int)
}

pub fn read_result_to_json(read_result: ReadResult) -> json.Json {
  let ReadResult(result:, until:, current_id:) = read_result
  json.object([
    #("result", json.array(result, encode_store_row)),
    #("until", json.int(until)),
    #("current_id", json.int(current_id)),
  ])
}

pub type PlotMailbox =
  process.Subject(PlotMailboxQuery)

pub type PlotMailboxQuery {
  Send(value: List(json_value.JsonValue), origin: Int, reply_with: Subject(Int))
  // Dequeue doesn't exist because it isn't idempotent, this matters because this will be exposed in the REST API
  Receive(
    after: Int,
    limit: option.Option(Int),
    reply_with: Subject(ReadResult),
    cleanup: Bool,
  )
  Cleanup(before_at: Int)
  Shutdown
}

fn handle_message(store: Store, message: PlotMailboxQuery) {
  case message {
    Send(vals, origin, reply) -> {
      let new_id = store.id + { list.length(vals) }
      process.send(reply, store.id)
      let vals =
        list.index_map(vals, fn(x, i) {
          StoreRow(
            id: store.id + i,
            val: x,
            plot_origin: origin,
            time: timestamp.system_time(),
          )
        })
      let new = list.append(store.list, vals)
      Store(list: new, id: new_id) |> actor.continue()
    }
    Receive(after, limit, reply, cleanup) -> {
      // duped code with Peek
      let #(_passed, list) =
        store.list
        |> list.split_while(fn(x) { x.id <= after })

      let send_list = case limit {
        option.Some(limit) -> list.split(list, limit).0
        option.None -> list
      }

      let until =
        list.last(send_list)
        |> result.map(fn(x) { x.id })
        |> result.unwrap(after)

      ReadResult(result: send_list, until:, current_id: store.id)
      |> process.send(reply, _)

      case cleanup {
        True -> Store(..store, list:)
        False -> store
      }
      |> actor.continue()
    }
    Cleanup(id) -> {
      let #(_passed, list) =
        store.list
        |> list.split_while(fn(x) { x.id <= id })

      Store(..store, list: list)
      |> actor.continue()
    }
    Shutdown -> actor.stop()
  }
}

const timeout = 1000

pub fn new(id: Int) {
  let assert Ok(subj) =
    actor.new(Store([], id))
    |> actor.on_message(handle_message)
    |> actor.start()
  subj
}

/// Clean up all items in the mailbox but keep everything after `keep_after` (not including current item)
pub fn cleanup(mailbox: PlotMailbox, keep_after_id: Int) {
  actor.send(mailbox, Cleanup(before_at: keep_after_id))
}

/// Add items to the end of the mailbox.
/// Returns the msg_id before the insertions
pub fn send(
  mailbox: PlotMailbox,
  items: List(json_value.JsonValue),
  plot_origin origin: Int,
) -> Int {
  actor.call(mailbox, timeout, Send(value: items, reply_with: _, origin:))
}

/// Get all items after a specific id and maybe run cleanup
pub fn recieve(
  mailbox: PlotMailbox,
  after: Int,
  limit: option.Option(Int),
  peek: Bool,
) -> ReadResult {
  actor.call(mailbox, timeout, Receive(
    after:,
    reply_with: _,
    limit:,
    cleanup: peek,
  ))
}

pub fn shutdown(cache: PlotMailbox) {
  process.send(cache, Shutdown)
}
