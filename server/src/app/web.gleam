import app/ctx
import ed25519/public_key
import gleam/bool
import gleam/dict
import gleam/http
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

  case
    mist.get_client_info(mist.body)
    |> process_plot_auth(ctx.conn, _, user_agent, ctx.df_ips)
  {
    Ok(it) -> handle_request(echo it)
    Error(Nil) ->
      case process_ext_auth() {
        Ok(it) -> handle_request(it)
        Error(Nil) -> handle_request(NoAuth)
      }
  }
}

fn process_ext_auth() -> Result(Authentication, Nil) {
  // TODO: implement
  Error(Nil)
}

fn process_plot_auth(
  conn: pog.Connection,
  info: Result(mist.ConnectionInfo, Nil),
  user_agent: Result(String, Nil),
  df_ips: List(mist.ConnectionInfo),
) -> Result(Authentication, Nil) {
  use info <- result.try(info)
  use <- bool.guard(!list.contains(df_ips, info), Error(Nil))

  use user_agent <- result.try(user_agent)
  use #(plot_id, username) <- result.try(parse_user_agent(user_agent))
  let assert Ok(plot_row) = sql.get_plot(conn, plot_id)
  Ok(case list.first(plot_row.rows) {
    Ok(plot) -> {
      let public_key = case plot.public_key {
        option.Some(key) -> {
          // Database should always contain good public keys
          let assert Ok(key) = public_key.deserialize_all(key)
          option.Some(key)
        }
        option.None -> option.None
      }
      RegisteredPlot(id: plot.id, owner: plot.owner, instance: public_key)
    }
    Error(Nil) -> UnregisteredPlot(id: plot_id, owner: username)
  })
}

pub type Authentication {
  NoAuth
  UnregisteredPlot(id: Int, owner: String)
  RegisteredPlot(
    id: Int,
    owner: uuid.Uuid,
    instance: option.Option(public_key.PublicKey),
  )
  // TODO: Implement
  ExternalServer
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
