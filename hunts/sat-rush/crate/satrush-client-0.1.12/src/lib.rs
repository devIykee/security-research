// Codama-generated code is excluded from linting: rustfmt is skipped and all
// clippy/rustc warnings are allowed, so regenerating the client can never break
// `pnpm lint` even if Codama emits a newly-lintable construct.
#[rustfmt::skip]
#[allow(clippy::all, warnings)]
mod generated;
mod alt;
mod builders;
#[cfg(feature = "fetch")]
pub mod gpa;
mod hashrate;
mod pda;
mod sats;
mod selection;
mod streak;
pub mod test_utils;

pub use alt::*;
pub use builders::*;
pub use hashrate::*;
pub use pda::*;
pub use sats::*;
pub use selection::*;
pub use streak::*;

pub use generated::accounts;
pub use generated::errors::*;
pub use generated::instructions;
pub use generated::programs::*;
pub use generated::types;

#[cfg(feature = "fetch")]
pub use generated::shared::*;

#[cfg(feature = "fetch")]
pub(crate) use generated::*;
