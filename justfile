set quiet := true

alias bw := build-wasm
alias c := clean
alias l := link
alias b := bump
alias v := current

cargo := require("cargo")
cp := require("cp")
echo := require("echo")
utpm := require("utpm")
current-patch := replace_regex(trim(replace_regex(read(justfile_directory() / "typst.toml"), "(?m)^[^v](.)*", "")), '[^=]+= "\d+\.\d+\.(\d+)"', "${1}")
current-minor := replace_regex(trim(replace_regex(read(justfile_directory() / "typst.toml"), "(?m)^[^v](.)*", "")), '[^=]+= "\d+\.(\d+)\.\d+"', "${1}")
current-major := replace_regex(trim(replace_regex(read(justfile_directory() / "typst.toml"), "(?m)^[^v](.)*", "")), '[^=]+= "(\d+)\.\d+\.\d+"', "${1}")
current := replace_regex(trim(replace_regex(read(justfile_directory() / "typst.toml"), "(?m)^[^v](.)*", "")), '[^=]+= "(.+)"', "${1}")
default-build-dir := "./target/wasm32-unknown-unknown/release/scheduler.wasm"

[default]
[private]
default:
    {{ just_executable() }} --list --unsorted --justfile {{ justfile() }}

# builds the rust wasm plugin and copies it to the workspace root
build-wasm build-dir=default-build-dir:
    {{ cargo }} build --release --target wasm32-unknown-unknown
    {{ cp }} {{ build-dir }} .

# cleans up the rust build artifacts
clean:
    {{ cargo }} clean

# links the current typst package workspace to the local package storage
link:
    {{ utpm }} ws l

# bumps the current version of the rust crate and the typst plugin
[arg("major", pattern='\d+')]
[arg("minor", pattern='\d+')]
[arg("patch", pattern='\d+')]
bump patch=current-patch minor=current-minor major=current-major:
    {{ if patch + minor + major == current-patch + current-minor + current-major { error("bumping is meant to bump versions; checking them goes through the `current` recipe") } else { "" } }}
    {{ utpm }} ws bump {{ major + "." + minor + "." + patch }}
    {{ cargo }} set-version --bump {{ if major != current-major { "major" } else if minor != current-minor { "minor" } else if patch != current-patch { "patch" } else { error("version bumps are not meant to provide the current package version; use the `current` recipe for that") } }}

# prints out the current typst package version as per the manifest file
current:
    {{ echo }} {{ current }}
