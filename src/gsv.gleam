import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string
import glearray
import splitter

// --- TYPES -------------------------------------------------------------------

/// Possible line endings used when turning a parsed csv back into a string
/// with the `from_lists` and `from_dicts` functions.
///
pub type LineEnding {
  /// The CRLF line ending: `\r\n`.
  ///
  Windows

  /// The LF line ending: `\n`.
  Unix
}

/// An error that could occurr trying to parse a csv file.
///
pub type Error {
  /// This happens when a field that is not escaped contains a double quote,
  /// like this:
  ///
  /// ```csv
  /// first field,second "field",third field
  /// ```
  ///
  /// If a field needs to have quotes it should be escaped like this:
  ///
  /// ```csv
  /// first field,"second ""field""",third field
  /// ```
  ///
  UnescapedQuote(
    /// The line where the unescaped quote is found.
    line: Int,
  )

  /// This happens when there's an escaped field that is missing a closing
  /// quote, like this:
  ///
  /// ```csv
  /// first field,"escaped but I'm missing the closing quote
  /// some other field,one last field
  /// ```
  ///
  MissingClosingQuote(
    /// The line where the field with the missing closing quote starts.
    starting_line: Int,
  )
}

fn line_ending_to_string(le: LineEnding) -> String {
  case le {
    Windows -> "\r\n"
    Unix -> "\n"
  }
}

// --- PARSING -----------------------------------------------------------------

type Splitters {
  Splitters(
    separator: String,
    /// A splitter that matches with either `\n` or `\r\n`.
    newlines: splitter.Splitter,
    /// A splitter that matches with either a `,` separator, or the escape
    /// character `"`.
    separator_or_quote: splitter.Splitter,
    /// A splitter that matches with either the escape charater (a single `"`),
    /// or with an escaped quote (two `"` in a row).
    quotes: splitter.Splitter,
  )
}

/// Parses a csv string into a list of lists of strings: each line of the csv
/// will be turned into a list with an item for each field.
///
/// ## Examples
///
/// ```gleam
/// "hello, world
/// goodbye, mars"
/// |> gsv.to_lists(seperator: ",")
/// // Ok([
/// //    ["hello", " world"],
/// //    ["goodbye", " mars"],
/// // ])
/// ```
///
/// > This implementation tries to stick as closely as possible to
/// > [RFC4180](https://www.ietf.org/rfc/rfc4180.txt), with a couple of notable
/// > differences:
/// > - both `\n` and `\r\n` line endings are accepted.
/// > - empty lines are allowed and just ignored.
/// > - lines are not forced to all have the same number of fields.
/// > - a line can start with an empty field `,two,three`.
/// > - a line can end with an empty field `one,two,`.
pub fn to_lists(
  csv: String,
  separator separator: String,
) -> Result(List(List(String)), Error) {
  let splitters =
    Splitters(
      separator:,
      newlines: splitter.new(["\r\n", "\n"]),
      separator_or_quote: splitter.new([separator, "\""]),
      quotes: splitter.new(["\"\"", "\""]),
    )

  lines_loop(csv, splitters, 0, [])
}

