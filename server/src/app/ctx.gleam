import actor/cache
import actor/plot_mailbox
import actor/profiles
import ed25519/private_key
import mist
import pog

pub type Context {
  Context(
    conn: pog.Connection,
    private_key: private_key.PrivateKey,
    profiles: profiles.Cache,
    df_ips: List(mist.IpAddress),
    mailbox_map: cache.Cache(Int, plot_mailbox.PlotMailbox),
  )
}
