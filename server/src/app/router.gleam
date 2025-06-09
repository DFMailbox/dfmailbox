import app/ctx
import app/handle/h_api_key
import app/handle/h_instance
import app/handle/h_mailbox
import app/handle/h_plot
import app/handle/h_query
import app/handle/h_server
import app/handle/h_trust
import app/handle/helper
import app/web
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/result
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

  // NOTE: an h_ function cannot take a request
  case wisp.path_segments(req) {
    ["v0", ..seg] ->
      case seg {
        ["plot", ..seg] -> {
          use auth <- web.auth_midleware(req, mist, ctx)
          case seg {
            [] -> {
              case req.method {
                http.Get -> {
                  h_plot.get_plot(auth, ctx)
                }
                http.Post -> {
                  use json <- wisp.require_json(req)
                  h_plot.register_plot(json, auth, ctx)
                }
                http.Put -> {
                  use json <- wisp.require_json(req)
                  h_plot.update_plot(json, auth, ctx)
                }
                http.Delete -> {
                  todo
                }
                _ -> wisp.method_not_allowed([http.Put, http.Post, http.Delete])
              }
            }
            ["whoami"] -> {
              use <- wisp.require_method(req, http.Get)
              use a <- helper.try_res(
                web.match_authenticated(auth)
                |> result.replace_error(helper.construct_error(
                  "Must have some auth",
                  401,
                )),
              )
              json.object([#("plot_id", json.int(a))])
              |> json.to_string_tree()
              |> wisp.json_response(200)
            }
            ["mailbox"] ->
              case req.method {
                http.Get -> {
                  let query = wisp.get_query(req)
                  h_mailbox.peek(query, auth, ctx)
                }
                http.Post -> {
                  use json <- wisp.require_json(req)
                  h_mailbox.enqueue(json, auth, ctx)
                }
                http.Delete -> {
                  let query = wisp.get_query(req)
                  h_mailbox.cleanup(query, auth, ctx)
                }
                _ -> wisp.method_not_allowed([http.Get, http.Post, http.Delete])
              }
            ["query"] -> {
              use <- wisp.require_method(req, http.Post)
              use json <- wisp.require_json(req)
              h_query.run_query(json, auth, ctx)
            }
            ["api-key"] ->
              case req.method {
                http.Get -> {
                  h_api_key.get_all(auth, ctx)
                }
                http.Post -> {
                  h_api_key.add(auth, ctx)
                }
                http.Delete -> {
                  h_api_key.purge_keys(auth, ctx)
                }
                _ -> wisp.method_not_allowed([http.Get, http.Post, http.Delete])
              }
            ["trust"] ->
              case req.method {
                http.Get -> {
                  h_trust.get_trusted(auth, ctx)
                }
                http.Post -> {
                  use json <- wisp.require_json(req)
                  h_trust.trust_plot(json, auth, ctx)
                }
                http.Delete -> {
                  use json <- wisp.require_json(req)
                  h_trust.untrust_plot(json, auth, ctx)
                }
                _ -> wisp.method_not_allowed([http.Get, http.Post, http.Delete])
              }
            _ -> wisp.not_found()
          }
        }
        ["plots", ..seg] -> {
          use #(plot_id, seg) <- helper.try_res(case seg {
            [plot_id, ..seg] -> {
              use plot_id <- result.try(
                int.parse(plot_id)
                |> result.replace_error(helper.construct_error(
                  "plot_id is not an int",
                  400,
                )),
              )

              Ok(#(plot_id, seg))
            }
            [] -> Error(helper.construct_error("No plot_id in path", 404))
          })
          use auth <- web.auth_midleware(req, mist, ctx)

          case seg {
            [] -> {
              use <- wisp.require_method(req, http.Get)
              h_plot.get_other_plot(plot_id, ctx)
            }
            ["mailbox"] -> {
              use <- wisp.require_method(req, http.Post)
              use json <- wisp.require_json(req)
              h_mailbox.enqueue_other(plot_id, json, auth, ctx)
            }
            _ -> wisp.not_found()
          }
        }
        ["instance"] ->
          case req.method {
            http.Get -> {
              todo
              // let query = wisp.get_query(req)
              // h_instance.get_instance(query)
            }
            http.Post -> {
              use json <- wisp.require_json(req)
              h_instance.introduce(json, ctx)
            }
            http.Delete -> {
              todo
              // h_instance.mark_key_as_compromised
            }
            _ -> wisp.method_not_allowed([http.Get, http.Post, http.Delete])
          }
        ["federation", ..segs] ->
          case segs {
            ["instance"] ->
              case req.method {
                http.Get -> {
                  let query = wisp.get_query(req)
                  h_server.sign(query, ctx)
                }
                http.Post -> {
                  use json <- wisp.require_json(req)
                  h_server.identity_key(json, ctx)
                }
                http.Delete -> {
                  todo
                }
                _ -> wisp.method_not_allowed([http.Get, http.Post, http.Delete])
              }
            ["mailbox"] ->
              case req.method {
                http.Post -> todo as "post mailbox"
                _ -> wisp.method_not_allowed([http.Get, http.Post, http.Delete])
              }
            _ -> wisp.not_found()
          }
        _ -> wisp.not_found()
      }
    ["robots.txt"] -> {
      wisp.response(200)
      |> wisp.set_body(
        "User-agent: *\nDisallow: /" |> string_tree.from_string |> wisp.Text,
      )
    }
    [] -> {
      wisp.html_response("dfmailbox" |> string_tree.from_string, 200)
    }
    _ -> wisp.not_found()
  }
}
