import dfjson
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

/// This store uses a list as a queue enqueuing at the end and dequeuing at the beginning.
/// This is to make the reads and cleanup fast (they block the thread) and the inserts slower.
type Store {
  Store(list: List(StoreRow), id: Int)
}

type StoreRow {
  StoreRow(id: Int, val: dfjson.DFJson)
}

pub type PlotQueue =
  process.Subject(PlotQueueQuery)

pub type PlotQueueQuery {
  Enqueue(value: List(dfjson.DFJson), reply_with: Subject(Int))
  // Dequeue doesn't exist because it isn't idempotent, this matters because this will be exposed in the REST API
  Peek(after: Int, reply_with: Subject(List(dfjson.DFJson)))
  Cleanup(before_at: Int)
  Shutdown
}

fn handle_message(
  message: PlotQueueQuery,
  store: Store,
) -> actor.Next(PlotQueueQuery, Store) {
  case message {
    Cleanup(id) -> {
      let #(_, list) =
        store.list
        |> list.split_while(fn(x) { x.id >= id })

      Store(..store, list: list)
      |> actor.continue()
    }
    Enqueue(vals, reply) -> {
      process.send(reply, store.id)
      let new =
        vals
        |> list.index_map(fn(x, i) { StoreRow(id: store.id + i, val: x) })
        // kinda expensive
        |> list.append(store.list)

      Store(list: new, id: store.id + { list.length(new) }) |> actor.continue()
    }
    Peek(after, reply) -> {
      let #(_, list) =
        store.list
        |> list.split_while(fn(x) { x.id >= after })
      list
      |> list.map(fn(x) { x.val })
      |> process.send(reply, _)

      store
      |> actor.continue()
    }
    Shutdown -> actor.Stop(process.Normal)
  }
}

const timeout = 1000

pub fn new() {
  actor.start(Store([], 0), handle_message)
}

/// Clean up all items in the mailbox but keep everything after `keep_after` (not including current item)
pub fn cleanup(mailbox: PlotQueue, keep_after_id: Int) {
  actor.send(mailbox, Cleanup(before_at: keep_after_id))
}

/// Add items to the end of the mailbox
pub fn enqueue(mailbox: PlotQueue, items: List(dfjson.DFJson)) {
  actor.call(mailbox, Enqueue(value: items, reply_with: _), timeout)
}

/// Get all items after a specific id
pub fn peek(mailbox: PlotQueue, after_id after: Int) {
  actor.call(mailbox, Peek(after:, reply_with: _), timeout)
}

pub fn shutdown(cache: PlotQueue) {
  process.send(cache, Shutdown)
}