fn lines_loop(
  csv: String,
  splitters: Splitters,
  line_number: Int,
  lines: List(List(String)),
) -> Result(List(List(String)), Error) {
  case csv {
    "" -> Ok(list.reverse(lines))
    _ ->
      case line_loop(csv, splitters, line_number) {
        Error(error) -> Error(error)
        Ok(#(rest, line_number, line)) ->
          lines_loop(rest, splitters, line_number, [line, ..lines])
      }
  }
}

fn line_loop(
  csv: String,
  splitters: Splitters,
  line_number: Int,
) -> Result(#(String, Int, List(String)), Error) {
  case splitter.split(splitters.newlines, csv) {
    // We've reached the end of the csv, there's no line to parse.
    #("", _, "") -> Ok(#("", line_number, []))

    // We ignore any empty line and just skip to the next.
    #("", _, rest) -> line_loop(rest, splitters, line_number + 1)

    // Otherwise we get all the fields out of the current line.
    #(line, newline, rest) ->
      field_loop(line, newline, rest, splitters, line_number + 1, [])
  }
}

/// This parses all the fields from the given line, returning them along with
/// the reamining part of the csv that was not parsed.
///
/// > You might have noticed that this doesn't just takes the line to parse as
/// > input, but it also needs the rest of the csv file. It might sound counter
/// > intuitive, but its need is explained in more detail in the `escape_loop`
/// > function.
///
fn field_loop(
  line: String,
  newline: String,
  rest: String,
  splitters: Splitters,
  line_number: Int,
  fields: List(String),
) -> Result(#(String, Int, List(String)), Error) {
  case splitter.split(splitters.separator_or_quote, line) {
    // There's no commas (nor escapes) left in the string, so we know we've
    // reached the last field in the line.
    #(field, "", "") ->
      Ok(#(rest, line_number, list.reverse([field, ..fields])))

    // A field starting with `"` is escaped and needs special handling.
    #("", "\"", line) -> {
      let start = line_number
      let field =
        escaped_loop(line, newline, rest, splitters, start, line_number, "")

      case field {
        Error(error) -> Error(error)
        Ok(#("", _, rest, line_number, field)) ->
          Ok(#(rest, line_number, list.reverse([field, ..fields])))
        Ok(#(line, newline, rest, line_number, field)) -> {
          let fields = [field, ..fields]
          field_loop(line, newline, rest, splitters, line_number, fields)
        }
      }
    }

    // There's a stray escape in the middle of a field that is not escaped.
    // This is an error!
    #(_, "\"", _) -> Error(UnescapedQuote(line_number))

    // We've found a field and the line is not over, so we just keep going,
    // parsing fields from the rest of the line.
    #(field, _, line) -> {
      let fields = [field, ..fields]
      field_loop(line, newline, rest, splitters, line_number, fields)
    }
  }
}

/// This parses an escaped field from the start of the line, once we've already
/// found the opening `"`.
///
/// > You might have noticed this also needs the rest of the document and just
/// > the current line is not enough. This is because an escaped field might
/// > contain newlines, and so we could end up needing to get more lines from
/// > the `rest` of the csv to properly parse the row.
///
fn escaped_loop(
  line: String,
  newline: String,
  rest: String,
  splitters: Splitters,
  // This is the line where the current row has started, and it is used to build
  // a nice error if the escaped field is missing a close quote.
  start: Int,
  line_number: Int,
  // The field is being built piece by piece as we also need to be unescaping
  // escaped quotes and can't just take the content between quotes verbatim.
  // This is the accumulator holding the field as it is being built.
  field: String,
) -> Result(#(String, String, String, Int, String), Error) {
  case splitter.split(splitters.quotes, line) {
    // We've reached the end of the line without finding any closing quote.
    // This could mean two things:
    #(line_piece, "", "") ->
      case splitter.split(splitters.newlines, rest) {
        // 1. we have reached the end of the entire csv file and there's no
        //    closed quote, that is an error.
        #("", "", "") -> Error(MissingClosingQuote(start))

        // 2. we have an escaped field that is spanning multiple lines and we
        //    need to get a new line from the rest of the csv to properly parse
        //    it.
        #(line, rest_newline, rest) -> {
          let line = line_piece <> newline <> line
          let line_number = line_number + 1
          escaped_loop(
            line,
            rest_newline,
            rest,
            splitters,
            start,
            line_number,
            field,
          )
        }
      }

    // If we find a double quote, we need to unescape it: that is we replace it
    // with a single quote in the final field.
    #(field_piece, "\"\"", line) -> {
      let field = field <> field_piece <> "\""
      escaped_loop(line, newline, rest, splitters, start, line_number, field)
    }

    // The field is properly closed and there's nothing more to the line.
    #(field_piece, _, "") -> {
      let field = case field {
        "" -> field_piece
        _ -> field <> field_piece
      }
      Ok(#("", newline, rest, line_number, field))
    }

    // The field is properly closed, but the line is not over! So we need to
    // keep going.
    #(field_piece, _, line) -> {
      // We remove the leading separator from the rest of the line.
      case string.starts_with(line, splitters.separator) {
        False -> Error(UnescapedQuote(line_number))
        True -> {
          let line = splitter.split(splitters.separator_or_quote, line).2
          let field = case field {
            "" -> field_piece
            _ -> field <> field_piece
          }
          Ok(#(line, newline, rest, line_number, field))
        }
      }
    }
  }
}

