use crate::{Outcome, call, hstr, out_of_range};
use godot::prelude::*;
use hegel_c as c;
use std::ptr;

/// An owned libhegel settings handle, created from the default profile.
/// Check `last_result` after `new()`: a malformed `HEGEL_*` environment
/// variable fails the creation.
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct HegelNativeSettings {
    pub(crate) raw: *mut c::HegelSettings,
    #[var(no_set)]
    last_result: i64,
    #[var(no_set)]
    last_error: GString,
}

#[godot_api]
impl IRefCounted for HegelNativeSettings {
    fn init(_base: Base<RefCounted>) -> Self {
        let mut raw = ptr::null_mut();
        let (last_result, last_error) = call(|ctx| unsafe { c::hegel_settings_new(ctx, &mut raw) });
        Self {
            raw,
            last_result,
            last_error,
        }
    }
}

impl Drop for HegelNativeSettings {
    fn drop(&mut self) {
        // SAFETY: raw came from hegel_settings_new (or is NULL) and is freed once.
        call(|ctx| unsafe { c::hegel_settings_free(ctx, self.raw) });
    }
}

impl HegelNativeSettings {
    fn record(&mut self, (result, error): Outcome) -> i64 {
        self.last_result = result;
        self.last_error = error;
        result
    }
}

#[godot_api]
impl HegelNativeSettings {
    #[constant]
    const VERBOSITY_NORMAL: i64 = c::hegel_verbosity_t::HEGEL_VERBOSITY_NORMAL as i64;
    #[constant]
    const VERBOSITY_QUIET: i64 = c::hegel_verbosity_t::HEGEL_VERBOSITY_QUIET as i64;
    #[constant]
    const VERBOSITY_VERBOSE: i64 = c::hegel_verbosity_t::HEGEL_VERBOSITY_VERBOSE as i64;
    #[constant]
    const VERBOSITY_DEBUG: i64 = c::hegel_verbosity_t::HEGEL_VERBOSITY_DEBUG as i64;
    #[constant]
    const HC_FILTER_TOO_MUCH: i64 = c::hegel_health_check_t::HEGEL_HC_FILTER_TOO_MUCH as i64;
    #[constant]
    const HC_TOO_SLOW: i64 = c::hegel_health_check_t::HEGEL_HC_TOO_SLOW as i64;
    #[constant]
    const HC_TEST_CASES_TOO_LARGE: i64 =
        c::hegel_health_check_t::HEGEL_HC_TEST_CASES_TOO_LARGE as i64;
    #[constant]
    const HC_LARGE_INITIAL_TEST_CASE: i64 =
        c::hegel_health_check_t::HEGEL_HC_LARGE_INITIAL_TEST_CASE as i64;

    #[func]
    fn set_test_cases(&mut self, n: i64) -> i64 {
        let s = self.raw;
        self.record(match u64::try_from(n) {
            Ok(n) => call(|ctx| unsafe { c::hegel_settings_set_test_cases(ctx, s, n) }),
            Err(_) => out_of_range("test_cases", n),
        })
    }

    /// `seed` is bit-cast to u64. `has_seed = false` lets libhegel pick one.
    #[func]
    fn set_seed(&mut self, seed: i64, has_seed: bool) -> i64 {
        let s = self.raw;
        self.record(call(|ctx| unsafe {
            c::hegel_settings_set_seed(ctx, s, seed as u64, has_seed)
        }))
    }

    #[func]
    fn set_derandomize(&mut self, derandomize: bool) -> i64 {
        let s = self.raw;
        self.record(call(|ctx| unsafe {
            c::hegel_settings_set_derandomize(ctx, s, derandomize)
        }))
    }

    /// The database root directory, or "" to disable the database.
    #[func]
    fn set_database(&mut self, path: GString) -> i64 {
        let (s, path) = (self.raw, path.to_string());
        self.record(call(|ctx| unsafe {
            c::hegel_settings_set_database(ctx, s, &hstr(&path))
        }))
    }

    /// The database key, or "" to clear it.
    #[func]
    fn set_database_key(&mut self, key: GString) -> i64 {
        let (s, key) = (self.raw, key.to_string());
        let key_str = hstr(&key);
        let key_ptr = if key.is_empty() {
            ptr::null()
        } else {
            &key_str
        };
        self.record(call(|ctx| unsafe {
            c::hegel_settings_set_database_key(ctx, s, key_ptr)
        }))
    }

    #[func]
    fn set_verbosity(&mut self, verbosity: i64) -> i64 {
        let s = self.raw;
        self.record(match u32::try_from(verbosity) {
            Ok(v) => call(|ctx| unsafe { c::hegel_settings_set_verbosity(ctx, s, v) }),
            Err(_) => out_of_range("verbosity", verbosity),
        })
    }

    /// A bitwise OR of the `HC_*` constants.
    #[func]
    fn set_suppress_health_check(&mut self, checks: i64) -> i64 {
        let s = self.raw;
        self.record(match u32::try_from(checks) {
            Ok(v) => call(|ctx| unsafe { c::hegel_settings_set_suppress_health_check(ctx, s, v) }),
            Err(_) => out_of_range("checks", checks),
        })
    }
}
