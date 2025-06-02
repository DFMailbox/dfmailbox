import app/ctx
import ed25519/public_key
import gleam/bit_array
import gleam/bool
import gleam/dict
import gleam/http/request
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mist
import pog
import sql
import wisp
import youid/uuid

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- log_request(req)
  // I miss this in rust...
  use <- wisp.rescue_crashes()
  use req <- wisp.handle_head(req)

  handle_request(req)
}

pub fn log_request(
  req: wisp.Request,
  handler: fn() -> wisp.Response,
) -> wisp.Response {
  case req.path == "/healthcheck" {
    True -> handler()
    False -> {
      wisp.log_request(req, handler)
    }
  }
}

pub fn auth_midleware(
  req: wisp.Request,
  mist: request.Request(mist.Connection),
  ctx: ctx.Context,
  handle_request: fn(Authentication) -> wisp.Response,
) -> wisp.Response {
  let headers = req.headers |> dict.from_list
  let user_agent = dict.get(headers, "user-agent")

  let auth =
    result.lazy_unwrap(
      mist.get_client_info(mist.body)
        |> process_plot_auth(ctx.conn, _, user_agent, ctx.df_ips),
      fn() {
        result.unwrap(
          process_ext_auth(ctx.conn, dict.get(headers, "x-api-key")),
          NoAuth,
        )
      },
    )
  handle_request(auth)
}

fn process_ext_auth(
  conn: pog.Connection,
  key: Result(String, Nil),
) -> Result(Authentication, Nil) {
  use key <- result.try(key)
  let bits = key |> bit_array.from_string()
  let assert Ok(plot) = sql.plot_from_api_key(conn, bits) |> echo
  use plot <- result.try(list.first(plot.rows))

  case plot.public_key {
    option.None ->
      LocalPlotApi(
        id: plot.id,
        owner: plot.owner,
        api_key: key,
        mailbox_msg_id: plot.mailbox_msg_id,
      )

    option.Some(instance) -> {
      let assert Ok(instance) = public_key.deserialize_all(instance)
      RemotePlotApi(
        id: plot.id,
        owner: plot.owner,
        api_key: key,
        instance: instance,
        mailbox_msg_id: plot.mailbox_msg_id,
      )
    }
  }
  |> Ok
}

fn process_plot_auth(
  conn: pog.Connection,
  info: Result(mist.ConnectionInfo, Nil),
  user_agent: Result(String, Nil),
  df_ips: List(mist.IpAddress),
) -> Result(Authentication, Nil) {
  use info <- result.try(info)
  use <- bool.guard(!list.contains(df_ips, info.ip_address), Error(Nil))

  use user_agent <- result.try(user_agent)
  use #(plot_id, username) <- result.try(parse_user_agent(user_agent))
  let assert Ok(plot_row) = sql.get_plot(conn, plot_id)
  case list.first(plot_row.rows) {
    Ok(plot) -> {
      case plot.public_key {
        option.Some(key) -> {
          let assert Ok(key) = public_key.deserialize_all(key)
          RemotePlot(
            id: plot.id,
            owner: plot.owner,
            instance: key,
            mailbox_msg_id: plot.mailbox_msg_id,
          )
        }
        option.None ->
          LocalPlot(
            id: plot.id,
            owner: plot.owner,
            mailbox_msg_id: plot.mailbox_msg_id,
          )
      }
    }
    Error(Nil) -> UnregisteredPlot(id: plot_id, owner: username)
  }
  |> Ok
}

pub type Authentication {
  NoAuth
  UnregisteredPlot(id: Int, owner: String)
  LocalPlot(id: Int, owner: uuid.Uuid, mailbox_msg_id: Int)
  RemotePlot(
    id: Int,
    owner: uuid.Uuid,
    instance: public_key.PublicKey,
    mailbox_msg_id: Int,
  )
  LocalPlotApi(id: Int, owner: uuid.Uuid, mailbox_msg_id: Int, api_key: String)
  RemotePlotApi(
    id: Int,
    owner: uuid.Uuid,
    instance: public_key.PublicKey,
    mailbox_msg_id: Int,
    api_key: String,
  )
}

/// Can either be RegisteredPlot or ExternalServer
pub type GenericPlot {
  GenericPlot(id: Int, owner: uuid.Uuid, mailbox_msg_id: Int)
}

pub fn match_generic(auth: Authentication) -> Result(GenericPlot, Nil) {
  case auth {
    LocalPlot(a, b, c) -> Ok(GenericPlot(a, b, c))
    LocalPlotApi(a, b, c, _) -> Ok(GenericPlot(a, b, c))
    _ -> Error(Nil)
  }
}

pub fn match_authenticated(auth: Authentication) -> Result(Int, Nil) {
  case auth {
    LocalPlot(a, _, _) -> Ok(a)
    LocalPlotApi(a, _, _, _) -> Ok(a)
    RemotePlot(a, _, _, _) -> Ok(a)
    RemotePlotApi(a, _, _, _, _) -> Ok(a)
    UnregisteredPlot(a, _) -> Ok(a)
    NoAuth -> Error(Nil)
  }
}

fn parse_user_agent(header: String) -> Result(#(Int, String), Nil) {
  let start = "Hypercube/"
  use <- bool.guard(!string.starts_with(header, start), Error(Nil))
  // Hypercube/7.2 (23612, DynamicCake)
  use #(_, right) <- result.try(string.split_once(header, "("))
  // 23612, DynamicCake)
  use #(plot_id, username) <- result.try(string.split_once(right, ", "))
  // 23612
  // DynamicCake)
  use #(username, _) <- result.try(string.split_once(username, ")"))
  // DynamicCake
  use plot_id <- result.try(int.parse(plot_id))
  Ok(#(plot_id, username))
}
