import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleamy/bench
import gsv

pub fn main() {
  bench.run(
    [
      bench.Input("1K", generate_csv(1000)),
      bench.Input("10K", generate_csv(10_000)),
      bench.Input("100K", generate_csv(100_000)),
    ],
    [bench.Function("gsv.to_lists", gsv.to_lists(_, separator: ","))],
    [bench.Duration(5000), bench.Warmup(2000)],
  )
  |> bench.table([bench.IPS, bench.Min, bench.P(99)])
  |> io.println()
}

fn generate_csv(lines: Int) -> String {
  int.range(1, lines + 1, [], fn(acc, _) { [generate_line(), ..acc] })
  |> list.map(fn(_) { generate_line() })
  |> string.join(with: "\n")
}

fn generate_line() -> String {
  int.range(1, 16, [], fn(acc, field_number) {
    case field_number % 3 {
      1 -> ["\"wibble wobble\"", ..acc]
      _ -> ["wibble wobble woo", ..acc]
    }
  })
  |> string.join(with: ",")
}
