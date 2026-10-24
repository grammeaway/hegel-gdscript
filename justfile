set shell := ["bash", "-euo", "pipefail", "-c"]
set windows-shell := ["bash", "-euo", "pipefail", "-c"]

godot := env("GODOT", "godot")
cargo_lib := if os() == "windows" { "hegel_gdscript.dll" } else if os() == "macos" { "libhegel_gdscript.dylib" } else { "libhegel_gdscript.so" }
addon_lib := if os() == "windows" { "hegel_gdscript.windows.x86_64.dll" } else if os() == "macos" { "libhegel_gdscript.macos.arm64.dylib" } else { "libhegel_gdscript.linux.x86_64.so" }

# Lint, build, import and test.
check: lint build import test

# Build the native library (always release, D7) into addons/hegel/bin/.
build:
    cd rust && cargo build --release
    mkdir -p addons/hegel/bin
    cp rust/target/release/{{cargo_lib}} addons/hegel/bin/{{addon_lib}}

# Import the project. A cold import can crash on exit after finishing its
# work (Godot #111048); the retry runs warm, and must succeed.
import:
    {{godot}} --headless --path . --import || {{godot}} --headless --path . --import

# Run the gdUnit4 suites under tests/.
test:
    GODOT_BIN="$(command -v {{godot}})" addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests

# Check formatting and lints, Rust and GDScript.
lint:
    cd rust && cargo fmt --check
    cd rust && cargo clippy --release -- -D warnings
    uvx --from gdtoolkit==4.5.0 gdlint addons/hegel tests
