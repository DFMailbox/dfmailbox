import ed25519/private_key
import pog

pub type Context {
  Context(conn: pog.Connection, private_key: private_key.PrivateKey)
}
