import app/ctx
import app/handle/h_plot
import app/handle/helper
import app/web
import gleam/http
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: ctx.Context) -> Response {
  use _req <- web.middleware(req)

  // NOTE: A guideline what to put here vs in a handler function:
  // If it can be expressed in an OpenAPI spec, put it here
  case wisp.path_segments(req) {
    ["v0", ..seg] ->
      case seg {
        ["path", ..] ->
          case req.method {
            http.Get -> {
              let query = wisp.get_query(req)
              h_plot.get_plot(query, ctx)
            }
            http.Post -> todo
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
        _ -> wisp.not_found()
      }
    _ -> wisp.not_found()
  }
}
