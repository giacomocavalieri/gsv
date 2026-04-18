# Changelog

## v5.1.0 - 18 April 2026

- Updated the `gleam_stdlib` constraint to allow using `v1.0.0`.

## v5.0.1 - 22 February 2026

- Updated the `gleam_stdlib` dependency and dropped use of deprecated function.

## v5.0.0 - 13 August 2025

- The performance of `to_lists` and `to_dicts` has been improved.
- The `ParseError` type has been renamed to `Error`.
- The `UnescapedQuote` and `MissingClosingQuote` errors now include the line
  where the error occurs instead of a hard to read byte number.

## v4.0.0 - 8 January 2025

- Added a `separator` parameter to `to_lists` and `to_dicts` as a way of
  specifying non-standard CSV field separators. (#16)

## v3.0.2 - 8 January 2025

- Dependency requirement for `glearray` has been relaxed to permit v1 or v2.

## v3.0.1 - 13 November 2024

- `from_lists` and consequently `from_dicts` now append a line ending to the end
  of the produced string. This is a patch release because the RFC states line
  endings after the final row are optional, but most people will want them.

## v3.0.0 - 4 November 2024

- Improved performance of `to_lists`, `to_dicts`, `from_lists` and `from_lists`.
- Parsing now doesn't trim the csv fields, conforming to RFC4180.
- The `to_lists` and `to_dicts` functions now return a structured error instead
  of a `String`.

## v2.0.3 - 25 October 2024

- Patch to remove some unused imports.

## v2.0.2 - 25 October 2024

- Patch to fix bug with handling closing quotes before a newline.

## v2.0.1 - 26 September 2024

- Patch to consider all headers in from_dicts.

## v2.0.0 - 24 September 2024

- Now there are four public functions, `to_lists`, `to_dicts`, `from_lists` and
  `from_dicts`.

## v1.4.0 - 29 March 2024

- Fix bug where trailing comma was causing error

## v1.3.1 - 1 February 2024

- Update to gleam_stdlib = "~> 0.34 or ~> 1.0" in preparation for 1.0

## v1.2.1 - 5 January 2024

- Fix bug with double commas producing error, now produce empty string

## v1.2.0 - 29 December 2023

- Add `to_lists_or_error` function

## v1.1.0 - 29 December 2023

- Add a function which panics with an appropriate error message on failure to
  parse csv. This includes the token location.

## v1.0.0 - 27 December 2023

- Init changelog w/v1 so people's stuff doesn't break.
