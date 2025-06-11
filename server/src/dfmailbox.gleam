import actor/cache
import actor/profiles
import app/address
import app/ctx
import app/router
import dot_env
import dot_env/env
import ed25519/private_key
import gleam/bool
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import mist
import pog
import wisp

pub fn main() -> Nil {
  wisp.configure_logger()
  dot_env.load_default()

  let env = get_env()
  let assert Ok(config) =
    pog.url_config(env.database_url)
    |> result.replace_error("Cannot parse database url")

  let conn =
    config
    |> pog.connect

  let assert Ok(private_key) = private_key.from_base64(env.secret_key)
  let assert Ok(profile_cache) = profiles.new()

  let context =
    ctx.Context(
      conn:,
      private_key:,
      profiles: profile_cache,
      df_ips: env.allowed_ips,
      identity_key_map: cache.new(),
      ext_identity_key_map: cache.new(),
      mailbox_map: cache.new(),
      nginx: env.is_nginx,
      instance: env.host,
    )

  let assert Ok(_subj) =
    router.handle_mist(_, env.secret_key, context)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(env.port)
    |> mist.start_http

  process.sleep_forever()
}

fn get_env() -> ProgramEnv {
  let assert Ok(secret_key) = env.get_string("SECRET_KEY")
  let assert Ok(database_url) = env.get_string("DATABASE_URL")
  let assert Ok(port) = env.get_int("PORT")
  let assert Ok(host) =
    env.get_then("HOST", fn(host) {
      address.parse(host) |> result.replace_error("Host is invalid")
    })
  let assert Ok(extra_ips) = case env.get_string("ALLOWED_IPS") {
    Ok(env) -> {
      use <- bool.guard(string.is_empty(env), Ok([]))
      let items = string.split(env, " ")
      let it =
        list.map(items, fn(x) {
          case string.split(x, ".") {
            [a, b, c, d] -> {
              use a <- result.try(int.parse(a))
              use b <- result.try(int.parse(b))
              use c <- result.try(int.parse(c))
              use d <- result.try(int.parse(d))
              Ok(mist.IpV4(a, b, c, d))
            }
            _ -> Error(Nil)
          }
        })
      use <- bool.guard(
        list.find(it, result.is_error) |> result.is_ok(),
        Error("Cannot parse IPs Invalid ip example: 129.168.1.42"),
      )
      it
      |> list.map(
        result.lazy_unwrap(_, fn() { panic as "ip should be guarded" }),
      )
      |> Ok
    }
    Error(_) -> Ok([])
  }
  let nginx = env.get_bool_or("IS_NGINX", False)

  let df_ips = [mist.IpV4(51, 222, 245, 229), ..extra_ips]

  ProgramEnv(secret_key, database_url, host, port, df_ips, nginx)
}

pub type ProgramEnv {
  ProgramEnv(
    secret_key: String,
    database_url: String,
    host: address.InstanceAddress,
    port: Int,
    allowed_ips: List(mist.IpAddress),
    is_nginx: Bool,
  )
}
