# ZIX

![](vhs/zix.gif)

CLI tool for managing NixOS configuration.

> :warning: **Work in Progress**: Under active development. Features may change.

## Requirements

- **Zig 0.16.0** or later

## Installation

```sh
git clone https://github.com/alvaro17f/zix.git
cd zix
zig build run
```

Move binary to PATH:

```sh
sudo mv zig-out/bin/zix <PATH>
```

### NixOS

```sh
nix run github:alvaro17f/zix#target.x86_64-linux-musl
```

Add to flake:

```nix
{
    inputs = {
        zix.url = "github:alvaro17f/zix";
    };
}
```

```nix
{ inputs, pkgs, ... }:
{
    home.packages = [
        inputs.zix.packages.${pkgs.system}.default
    ];
}
```

## Taskfile

Build tasks via `./taskfile`:

| Task | Description |
|---|---|
| `./taskfile build` | Compile project |
| `./taskfile run` | Execute binary |
| `./taskfile test` | Run test suite |
| `./taskfile coverage` | Run tests + kcov (100% line coverage) |
| `./taskfile fmt` | Format Zig sources |
| `./taskfile clean` | Remove build artifacts |
| `./taskfile` | Show help |

## Coverage

100% line coverage enforced via **kcov**:

```sh
./taskfile coverage
# ✓ coverage: 100.00% (305/305 lines)
```

Tests run with LLVM backend (`.use_llvm = true`) for accurate DWARF instrumentation.

## Usage

```
 ***************************************************
 ZIX - A simple CLI tool to update your nixos system
 ***************************************************
 -r : set repo path (default is $HOME/.dotfiles)
 -n : set hostname (default is OS hostname)
 -k : set generations to keep (default is 10)
 -u : set update to true (default is false)
 -d : set diff to true (default is false)
 -h, help : Display this help message
 -v, version : Display the current version
```

## License

MIT. See LICENSE.
