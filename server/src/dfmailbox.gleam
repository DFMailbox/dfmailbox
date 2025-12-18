import actor/cache
import actor/profiles
import app/address
import app/ctx
import app/router
import dot_env
import dot_env/env
import ed25519/private_key
import ewe
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import gleam/result
import logging
import pog

pub fn main() -> Nil {
  logging.configure()
  logging.set_level(logging.Info)
  dot_env.load_default()

  let env = get_env()
  let pool_name = process.new_name("database_pool")
  let assert Ok(_start) =
    start_application_supervisor(env.database_url, pool_name)
    |> result.replace_error("Cannot parse database url")

  let assert Ok(private_key) = private_key.from_base64(env.secret_key)
  let assert Ok(profile_cache) = profiles.new()

  let context =
    ctx.Context(
      conn: pog.named_connection(pool_name),
      private_key:,
      profiles: profile_cache.data,
      identity_key_map: cache.new().data,
      ext_identity_key_map: cache.new().data,
      mailbox_map: cache.new().data,
      nginx: env.is_nginx,
      instance: env.host,
      testing_mode: env.testing_mode,
    )

  let assert Ok(_subj) =
    ewe.new(router.handle_ewe(_, context))
    |> ewe.bind_all()
    |> ewe.listening(port: 8080)
    |> ewe.start()

  process.sleep_forever()
  // router.handle_mist(_, env.secret_key, context)
  // |> mist.new
  // |> mist.bind("0.0.0.0")
  // |> mist.port(env.port)
  // |> mist.start
}

pub fn start_application_supervisor(
  url: String,
  pool_name: process.Name(pog.Message),
) {
  use config <- result.try(pog.url_config(pool_name, url))

  let pool_child =
    config
    |> pog.host("localhost")
    |> pog.database("my_database")
    |> pog.pool_size(15)
    |> pog.supervised

  supervisor.new(supervisor.RestForOne)
  |> supervisor.add(pool_child)
  |> supervisor.start
  |> Ok
}

fn get_env() -> ProgramEnv {
  let assert Ok(secret_key) = env.get_string("SECRET_KEY")
  let assert Ok(database_url) = env.get_string("DATABASE_URL")
  let assert Ok(port) = env.get_int("PORT")
  let testing_mode = env.get_bool_or("TESTING_MODE", False)
  let assert Ok(host) =
    env.get_then("HOST", fn(host) {
      address.parse(host) |> result.replace_error("Host is invalid")
    })
  let nginx = env.get_bool_or("IS_NGINX", False)

  ProgramEnv(secret_key, database_url, host, port, testing_mode, nginx)
}

pub type ProgramEnv {
  ProgramEnv(
    secret_key: String,
    database_url: String,
    host: address.InstanceAddress,
    port: Int,
    testing_mode: Bool,
    is_nginx: Bool,
  )
}
