//! gdext bindings over the libhegel C ABI (the `hegeltest-c` crate). This
//! layer is deliberately thin: each method makes one `hegel_*` call, converts
//! its arguments and results, and records the result code. Every policy
//! decision lives in the GDScript addon.

use godot::prelude::*;
use hegel_c as c;
use hegel_c::hegel_result_t as Rc;
use std::ffi::c_char;

mod run;
mod settings;
mod test_case;

struct HegelExtension;

#[gdextension]
unsafe impl ExtensionLibrary for HegelExtension {}

struct ThreadContext(*mut c::HegelContext);

impl Drop for ThreadContext {
    fn drop(&mut self) {
        // SAFETY: the pointer came from hegel_context_new and is freed once.
        let _ = unsafe { c::hegel_context_free(self.0) };
    }
}

thread_local! {
    static CONTEXT: ThreadContext = ThreadContext(c::hegel_context_new());
}

/// A call's result code, as an int, and its message (empty on success).
pub(crate) type Outcome = (i64, GString);

/// Makes one libhegel call on this thread's context.
pub(crate) fn call(f: impl FnOnce(*mut c::HegelContext) -> Rc) -> Outcome {
    CONTEXT.with(|ctx| {
        let rc = f(ctx.0);
        if rc == Rc::HEGEL_OK {
            return (rc as i64, GString::new());
        }
        // SAFETY: the message is valid until the next call on this context,
        // and is copied out here.
        let message = string_from(unsafe { c::hegel_context_last_error(ctx.0) });
        (rc as i64, GString::from(&message))
    })
}

/// Fails a call whose int argument doesn't fit its C parameter, as libhegel
/// fails one with an invalid argument.
pub(crate) fn out_of_range(name: &str, value: i64) -> Outcome {
    (
        Rc::HEGEL_E_INVALID_ARG as i64,
        GString::from(&format!("{name} is out of range: {value}")),
    )
}

/// A borrowed engine string viewing `s`, valid while `s` is.
pub(crate) fn hstr(s: &str) -> c::hegel_string_t {
    c::hegel_string_t {
        data: s.as_ptr() as *const c_char,
        len: s.len(),
    }
}

/// Copies an engine string out. NULL data is the empty string.
pub(crate) fn string_from(s: c::hegel_string_t) -> String {
    if s.data.is_null() {
        return String::new();
    }
    // SAFETY: the engine guarantees `len` readable bytes at `data`.
    let bytes = unsafe { std::slice::from_raw_parts(s.data as *const u8, s.len) };
    String::from_utf8_lossy(bytes).into_owned()
}

/// Copies an optional engine string out. NULL, meaning absent, is "".
pub(crate) fn opt_string_from(p: *const c::hegel_string_t) -> String {
    if p.is_null() {
        return String::new();
    }
    // SAFETY: a non-NULL pointer refers to a live engine string.
    string_from(unsafe { *p })
}

/// libhegel's result codes and the calls that belong to no handle.
#[derive(GodotClass)]
#[class(no_init, base=Object)]
pub struct HegelNative;

#[godot_api]
impl HegelNative {
    #[constant]
    const OK: i64 = Rc::HEGEL_OK as i64;
    #[constant]
    const E_STOP_TEST: i64 = Rc::HEGEL_E_STOP_TEST as i64;
    #[constant]
    const E_ASSUME: i64 = Rc::HEGEL_E_ASSUME as i64;
    #[constant]
    const E_BACKEND: i64 = Rc::HEGEL_E_BACKEND as i64;
    #[constant]
    const E_INVALID_HANDLE: i64 = Rc::HEGEL_E_INVALID_HANDLE as i64;
    #[constant]
    const E_INVALID_ARG: i64 = Rc::HEGEL_E_INVALID_ARG as i64;
    #[constant]
    const E_ALREADY_COMPLETE: i64 = Rc::HEGEL_E_ALREADY_COMPLETE as i64;
    #[constant]
    const E_NOT_COMPLETE: i64 = Rc::HEGEL_E_NOT_COMPLETE as i64;
    #[constant]
    const E_INTERNAL: i64 = Rc::HEGEL_E_INTERNAL as i64;
    #[constant]
    const E_CONCURRENT_USE: i64 = Rc::HEGEL_E_CONCURRENT_USE as i64;
    #[constant]
    const E_RETRY: i64 = Rc::HEGEL_E_RETRY as i64;
    #[constant]
    const E_NOT_FOUND: i64 = Rc::HEGEL_E_NOT_FOUND as i64;

    /// libhegel's version string.
    #[func]
    fn version() -> GString {
        let mut out = c::hegel_string_t::default();
        let (rc, error) = call(|ctx| unsafe { c::hegel_version(ctx, &mut out) });
        if rc != Rc::HEGEL_OK as i64 {
            godot_error!("hegel_version failed: {error}");
        }
        GString::from(&string_from(out))
    }

    /// The span label for `name`. Labels are u64 in libhegel; they cross into
    /// GDScript bit-cast to int.
    #[func]
    fn label_from_name(name: GString) -> i64 {
        let name = name.to_string();
        let mut out = 0u64;
        let (rc, error) =
            call(|ctx| unsafe { c::hegel_label_from_name(ctx, hstr(&name), &mut out) });
        if rc != Rc::HEGEL_OK as i64 {
            godot_error!("hegel_label_from_name failed: {error}");
        }
        out as i64
    }

    /// The span label combining `labels`, in order.
    #[func]
    fn label_combine(labels: PackedInt64Array) -> i64 {
        let labels: Vec<u64> = labels.as_slice().iter().map(|&l| l as u64).collect();
        let mut out = 0u64;
        let (rc, error) = call(|ctx| unsafe {
            c::hegel_label_combine(ctx, labels.as_ptr(), labels.len(), &mut out)
        });
        if rc != Rc::HEGEL_OK as i64 {
            godot_error!("hegel_label_combine failed: {error}");
        }
        out as i64
    }
}
