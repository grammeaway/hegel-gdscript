set shell := ["bash", "-euo", "pipefail", "-c"]
set windows-shell := ["bash", "-euo", "pipefail", "-c"]

godot := env("GODOT", "godot")
cargo_lib := if os() == "windows" { "hegel_gdscript.dll" } else if os() == "macos" { "libhegel_gdscript.dylib" } else { "libhegel_gdscript.so" }
addon_lib := if os() == "windows" { "hegel_gdscript.windows.x86_64.dll" } else if os() == "macos" { "libhegel_gdscript.macos.arm64.dylib" } else { "libhegel_gdscript.linux.x86_64.so" }
python := if os() == "windows" { "python" } else { "python3" }
version := `sed -n 's/^version = "\(.*\)"/\1/p' rust/Cargo.toml`

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

# Zip addons/hegel/, with whatever libraries bin/ holds, into dist/.
package version=version:
    test -n "$(ls addons/hegel/bin)" || { echo "addons/hegel/bin/ is empty: run just build" >&2; exit 1; }
    rm -rf dist/stage dist/hegel-gdscript-{{version}}.zip
    mkdir -p dist/stage/addons
    cp -R addons/hegel dist/stage/addons/
    cp LICENSE README.md CHANGELOG.md dist/stage/addons/hegel/
    cd dist/stage && {{python}} -c "import shutil; shutil.make_archive('../hegel-gdscript-{{version}}', 'zip', '.', 'addons')"
    rm -rf dist/stage
    @echo "dist/hegel-gdscript-{{version}}.zip"

# Unzip a package into a fresh project and run a property there.
smoke-package zip=("dist/hegel-gdscript-" + version + ".zip"):
    rm -rf dist/smoke
    mkdir -p dist/smoke
    {{python}} -c "import shutil, sys; shutil.unpack_archive(sys.argv[1], sys.argv[2])" "{{zip}}" dist/smoke
    printf 'config_version=5\n\n[application]\n\nconfig/name="smoke"\n' > dist/smoke/project.godot
    cp tests/package/smoke.gd dist/smoke/
    cd dist/smoke && { {{godot}} --headless --path . --import || {{godot}} --headless --path . --import; }
    cd dist/smoke && {{godot}} --headless --path . -s res://addons/hegel/cli/run.gd -- res://smoke.gd

# Check formatting and lints, Rust and GDScript.
lint:
    cd rust && cargo fmt --check
    cd rust && cargo clippy --release -- -D warnings
    uvx --from gdtoolkit==4.5.0 gdlint addons/hegel tests examples
