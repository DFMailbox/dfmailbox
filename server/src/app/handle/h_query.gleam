import actor/plot_mailbox
import app/ctx
import app/handle/helper
import app/role
import dynjson
import gleam/bool
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import sql
import wisp

pub fn run_query(json: dynamic.Dynamic, role: role.Role, ctx: ctx.Context) {
  use body <- helper.guard_json(json, query_body_decoder())
  use plot <- helper.try_res(role |> role.match_host)

  let self_mailbox = ctx.get_mailbox(ctx, plot.id, plot.mailbox_msg_id)
  body.queries
  |> list.map(fn(query) {
    case query {
      DoCleanup(before_at:) -> {
        plot_mailbox.cleanup(self_mailbox, before_at)
        Cleanup
      }
      DoEnqueue(value:, to:) -> {
        let mailbox = case to {
          option.Some(to) -> {
            let assert Ok(trust) = sql.check_trust(ctx.conn, to, plot.id)
            let mailbox =
              ctx.get_mailbox_lazy(ctx, to)
              |> result.replace_error("plot_not_exists")
            use <- bool.guard(trust.count != 1, Error("plot_not_trusted"))
            mailbox
          }
          option.None -> Ok(self_mailbox)
        }
        case mailbox {
          Ok(mailbox) -> {
            let res = plot_mailbox.send(mailbox, value, plot.id)

            let assert Ok(_) =
              sql.set_mailbox_msg_id(
                ctx.conn,
                to |> option.unwrap(plot.id),
                res,
              )
            res
            |> Enqueue
          }
          Error(err) -> err |> ReplyError
        }
      }
      DoDequeue(after:, limit:) -> {
        plot_mailbox.recieve(self_mailbox, after, limit, True)
        |> Dequeue
      }
      DoPeek(after:, limit:) -> {
        plot_mailbox.recieve(self_mailbox, after, limit, False)
        |> Peek
      }
    }
  })
  |> QueryResponse
  |> query_response_to_json()
  |> json.to_string_tree()
  |> wisp.json_response(200)
}

type QueryResponse {
  QueryResponse(responses: List(MailboxReply))
}

fn query_response_to_json(query_response: QueryResponse) -> json.Json {
  let QueryResponse(responses:) = query_response
  json.array(responses, mailbox_reply_to_json)
}

type MailboxReply {
  Peek(result: plot_mailbox.ReadResult)
  Dequeue(result: plot_mailbox.ReadResult)
  Enqueue(msg_id: Int)
  ReplyError(msg: String)
  Cleanup
}

fn mailbox_reply_to_json(mailbox_reply: MailboxReply) -> json.Json {
  case mailbox_reply {
    Peek(result:) ->
      json.object([
        #("type", json.string("peek")),
        #("result", plot_mailbox.read_result_to_json(result)),
      ])
    Dequeue(result:) ->
      json.object([
        #("type", json.string("dequeue")),
        #("result", plot_mailbox.read_result_to_json(result)),
      ])
    Enqueue(msg_id:) ->
      json.object([
        #("type", json.string("enqueue")),
        #("msg_id", json.int(msg_id)),
      ])
    ReplyError(msg:) ->
      json.object([#("type", json.string("error")), #("msg", json.string(msg))])

    Cleanup -> json.object([#("type", json.string("cleanup"))])
  }
}

type QueryBody {
  QueryBody(queries: List(MailboxOperation))
}

fn query_body_decoder() -> decode.Decoder(QueryBody) {
  use queries <- decode.then(decode.list(mailbox_operation_decoder()))
  decode.success(QueryBody(queries:))
}

type MailboxOperation {
  DoPeek(after: Int, limit: option.Option(Int))
  DoDequeue(after: Int, limit: option.Option(Int))
  DoEnqueue(value: List(dynjson.DynJson), to: option.Option(Int))
  DoCleanup(before_at: Int)
}

fn mailbox_operation_decoder() -> decode.Decoder(MailboxOperation) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "peek" -> {
      use after <- decode.field("after", decode.int)
      use limit <- decode.optional_field(
        "limit",
        option.None,
        decode.optional(decode.int),
      )
      decode.success(DoPeek(after:, limit:))
    }
    "dequeue" -> {
      use after <- decode.field("after", decode.int)
      use limit <- decode.optional_field(
        "limit",
        option.None,
        decode.optional(decode.int),
      )
      decode.success(DoDequeue(after:, limit:))
    }
    "enqueue" -> {
      use value <- decode.field("value", decode.list(dynjson.decoder()))
      use to <- decode.field("to", decode.optional(decode.int))
      decode.success(DoEnqueue(value:, to:))
    }
    "cleanup" -> {
      use before_at <- decode.field("before_at", decode.int)
      decode.success(DoCleanup(before_at:))
    }
    _ -> decode.failure(DoCleanup(0), "MailboxOperation")
  }
}
