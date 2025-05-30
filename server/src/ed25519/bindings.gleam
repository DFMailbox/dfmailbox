// Created by Sören Schwert licensed under Apache-2.0
// https://github.com/sisou/nimiq_gleam/commit/f56421d3edffe8ed1c77559719734e1edb52196f
// Bindings for https://hex.pm/packages/ed25519

/// Public or secret key
pub type Key =
  BitArray

/// Computed signature
pub type Signature =
  BitArray

/// Derive the public signing key from the secret key
@external(erlang, "Elixir.Ed25519", "derive_public_key")
pub fn derive_public_key(sk: Key) -> Key

/// Generate a secret/public key pair
///
/// Returned tuple contains `#(random_secret_key, derived_public_key)`
@external(erlang, "Elixir.Ed25519", "generate_key_pair")
pub fn generate_key_pair() -> #(Key, Key)

// /// Generate a secret/public key pair from supplied secret key
// ///
// /// Returned tuple contains `#(secret_key, derived_public_key)`
// @external(erlang, "Elixir.Ed25519.Ed25519", "generate_key_pair")
// pub fn generate_key_pair(secret: Key) -> #(Key, Key)

/// Returns whether a given `key` lies on the ed25519 curve.
@external(erlang, "Elixir.Ed25519", "on_curve")
pub fn on_curve(key: Key) -> Bool

/// Sign a message
@external(erlang, "Elixir.Ed25519", "signature")
pub fn signature(m: BitArray, sk: Key, pk: Key) -> Signature

/// Validate a signed message
@external(erlang, "Elixir.Ed25519", "valid_signature?")
pub fn valid_signature(sig: Signature, m: BitArray, pk: Key) -> Bool
