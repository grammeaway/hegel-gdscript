use crate::settings::HegelNativeSettings;
use crate::test_case::HegelNativeTestCase;
use crate::{Outcome, call, opt_string_from, out_of_range, string_from};
use godot::prelude::*;
use hegel_c as c;
use hegel_c::hegel_result_t as Rc;
use std::ffi::{c_char, c_void};
use std::ptr;
use std::sync::{Arc, Mutex};

/// Engine output lines, buffered until GDScript drains them.
#[derive(Default)]
struct OutputBuffer(Mutex<Vec<String>>);

unsafe extern "C" fn output_trampoline(user_data: *mut c_void, line: *const c_char, len: usize) {
    if user_data.is_null() || line.is_null() {
        return;
    }
    // SAFETY: user_data is the run's Arc<OutputBuffer>, which outlives the
    // run; line is valid for len bytes for the duration of the call.
    let buffer = unsafe { &*(user_data as *const OutputBuffer) };
    let bytes = unsafe { std::slice::from_raw_parts(line as *const u8, len) };
    let line = String::from_utf8_lossy(bytes).into_owned();
    buffer
        .0
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .push(line);
}

/// One property-test run: the engine's generate and shrink loop, driven
/// through `next_test_case`.
#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct HegelNativeRun {
    raw: *mut c::HegelRun,
    output: Arc<OutputBuffer>,
    #[var(no_set)]
    last_result: i64,
    #[var(no_set)]
    last_error: GString,
}

impl Drop for HegelNativeRun {
    fn drop(&mut self) {
        // SAFETY: raw came from hegel_run_start (or is NULL) and is freed once.
        call(|ctx| unsafe { c::hegel_run_free(ctx, self.raw) });
    }
}

impl HegelNativeRun {
    fn record(&mut self, (result, error): Outcome) -> i64 {
        self.last_result = result;
        self.last_error = error;
        result
    }
}

#[godot_api]
impl HegelNativeRun {
    /// Starts the run, freeing any run this object held before.
    #[func]
    fn start(&mut self, settings: Gd<HegelNativeSettings>) -> i64 {
        call(|ctx| unsafe { c::hegel_run_free(ctx, self.raw) });
        self.raw = ptr::null_mut();
        let s = settings.bind().raw;
        let user_data = Arc::as_ptr(&self.output) as *mut c_void;
        let mut raw = ptr::null_mut();
        let outcome = call(|ctx| unsafe {
            c::hegel_run_start(ctx, s, Some(output_trampoline), user_data, &mut raw)
        });
        self.raw = raw;
        self.record(outcome)
    }

    /// The next test case, or null once the run is finished (or on failure).
    #[func]
    fn next_test_case(&mut self) -> Option<Gd<HegelNativeTestCase>> {
        let run = self.raw;
        let mut raw = ptr::null_mut();
        self.record(call(|ctx| unsafe {
            c::hegel_next_test_case(ctx, run, &mut raw)
        }));
        (!raw.is_null()).then(|| HegelNativeTestCase::wrap(raw))
    }

    /// The finished run's result, or null on failure.
    #[func]
    fn result(&mut self) -> Option<Gd<HegelNativeRunResult>> {
        let run = self.raw;
        let mut raw = ptr::null_mut();
        self.record(call(|ctx| unsafe {
            c::hegel_run_result(ctx, run, &mut raw)
        }));
        (!raw.is_null()).then(|| Gd::from_object(HegelNativeRunResult::wrap(raw)))
    }

    /// Engine output lines emitted since the last drain.
    #[func]
    fn drain_output(&self) -> PackedStringArray {
        let mut lines = self.output.0.lock().unwrap_or_else(|e| e.into_inner());
        std::mem::take(&mut *lines)
            .iter()
            .map(GString::from)
            .collect()
    }
}

/// The outcome of a finished run. Failures are read by index.
#[derive(GodotClass)]
#[class(no_init, base=RefCounted)]
pub struct HegelNativeRunResult {
    raw: *mut c::HegelRunResult,
    #[var(no_set)]
    last_result: i64,
    #[var(no_set)]
    last_error: GString,
}

impl Drop for HegelNativeRunResult {
    fn drop(&mut self) {
        // SAFETY: raw came from hegel_run_result and is freed once.
        call(|ctx| unsafe { c::hegel_run_result_free(ctx, self.raw) });
    }
}

impl HegelNativeRunResult {
    fn wrap(raw: *mut c::HegelRunResult) -> Self {
        Self {
            raw,
            last_result: 0,
            last_error: GString::new(),
        }
    }

    fn record(&mut self, (result, error): Outcome) -> i64 {
        self.last_result = result;
        self.last_error = error;
        result
    }

