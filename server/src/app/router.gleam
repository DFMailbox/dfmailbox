import app/ctx
import app/handle/h_plot
import app/handle/h_server
import app/web
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/string
import gleam/string_tree
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn handle_mist(
  req: request.Request(mist.Connection),
  secret: String,
  ctx: ctx.Context,
) -> response.Response(mist.ResponseData) {
  wisp_mist.handler(handle_request(_, req, ctx), secret)(req)
}

pub fn handle_request(
  req: Request,
  mist: request.Request(mist.Connection),
  ctx: ctx.Context,
) -> Response {
  use req <- web.middleware(req)
  use auth <- web.auth_midleware(req, mist, ctx)
  echo { "auth: " <> auth |> string.inspect }

  // NOTE: an h_ function cannot take a request
  case wisp.path_segments(req) {
    ["v0", ..seg] ->
      case seg {
        ["plot", ..] ->
          case req.method {
            http.Get -> {
              let query = wisp.get_query(req)
              h_plot.get_plot(query, ctx)
            }
            http.Post -> {
              use json <- wisp.require_json(req)
              h_plot.register_plot(json, auth, ctx)
            }
            http.Put -> todo
            http.Delete -> todo
            _ ->
              wisp.method_not_allowed([
                http.Get,
                http.Post,
                http.Put,
                http.Delete,
              ])
          }
        ["info", ..] -> {
          use <- wisp.require_method(req, http.Get)
          let query = wisp.get_query(req)
          h_server.sign(query, ctx)
        }
        _ -> wisp.not_found()
      }
    _ -> {
      wisp.html_response("dfqueue" |> string_tree.from_string, 200)
    }
  }
}
