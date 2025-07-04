import actor/cache
import app/address
import app/ctx
import app/handle/helper
import app/role
import cors_builder
import ed25519/public_key
import gleam/bit_array
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

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- log_request(req)
  // I miss this in rust...
  use <- wisp.rescue_crashes()
  use req <- wisp.handle_head(req)
  let cors =
    cors_builder.new()
    |> cors_builder.allow_all_origins()
    |> cors_builder.allow_method(http.Get)
    |> cors_builder.allow_method(http.Post)
    |> cors_builder.allow_method(http.Put)
    |> cors_builder.allow_method(http.Delete)
    |> cors_builder.allow_method(http.Options)
    |> cors_builder.allow_header("content-type")
    |> cors_builder.allow_header("x-api-key")
    |> cors_builder.allow_header("user-agent")
    |> cors_builder.allow_header("x-identity-key")
    |> cors_builder.max_age(60 * 60)
  use req <- cors_builder.wisp_middleware(req, cors)

  handle_request(req)
}

pub fn log_request(
  req: wisp.Request,
  handler: fn() -> wisp.Response,
) -> wisp.Response {
  case req.path == "/healthcheck" {
    True -> wisp.ok()
    False -> {
      wisp.log_request(req, handler)
    }
  }
}

pub fn auth_federation(
  req: wisp.Request,
  ctx: ctx.Context,
  handle_request: fn(public_key.PublicKey) -> wisp.Response,
) -> wisp.Response {
  case get_token(req, ctx) {
    Ok(key) -> handle_request(key)
    Error(err) -> err
  }
}

fn get_token(
  req: wisp.Request,
  ctx: ctx.Context,
) -> Result(public_key.PublicKey, wisp.Response) {
  use token <- result.try(
    list.key_find(req.headers, "x-identity-token")
    |> helper.replace_construct_error("x-identity-token not found", 401),
  )
  use b64_token <- result.try(
    bit_array.base64_decode(token)
    |> helper.replace_construct_error("identity token is not base6", 401),
  )
  use key <- result.try(
    cache.get(ctx.ext_identity_key_map, b64_token)
    |> helper.replace_construct_error("identity token invalid", 401),
  )
  Ok(key)
}

pub fn auth_midleware(
  req: wisp.Request,
  mist: request.Request(mist.Connection),
  ctx: ctx.Context,
  handle_request: fn(role.Role) -> wisp.Response,
) -> wisp.Response {
  let headers = req.headers |> dict.from_list

  let auth =
    result.lazy_unwrap(
      mist.get_client_info(mist.body)
        |> process_plot_auth(
          ctx.conn,
          _,
          dict.get(headers, "user-agent"),
          dict.get(headers, "x-real-ip"),
          ctx.df_ips,
          ctx.nginx,
          ctx.testing_mode,
        ),
      fn() {
        result.unwrap(
          process_ext_auth(ctx.conn, dict.get(headers, "x-api-key")),
          role.NoAuth,
        )
      },
    )
  handle_request(auth)
}

fn process_ext_auth(
  conn: pog.Connection,
  key: Result(String, Nil),
) -> Result(role.Role, Nil) {
  use key <- result.try(key)
  let bits = key |> bit_array.from_string()
  let assert Ok(plot) = sql.plot_from_api_key(conn, bits)
  use plot <- result.try(list.first(plot.rows))

  case plot.public_key {
    option.None ->
      role.Host(
        id: plot.id,
        owner: plot.owner,
        mailbox_msg_id: plot.mailbox_msg_id,
      )

    option.Some(instance) -> {
      let assert Ok(instance) = public_key.deserialize_all(instance)
      let assert option.Some(addr) = plot.address
      let assert Ok(address) = address.parse(addr)
      role.Registered(
        id: plot.id,
        owner: plot.owner,
        instance: instance,
        address:,
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
  x_real_ip: Result(String, Nil),
  df_ips: List(mist.IpAddress),
  is_nginx: Bool,
  bypass_ip_check: Bool,
) -> Result(role.Role, Nil) {
  use info <- result.try(info)
  let ok = case is_nginx {
    True -> {
      case x_real_ip {
        Ok(ip) -> {
          case string.split(ip, ".") {
            [a, b, c, d] -> {
              {
                use a <- result.try(int.parse(a))
                use b <- result.try(int.parse(b))
                use c <- result.try(int.parse(c))
                use d <- result.try(int.parse(d))
                mist.IpV4(a, b, c, d)
                |> list.contains(df_ips, _)
                |> Ok
              }
              |> result.replace_error(False)
              |> result.unwrap_both()
            }
            _ -> False
          }
        }

        Error(Nil) -> False
      }
    }
    False -> {
      echo info.ip_address
      list.contains(df_ips, info.ip_address)
    }
  }
  let ok = case bypass_ip_check {
    True -> True
    False -> ok
  }
  use <- bool.guard(!ok, Error(Nil))

  use user_agent <- result.try(user_agent)
  use #(plot_id, username) <- result.try(parse_user_agent(user_agent))
  let assert Ok(plot_row) = sql.get_plot(conn, plot_id)
  case list.first(plot_row.rows) {
    Ok(plot) -> {
      case plot.public_key {
        option.Some(key) -> {
          let assert Ok(key) = public_key.deserialize_all(key)
          let assert option.Some(addr) = plot.address
          let assert Ok(address) = address.parse(addr)
          role.Registered(
            id: plot.id,
            owner: plot.owner,
            mailbox_msg_id: plot.mailbox_msg_id,
            instance: key,
            address:,
          )
        }
        option.None ->
          role.Host(
            id: plot.id,
            owner: plot.owner,
            mailbox_msg_id: plot.mailbox_msg_id,
          )
      }
    }
    Error(Nil) -> role.Unregistered(id: plot_id, owner: username)
  }
  |> Ok
}

// pub type Authentication {
//   NoAuth
//   UnregisteredPlot(id: Int, owner: String)
//   LocalPlot(id: Int, owner: uuid.Uuid, mailbox_msg_id: Int)
//   RemotePlot(
//     id: Int,
//     owner: uuid.Uuid,
//     instance: public_key.PublicKey,
//     mailbox_msg_id: Int,
//   )
//   LocalPlotApi(id: Int, owner: uuid.Uuid, mailbox_msg_id: Int, api_key: String)
//   RemotePlotApi(
//     id: Int,
//     owner: uuid.Uuid,
//     instance: public_key.PublicKey,
//     mailbox_msg_id: Int,
//     api_key: String,
//   )
// }

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
