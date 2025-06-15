//// This file is here to replce ./src/compile_time.gleam
//// This right now is the dev version

import gleam/http

/// The scheme to use for external instances
/// This is set to http so local network communication is possible
pub const scheme = http.Http
