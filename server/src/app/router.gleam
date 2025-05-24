import app/ctx
import app/handle/h_plot
import app/handle/h_server
import app/web
import gleam/http
import gleam/string_tree
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: ctx.Context) -> Response {
  use _req <- web.middleware(req)

  // NOTE: an h_ function cannot take a request
  case wisp.path_segments(req) {
    ["v0", ..seg] ->
      case seg {
        ["path", ..] ->
          case req.method {
            http.Get -> {
              let query = wisp.get_query(req)
              h_plot.get_plot(query, ctx)
            }
            http.Post -> {
              todo
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
