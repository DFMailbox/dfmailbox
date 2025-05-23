import app/router
import dot_env
import dot_env/env
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  dot_env.load_default()

  let env = get_env()

  let assert Ok(_subj) =
    wisp_mist.handler(router.handle_request, env.secret_key)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(env.port)
    |> mist.start_http

  process.sleep_forever()
}

fn get_env() -> ProgramEnv {
  let assert Ok(jwt_key) = env.get_string("JWT_KEY")
  let assert Ok(secret_key) = env.get_string("SECRET_KEY")
  let assert Ok(redis_url) = env.get_string("REDIS_URL")
  let assert Ok(database_url) = env.get_string("DATABASE_URL")
  let assert Ok(port) = env.get_int("PORT")
  let assert Ok(domain) = env.get_string("HOST")

  ProgramEnv(secret_key, jwt_key, redis_url, database_url, port, domain)
}

pub type ProgramEnv {
  ProgramEnv(
    secret_key: String,
    jwt_key: String,
    redis_url: String,
    database_url: String,
    port: Int,
    host: String,
  )
}
