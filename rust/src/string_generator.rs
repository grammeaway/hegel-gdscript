use crate::{Outcome, call, out_of_range};
use godot::prelude::*;
use hegel_c as c;
use std::ptr;

/// An engine string generator, built once and drawn from through
/// `HegelNativeTestCase.generate_string`.
#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct HegelNativeStringGenerator {
    pub(crate) raw: *mut c::HegelStringGenerator,
    #[var(no_set)]
    last_result: i64,
    #[var(no_set)]
    last_error: GString,
}

impl Drop for HegelNativeStringGenerator {
    fn drop(&mut self) {
        // SAFETY: raw came from hegel_string_generator_text (or is NULL) and
        // is freed once.
        call(|ctx| unsafe { c::hegel_string_generator_free(ctx, self.raw) });
    }
}

impl HegelNativeStringGenerator {
    fn record(&mut self, (result, error): Outcome) -> i64 {
        self.last_result = result;
        self.last_error = error;
        result
    }
}

#[godot_api]
impl HegelNativeStringGenerator {
    /// Builds a Unicode text generator, freeing any generator this object
    /// held before. Sizes are in characters; codepoints bound the alphabet,
    /// with no category or character filters.
    #[func]
    fn text(
        &mut self,
        min_size: i64,
        max_size: i64,
        min_codepoint: i64,
        max_codepoint: i64,
    ) -> i64 {
        call(|ctx| unsafe { c::hegel_string_generator_free(ctx, self.raw) });
        self.raw = ptr::null_mut();
        let Ok(min) = u64::try_from(min_size) else {
            return self.record(out_of_range("min_size", min_size));
        };
        let Ok(max) = u64::try_from(max_size) else {
            return self.record(out_of_range("max_size", max_size));
        };
        let Ok(min_cp) = u32::try_from(min_codepoint) else {
            return self.record(out_of_range("min_codepoint", min_codepoint));
        };
        let Ok(max_cp) = u32::try_from(max_codepoint) else {
            return self.record(out_of_range("max_codepoint", max_codepoint));
        };
        let mut raw = ptr::null_mut();
        let outcome = call(|ctx| unsafe {
            c::hegel_string_generator_text(
                ctx,
                min,
                max,
                ptr::null(),
                min_cp,
                max_cp,
                ptr::null(),
                0,
                ptr::null(),
                0,
                c::hegel_string_t::default(),
                c::hegel_string_t::default(),
                &mut raw,
            )
        });
        self.raw = raw;
        self.record(outcome)
    }
}