    /// Reads one field off the failure at `index`, through a copy of the
    /// failure that is freed afterwards.
    fn read_failure(
        &mut self,
        index: i64,
        read: impl FnOnce(*mut c::HegelContext, *const c::HegelFailure) -> (Rc, String),
    ) -> GString {
        let Ok(index) = usize::try_from(index) else {
            self.record(out_of_range("index", index));
            return GString::new();
        };
        let r = self.raw;
        let mut failure = ptr::null_mut();
        let mut text = String::new();
        let mut outcome =
            call(|ctx| unsafe { c::hegel_run_result_failure(ctx, r, index, &mut failure) });
        if outcome.0 == Rc::HEGEL_OK as i64 {
            outcome = call(|ctx| {
                let (rc, value) = read(ctx, failure);
                text = value;
                rc
            });
        }
        // SAFETY: failure is NULL or a copy owned here, freed once.
        call(|ctx| unsafe { c::hegel_failure_free(ctx, failure) });
        self.record(outcome);
        GString::from(&text)
    }
}

#[godot_api]
impl HegelNativeRunResult {
    #[constant]
    const RUN_STATUS_PASSED: i64 = c::hegel_run_status_t::HEGEL_RUN_STATUS_PASSED as i64;
    #[constant]
    const RUN_STATUS_FAILED: i64 = c::hegel_run_status_t::HEGEL_RUN_STATUS_FAILED as i64;
    #[constant]
    const RUN_STATUS_ERROR: i64 = c::hegel_run_status_t::HEGEL_RUN_STATUS_ERROR as i64;
    #[constant]
    const RUN_ERROR_NONE: i64 = c::hegel_run_error_kind_t::HEGEL_RUN_ERROR_NONE as i64;
    #[constant]
    const RUN_ERROR_HEALTH_CHECK: i64 =
        c::hegel_run_error_kind_t::HEGEL_RUN_ERROR_HEALTH_CHECK as i64;
    #[constant]
    const RUN_ERROR_FLAKY: i64 = c::hegel_run_error_kind_t::HEGEL_RUN_ERROR_FLAKY as i64;
    #[constant]
    const RUN_ERROR_NONDETERMINISTIC: i64 =
        c::hegel_run_error_kind_t::HEGEL_RUN_ERROR_NONDETERMINISTIC as i64;
    #[constant]
    const RUN_ERROR_UNSATISFIABLE: i64 =
        c::hegel_run_error_kind_t::HEGEL_RUN_ERROR_UNSATISFIABLE as i64;
    #[constant]
    const RUN_ERROR_USAGE: i64 = c::hegel_run_error_kind_t::HEGEL_RUN_ERROR_USAGE as i64;
    #[constant]
    const RUN_ERROR_INTERNAL: i64 = c::hegel_run_error_kind_t::HEGEL_RUN_ERROR_INTERNAL as i64;

    /// One of the `RUN_STATUS_*` constants.
    #[func]
    fn status(&mut self) -> i64 {
        let r = self.raw;
        let mut out = c::hegel_run_status_t::HEGEL_RUN_STATUS_ERROR;
        self.record(call(|ctx| unsafe {
            c::hegel_run_result_status(ctx, r, &mut out)
        }));
        out as i64
    }

    /// One of the `RUN_ERROR_*` constants.
    #[func]
    fn error_kind(&mut self) -> i64 {
        let r = self.raw;
        let mut out = c::hegel_run_error_kind_t::HEGEL_RUN_ERROR_NONE;
        self.record(call(|ctx| unsafe {
            c::hegel_run_result_error_kind(ctx, r, &mut out, ptr::null_mut())
        }));
        out as i64
    }

    /// The `HC_*` value of the failed health check, or 0.
    #[func]
    fn health_check(&mut self) -> i64 {
        let r = self.raw;
        let mut out = 0u32;
        self.record(call(|ctx| unsafe {
            c::hegel_run_result_error_kind(ctx, r, ptr::null_mut(), &mut out)
        }));
        i64::from(out)
    }

    /// The run-level error message, or "" when the run didn't error.
    #[func]
    fn error(&mut self) -> GString {
        let r = self.raw;
        let mut out = ptr::null();
        self.record(call(|ctx| unsafe {
            c::hegel_run_result_error(ctx, r, &mut out)
        }));
        GString::from(&opt_string_from(out))
    }

    #[func]
    fn failure_count(&mut self) -> i64 {
        let r = self.raw;
        let mut out = 0usize;
        self.record(call(|ctx| unsafe {
            c::hegel_run_result_failure_count(ctx, r, &mut out)
        }));
        out as i64
    }

    /// The origin the failure at `index` was grouped under.
    #[func]
    fn failure_origin(&mut self, index: i64) -> GString {
        self.read_failure(index, |ctx, f| {
            let mut out = c::hegel_string_t::default();
            let rc = unsafe { c::hegel_failure_origin(ctx, f, &mut out) };
            (rc, string_from(out))
        })
    }

    /// The failure's reproduce blob, or "" when there is none.
    #[func]
    fn failure_blob(&mut self, index: i64) -> GString {
        self.read_failure(index, |ctx, f| {
            let mut out = ptr::null();
            let rc = unsafe { c::hegel_failure_reproduction_blob(ctx, f, &mut out) };
            (rc, opt_string_from(out))
        })
    }

    /// The failure's confirmation caveat, or "" for a deterministic failure.
    #[func]
    fn failure_caveat(&mut self, index: i64) -> GString {
        self.read_failure(index, |ctx, f| {
            let mut out = ptr::null();
            let rc = unsafe { c::hegel_failure_caveat(ctx, f, &mut out) };
            (rc, opt_string_from(out))
        })
    }
}
