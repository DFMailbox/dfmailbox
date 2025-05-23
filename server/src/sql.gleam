import gleam/dynamic/decode
import gleam/option.{type Option}
import pog
import youid/uuid.{type Uuid}

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
    domain: Option(String),
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
    use domain <- decode.field(3, decode.optional(decode.string))
    decode.success(GetPlotRow(id:, owner:, public_key:, domain:))
  }

  "SELECT plot.id, owner, public_key, domain FROM plot
LEFT JOIN known_instance instance ON instance.id = plot.instance
WHERE plot.id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
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
