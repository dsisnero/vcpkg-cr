# vcpkg-cr

This is a helper for finding libraries in a [Vcpkg](https://github.com/Microsoft/vcpkg) installation from crystal build scripts. It works similarly to [pkg-config](https://github.com/alexcrichton/pkg-config-rs). It works on Windows (MSVC ABI), Linux and MacOS.

A crystal port of [vcpkg-rs](https://github.com/mcgoo/vcpkg-rs)

## Installation

```yaml
dependencies:
  vcpkg:
    github: dsisnero/vcpkg-cr
```

...and run `crystal deps` or `shards install`

## Usage

Find the library named `foo` in a [Vcpkg](https://github.com/Microsoft/vcpkg) installation and emit crystal metadata to link it:

```crystal
// build.rs
require "vcpkg"


    Vcpkg.find_package("foo")
```

## Development

## Contributing

1. Fork it (<https://github.com/dsisnero/vcpkg-crystal/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [dsisnero](https://github.com/dsisnero) - creator and maintainer
