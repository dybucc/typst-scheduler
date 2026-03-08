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
current_patch := replace_regex(trim(replace_regex(read(justfile_directory() / "typst.toml"), "(?m)^[^v](.)*", "")), '[^=]+= "\d+\.\d+\.(\d+)"', "${1}")
current_minor := replace_regex(trim(replace_regex(read(justfile_directory() / "typst.toml"), "(?m)^[^v](.)*", "")), '[^=]+= "\d+\.(\d+)\.\d+"', "${1}")
current_major := replace_regex(trim(replace_regex(read(justfile_directory() / "typst.toml"), "(?m)^[^v](.)*", "")), '[^=]+= "(\d+)\.\d+\.\d+"', "${1}")
current := replace_regex(trim(replace_regex(read(justfile_directory() / "typst.toml"), "(?m)^[^v](.)*", "")), '[^=]+= "(.+)"', "${1}")

[default]
[private]
default:
    {{ just_executable() }} --list --unsorted --justfile {{ justfile() }}

# builds the rust project containing the wasm plugin and copy it to the ws root
build-wasm:
    {{ cargo }} build --release --target wasm32-unknown-unknown
    {{ cp }} ./target/wasm32-unknown-unknown/release/scheduler.wasm .

# cleans up the build artifacts from the rust plugin
clean:
    {{ cargo }} clean

# links the current typst package workspace to the local package storage
link:
    {{ utpm }} ws l

# bumps the current version of the rust crate and the typst plugin
bump type patch=current_patch minor=current_minor major=current_major:
    {{ utpm }} ws bump {{ major + "." + minor + "." + patch }}
    {{ cargo }} set-version --bump {{ if type == "patch" { "patch" } else if type == "minor" { "minor" } else if type == "major" { "major" } else { error("only supported version bumps are: `patch`, `minor`, `major`") } }}

# prints out the current typst package version as per the manifest file
current:
    {{ echo }} {{ current }}
