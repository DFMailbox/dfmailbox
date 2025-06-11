import gleam/dynamic/decode
import gleam/option.{type Option}
import pog
import youid/uuid.{type Uuid}

/// Runs the `set_mailbox_msg_id` query
/// defined in `./src/sql/set_mailbox_msg_id.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn set_mailbox_msg_id(db, arg_1, arg_2) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE plot 
SET mailbox_msg_id = $2
WHERE id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_trust` query
/// defined in `./src/sql/list_trust.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.4 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListTrustRow {
  ListTrustRow(trusted: Int)
}

/// Runs the `list_trust` query
/// defined in `./src/sql/list_trust.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_trust(db, arg_1) {
  let decoder = {
    use trusted <- decode.field(0, decode.int)
    decode.success(ListTrustRow(trusted:))
  }

  "SELECT trusted FROM trust
WHERE plot = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `check_trust` query
/// defined in `./src/sql/check_trust.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.4 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CheckTrustRow {
  CheckTrustRow(id: Int)
}

/// Runs the `check_trust` query
/// defined in `./src/sql/check_trust.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn check_trust(db, arg_1, arg_2) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(CheckTrustRow(id:))
  }

  "SELECT id FROM trust
WHERE plot = $1 AND trusted = $2;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_trust` query
/// defined in `./src/sql/delete_trust.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_trust(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM trust
WHERE plot = $1 OR trusted = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `register_plot_int` query
/// defined in `./src/sql/register_plot_int.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn register_plot_int(db, arg_1, arg_2) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO plot (id, owner, mailbox_msg_id)
VALUES ($1, $2, 0)
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_instance` query
/// defined in `./src/sql/get_instance.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.4 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetInstanceRow {
  GetInstanceRow(address: Option(String))
}

/// Runs the `get_instance` query
/// defined in `./src/sql/get_instance.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_instance(db, arg_1) {
  let decoder = {
    use address <- decode.field(0, decode.optional(decode.string))
    decode.success(GetInstanceRow(address:))
  }

  "SELECT address FROM known_instance
WHERE public_key = $1;

"
  |> pog.query
  |> pog.parameter(pog.bytea(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_api_keys` query
/// defined in `./src/sql/get_api_keys.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.4 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetApiKeysRow {
  GetApiKeysRow(
    id: Int,
    plot: Int,
    hashed_key: BitArray,
    created_at: pog.Timestamp,
  )
}

/// Runs the `get_api_keys` query
/// defined in `./src/sql/get_api_keys.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_api_keys(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use plot <- decode.field(1, decode.int)
    use hashed_key <- decode.field(2, decode.bit_array)
    use created_at <- decode.field(3, pog.timestamp_decoder())
    decode.success(GetApiKeysRow(id:, plot:, hashed_key:, created_at:))
  }

  "SELECT id, plot, hashed_key, created_at FROM api_key
WHERE plot = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `add_api_key` query
/// defined in `./src/sql/add_api_key.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn add_api_key(db, arg_1, arg_2) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO api_key (plot, hashed_key) 
VALUES ($1, sha256($2))
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.bytea(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_plot` query
/// defined in `./src/sql/get_plot.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.4 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetPlotRow {
  GetPlotRow(
    id: Int,
    owner: Uuid,
    public_key: Option(BitArray),
    address: Option(String),
    mailbox_msg_id: Int,
  )
}

/// Runs the `get_plot` query
/// defined in `./src/sql/get_plot.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_plot(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use owner <- decode.field(1, uuid_decoder())
    use public_key <- decode.field(2, decode.optional(decode.bit_array))
    use address <- decode.field(3, decode.optional(decode.string))
    use mailbox_msg_id <- decode.field(4, decode.int)
    decode.success(
      GetPlotRow(id:, owner:, public_key:, address:, mailbox_msg_id:),
    )
  }

  "SELECT plot.id, owner, public_key, address, mailbox_msg_id FROM plot
LEFT JOIN known_instance instance ON instance.public_key = plot.instance
WHERE plot.id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `identify_instance` query
/// defined in `./src/sql/identify_instance.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn identify_instance(db, arg_1, arg_2) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO known_instance (public_key, address)
VALUES ($1, $2)
"
  |> pog.query
  |> pog.parameter(pog.bytea(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `trust_plot` query
/// defined in `./src/sql/trust_plot.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn trust_plot(db, arg_1, arg_2) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO trust (plot, trusted)
SELECT $1, unnest($2::int[])
ON CONFLICT (plot, trusted) DO NOTHING;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.array(fn(value) { pog.int(value) }, arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `purge_api_keys` query
/// defined in `./src/sql/purge_api_keys.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn purge_api_keys(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM api_key
WHERE plot = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_address` query
/// defined in `./src/sql/get_address.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.4 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetAddressRow {
  GetAddressRow(address: Option(String))
}

/// Runs the `get_address` query
/// defined in `./src/sql/get_address.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_address(db, arg_1) {
  let decoder = {
    use address <- decode.field(0, decode.optional(decode.string))
    decode.success(GetAddressRow(address:))
  }

  "SELECT address FROM known_instance
WHERE public_key = $1
"
  |> pog.query
  |> pog.parameter(pog.bytea(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `plot_from_api_key` query
/// defined in `./src/sql/plot_from_api_key.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.4 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PlotFromApiKeyRow {
  PlotFromApiKeyRow(
    id: Int,
    owner: Uuid,
    public_key: Option(BitArray),
    address: Option(String),
    mailbox_msg_id: Int,
  )
}

/// Runs the `plot_from_api_key` query
/// defined in `./src/sql/plot_from_api_key.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn plot_from_api_key(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use owner <- decode.field(1, uuid_decoder())
    use public_key <- decode.field(2, decode.optional(decode.bit_array))
    use address <- decode.field(3, decode.optional(decode.string))
    use mailbox_msg_id <- decode.field(4, decode.int)
    decode.success(
      PlotFromApiKeyRow(id:, owner:, public_key:, address:, mailbox_msg_id:),
    )
  }

  "SELECT plot.id, owner, public_key, address, mailbox_msg_id FROM api_key
JOIN plot ON plot.id = api_key.plot
LEFT JOIN known_instance instance ON instance.public_key = plot.instance
WHERE hashed_key = sha256($1);
"
  |> pog.query
  |> pog.parameter(pog.bytea(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `remove_trust` query
/// defined in `./src/sql/remove_trust.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn remove_trust(db, arg_1, arg_2) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM trust
WHERE plot = $1 AND trusted = ANY($2::INTEGER[]);
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.array(fn(value) { pog.int(value) }, arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `update_plot_instance_int` query
/// defined in `./src/sql/update_plot_instance_int.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_plot_instance_int(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE plot
SET instance = NULL
WHERE id = $1
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_plot` query
/// defined in `./src/sql/delete_plot.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_plot(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM plot
WHERE id = $1;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `update_plot_instance_ext` query
/// defined in `./src/sql/update_plot_instance_ext.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_plot_instance_ext(db, arg_1, arg_2) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE plot
SET instance = $1
WHERE id = $2
"
  |> pog.query
  |> pog.parameter(pog.bytea(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `register_plot_ext` query
/// defined in `./src/sql/register_plot_ext.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.4 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn register_plot_ext(db, arg_1, arg_2, arg_3) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO plot (id, owner, instance, mailbox_msg_id)
VALUES ($1, $2, $3, 0)
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.bytea(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Encoding/decoding utils -------------------------------------------------

/// A decoder to decode `Uuid`s coming from a Postgres query.
///
fn uuid_decoder() {
  use bit_array <- decode.then(decode.bit_array)
  case uuid.from_bit_array(bit_array) {
    Ok(uuid) -> decode.success(uuid)
    Error(_) -> decode.failure(uuid.v7(), "Uuid")
  }
}