/// Parses a csv string into a list of dicts: the first line of the csv is
/// interpreted as the headers' row and each of the following lines is turned
/// into a dict with a value for each of the headers.
///
/// If a field is empty then it won't be added to the dict.
///
/// ## Examples
///
/// ```gleam
/// "pet,name,cuteness
/// dog,Fido,100
/// cat,,1000
/// "
/// |> gsv.to_dicts(separator: ",")
/// // Ok([
/// //    dict.from_list([
/// //      #("pet", "dog"), #("name", "Fido"), #("cuteness", "100")
/// //    ]),
/// //    dict.from_list([
/// //      #("pet", "cat"), #("cuteness", "1000")
/// //    ]),
/// // ])
/// ```
///
/// > Just like `to_lists` this implementation tries to stick as closely as
/// > possible to [RFC4180](https://www.ietf.org/rfc/rfc4180.txt).
/// > You can look at `to_lists`' documentation to see how it differs from the
/// > RFC.
///
pub fn to_dicts(
  input: String,
  separator field_separator: String,
) -> Result(List(Dict(String, String)), Error) {
  use rows <- result.map(to_lists(input, field_separator))
  case rows {
    [] -> []
    [headers, ..rows] -> {
      let headers = glearray.from_list(headers)

      use row <- list.map(rows)
      use row, field, index <- list.index_fold(row, dict.new())
      case field {
        // If the field is empty then we don't add it to the row's dict.
        "" -> row
        _ ->
          // We look for the header corresponding to this field's position.
          case glearray.get(headers, index) {
            Ok(header) -> dict.insert(row, header, field)
            // This could happen if the row has more fields than headers in the
            // header row, in this case the field is just discarded
            Error(_) -> row
          }
      }
    }
  }
}

/// Takes a list of lists of strings and turns it to a csv string, automatically
/// escaping all fields that contain double quotes or line endings.
///
/// ## Examples
///
/// ```gleam
/// let rows = [["hello", "world"], ["goodbye", "mars"]]
/// from_lists(rows, separator: ",", line_ending: Unix)
/// // "hello,world
/// // goodbye,mars"
/// ```
///
///
pub fn from_lists(
  rows: List(List(String)),
  separator separator: String,
  line_ending line_ending: LineEnding,
) -> String {
  let line_ending = line_ending_to_string(line_ending)

  list.map(rows, fn(row) {
    list.map(row, escape_field(_, separator))
    |> string.join(with: separator)
  })
  |> string.join(with: line_ending)
  |> string.append(line_ending)
}

fn escape_field(field: String, separator: String) -> String {
  case string.contains(field, "\"") {
    True -> "\"" <> string.replace(in: field, each: "\"", with: "\"\"") <> "\""
    False ->
      case string.contains(field, separator) || string.contains(field, "\n") {
        True -> "\"" <> field <> "\""
        False -> field
      }
  }
}

/// Takes a list of dicts and writes it to a csv string.
/// Will automatically escape strings that contain double quotes or
/// line endings with double quotes (in csv, double quotes get escaped by doing
/// a double doublequote)
/// The string `he"llo\n` becomes `"he""llo\n"`
///
pub fn from_dicts(
  rows: List(Dict(String, String)),
  separator separator: String,
  line_ending line_ending: LineEnding,
) -> String {
  case rows {
    [] -> ""
    _ -> {
      let headers =
        rows
        |> list.flat_map(dict.keys)
        |> list.unique
        |> list.sort(string.compare)

      let rows = list.map(rows, row_dict_to_list(_, headers))
      from_lists([headers, ..rows], separator, line_ending)
    }
  }
}

fn row_dict_to_list(
  row: Dict(String, String),
  headers: List(String),
) -> List(String) {
  use header <- list.map(headers)
  case dict.get(row, header) {
    Ok(field) -> field
    Error(Nil) -> ""
  }
}
