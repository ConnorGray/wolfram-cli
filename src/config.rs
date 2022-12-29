use std::sync::atomic::{self, AtomicU8};

static VERBOSITY: AtomicU8 = AtomicU8::new(0);

/// Get the verbosity value specified by the command-line invocation of this
/// program.
pub fn verbosity() -> u8 {
	VERBOSITY.load(atomic::Ordering::SeqCst)
}

pub fn set_verbosity(value: u8) {
	VERBOSITY.store(value, atomic::Ordering::SeqCst)
}
