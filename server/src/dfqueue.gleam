import app/ctx
import app/router
import dot_env
import dot_env/env
import ed25519/private_key
import gleam/erlang/process
import gleam/result
import mist
import pog
import wisp
import wisp/wisp_mist

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

  let context = ctx.Context(conn:, private_key:)

  let assert Ok(_subj) =
    wisp_mist.handler(router.handle_request(_, context), env.secret_key)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(env.port)
    |> mist.start_http

  process.sleep_forever()
}

fn get_env() -> ProgramEnv {
  let assert Ok(secret_key) = env.get_string("SECRET_KEY")
  let assert Ok(redis_url) = env.get_string("REDIS_URL")
  let assert Ok(database_url) = env.get_string("DATABASE_URL")
  let assert Ok(port) = env.get_int("PORT")
  let assert Ok(host) = env.get_string("HOST")

  ProgramEnv(secret_key, redis_url, database_url, port, host)
}

pub type ProgramEnv {
  ProgramEnv(
    secret_key: String,
    redis_url: String,
    database_url: String,
    port: Int,
    host: String,
  )
}
