import actor/cache
import actor/plot_mailbox
import actor/profiles
import app/address
import ed25519/private_key
import ed25519/public_key
import gleam/list
import gleam/result
import mist
import pog
import sql

pub type Context {
  Context(
    conn: pog.Connection,
    private_key: private_key.PrivateKey,
    profiles: profiles.Cache,
    df_ips: List(mist.IpAddress),
    mailbox_map: cache.Cache(Int, plot_mailbox.PlotMailbox),
    /// Keys issued by other instances to validate this instance
    identity_key_map: cache.Cache(public_key.PublicKey, BitArray),
    /// Keys issued by this instance to validate other instances
    ext_identity_key_map: cache.Cache(BitArray, public_key.PublicKey),
    instance: address.InstanceAddress,
    nginx: Bool,
    testing_mode: Bool,
  )
}

pub fn get_mailbox(ctx: Context, id: Int, msg_id: Int) {
  case
    ctx.mailbox_map
    |> cache.get(id)
  {
    Ok(it) -> it
    Error(Nil) -> {
      let box = plot_mailbox.new(msg_id)
      cache.set(ctx.mailbox_map, id, box)
      box
    }
  }
}

pub fn get_mailbox_lazy(
  ctx: Context,
  id: Int,
) -> Result(plot_mailbox.PlotMailbox, Nil) {
  case
    ctx.mailbox_map
    |> cache.get(id)
  {
    Ok(it) -> Ok(it)
    Error(Nil) -> {
      let assert Ok(plot) = sql.get_plot(ctx.conn, id)
      use plot <- result.try(list.first(plot.rows))
      let box = plot_mailbox.new(plot.id)
      cache.set(ctx.mailbox_map, id, box)
      Ok(box)
    }
  }
}
