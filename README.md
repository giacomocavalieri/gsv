# gsv

[![Package Version](https://img.shields.io/hexpm/v/gsv)](https://hex.pm/packages/gsv)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gsv/)

A simple csv parser and serialiser for Gleam.

```gleam
import gsv.{Unix, Windows}

pub fn main() {
  let csv =
    "name,loves
lucy,gleam"

  // Parse a csv string into a list of rows.
  let assert Ok(rows) = gsv.to_lists(csv, ",")
  // -> [["name", "loves"], ["lucy", "gleam"]]

  // If your csv has headers you can also parse it into a list of dictionaries.
  let assert Ok(rows) = gsv.to_dicts(csv_str, ",")
  // -> [dict.from_list([#("name", "lucy"), #("loves", "gleam")])]
}
```

## Installation

To add this package to your Gleam project:

```sh
gleam add gsv@5
```
