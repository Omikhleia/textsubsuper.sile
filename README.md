# textsubsuper.sile

[![License](https://img.shields.io/github/license/Omikhleia/textsubsuper.sile?label=License)](LICENSE)
[![Luacheck](https://img.shields.io/github/actions/workflow/status/Omikhleia/textsubsuper.sile/luacheck.yml?branch=main&label=Luacheck&logo=Lua)](https://github.com/Omikhleia/textsubsuper.sile/actions?workflow=Luacheck)
[![Luarocks](https://img.shields.io/luarocks/v/Omikhleia/textsubsuper.sile?label=Luarocks&logo=Lua)](https://luarocks.org/modules/Omikhleia/textsubsuper.sile)

This package for the [SILE](https://github.com/sile-typesetter/sile) typesetting system provides ways to typeset superscripted or subscripted text properly, using real (i.e. based on OpênType font properties) or fake (scaled and raised) characters, with several tuning options.

As it names imply, it is not a general-purpose super/subscript package, but it operates on text:

- Detecting and using, when available, OpenType font features for “real” superscripts or subscripts;
- Scaling and raising (or lowering) characters in the “fake” case, with special provisions for digits and character weight.

In other words, it aims at providing a standardized way to get a “decent typographical” output for superscripted or subscripted text, with appropriate fallbacks.

![superscripts and subscripts](textsubsuper.png "Superscripts and subscripts")

## Installation

This package require SILE v0.15.12.

Installation relies on the **luarocks** package manager.

To install the latest version, you may use the provided “rockspec”:

```
luarocks install textsubsuper.sile
```

(Refer to the SILE manual for more detailed 3rd-party package installation information.)

## Usage

Examples are provided in the [examples](./examples) folder.

The in-code package documentation may also be useful.
A readable version of the documentation is included in the User Manual for the [resilient.sile](https://github.com/Omikhleia/resilient.sile) collection of classes and packages.

## License

The code and samples in this repository are released under the MIT license, (c) 2021-2025 Omikhleia.
