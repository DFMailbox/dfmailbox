import birl
import dfjson
import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result

type Store {
  Store(list: List(StoreRow), id: Int)
}

pub type StoreRow {
  StoreRow(id: Int, time: birl.Time, plot_origin: Int, val: dfjson.DFJson)
}

pub fn encode_store_row(store_row: StoreRow) -> json.Json {
  let StoreRow(id:, time:, plot_origin:, val:) = store_row
  json.object([
    #("id", json.int(id)),
    #("time", time |> birl.to_unix |> json.int()),
    #("plot_origin", json.int(plot_origin)),
    #("val", dfjson.encode_df_json(val)),
  ])
}

pub type PeekResult {
  PeekResult(result: List(StoreRow), until: Int, current_id: Int)
}

pub type PlotMailbox =
  process.Subject(PlotMailboxQuery)

pub type PlotMailboxQuery {
  Post(value: List(dfjson.DFJson), origin: Int, reply_with: Subject(Int))
  // Dequeue doesn't exist because it isn't idempotent, this matters because this will be exposed in the REST API
  Peek(after: Int, limit: option.Option(Int), reply_with: Subject(PeekResult))
  Cleanup(before_at: Int)
  Shutdown
}

fn handle_message(
  message: PlotMailboxQuery,
  store: Store,
) -> actor.Next(PlotMailboxQuery, Store) {
  case message {
    Cleanup(id) -> {
      let #(_, list) =
        store.list
        |> list.split_while(fn(x) { x.id <= id })

      Store(..store, list: list)
      |> actor.continue()
    }
    Post(vals, origin, reply) -> {
      let new_id = store.id + { list.length(vals) }
      process.send(reply, new_id)
      let vals =
        list.index_map(vals, fn(x, i) {
          StoreRow(
            id: store.id + i,
            val: x,
            plot_origin: origin,
            time: birl.utc_now(),
          )
        })
      let new = list.append(store.list, vals)
      Store(list: new, id: new_id) |> actor.continue()
    }
    Peek(after, limit, reply) -> {
      let #(_passed, list) =
        store.list
        |> list.split_while(fn(x) { x.id <= after })
      let list = case limit {
        option.Some(limit) -> list.split(list, limit).0
        option.None -> list
      }

      let until =
        list.last(list) |> result.map(fn(x) { x.id }) |> result.unwrap(after)

      PeekResult(result: list, until:, current_id: store.id)
      |> process.send(reply, _)

      actor.continue(store)
    }
    Shutdown -> actor.Stop(process.Normal)
  }
}

const timeout = 1000

pub fn new(id: Int) {
  let assert Ok(subj) = actor.start(Store([], id), handle_message)
  subj
}

/// Clean up all items in the mailbox but keep everything after `keep_after` (not including current item)
pub fn cleanup(mailbox: PlotMailbox, keep_after_id: Int) {
  actor.send(mailbox, Cleanup(before_at: keep_after_id))
}

/// Add items to the end of the mailbox.
/// Returns the msg_id before the insertions
pub fn post(
  mailbox: PlotMailbox,
  items: List(dfjson.DFJson),
  plot_origin origin: Int,
) -> Int {
  actor.call(mailbox, Post(value: items, reply_with: _, origin:), timeout)
}

/// Get all items after a specific id
pub fn peek(mailbox: PlotMailbox, after: Int, limit: option.Option(Int)) {
  actor.call(mailbox, Peek(after:, reply_with: _, limit:), timeout)
}

pub fn shutdown(cache: PlotMailbox) {
  process.send(cache, Shutdown)
}
