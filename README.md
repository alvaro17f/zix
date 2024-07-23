# ZIX

![](vhs/zix.gif)

ZIX is a command line tool for managing NixOS configuration.

> :warning: **Work in Progress**: This project is currently under development. Some features may not be complete and may change in the future.
## Installation

To install ZIX, you can clone the repository and compile the source code:

```sh
git clone https://github.com/alvaro17f/zix.git
cd zix
zig build run
```

## Usage
To use ZIX, run the zix command with the desired options. Here are some examples:

```sh
# Update the system
zix --update

# Keep the last 5 generations
zix --keep 5

# Show the differences between generations
zix --diff
```

## License
ZIX is distributed under the MIT license. See the LICENSE file for more information.
