import app/ctx
import ewe
import gleam/http/request

pub fn handle_ewe(
  req: request.Request(ewe.Connection),
  ctx: ctx.Context,
) -> ewe.Response {
  // request.path_segments()
  todo
}
