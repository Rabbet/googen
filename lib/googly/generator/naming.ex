defmodule Googly.Generator.Naming do
  @moduledoc """
  Turns untrusted discovery-document names into safe Elixir identifiers.

  A discovery document is untrusted input — googly generates a client for *any*
  API — and names drawn from it (schema, property, resource, and method names)
  are interpolated into generated *code* positions: `defmodule` aliases,
  `defstruct` field atoms, `@type` keys, `def` heads. `Macro.camelize/1` and
  `Macro.underscore/1` are case/segment converters, not sanitizers: they leave
  quotes, brackets, parentheses, spaces, and newlines intact, so a name like
  `Foo do\\n  raise "x"\\nend\\n\\ndefmodule Bar` survives verbatim and injects
  executable code. Every name that reaches generated source must pass through
  here first.

  The wire name (the exact JSON key) is never sanitized — it is preserved
  separately on each field/parameter and baked in via `inspect/1`, so mangling
  the *identifier* here is lossless for the round trip.
  """

  @identifier ~r/^[a-z_][A-Za-z0-9_]*$/
  @segment ~r/^[A-Z][A-Za-z0-9]*$/

  @doc """
  A snake_case struct-field / variable / function identifier. Non-identifier
  characters collapse to `_`; a leading digit or empty result is normalized so
  the output is always a valid atom name (`satisfiesPZS` -> `satisfies_pzs`,
  `$.xgafv` -> `xgafv`).
  """
  @spec field_name(String.t()) :: String.t()
  def field_name(wire) do
    wire
    |> String.replace(~r/[^A-Za-z0-9]+/, "_")
    |> Macro.underscore()
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
    |> normalize_identifier()
    |> assert_matches(@identifier)
  end

  @doc """
  A CamelCase module-alias segment (`bucket` -> `Bucket`). Anything that isn't a
  letter or digit is stripped, so the segment can't carry a `.` (which would
  nest a module), close its `defmodule`, or open a new one; a leading digit or
  empty result is normalized to keep it a valid alias.
  """
  @spec module_segment(String.t()) :: String.t()
  def module_segment(name) do
    name
    |> String.replace(~r/[^A-Za-z0-9]+/, "_")
    |> Macro.camelize()
    # `Macro.camelize/1` keeps an underscore that precedes an uppercase letter or
    # digit (`defmodule_Sneaky` -> `Defmodule_Sneaky`), so strip any residual to
    # collapse the name to a single alias segment.
    |> String.replace("_", "")
    |> normalize_segment()
    |> assert_matches(@segment)
  end

  defp normalize_identifier(""), do: "field"
  defp normalize_identifier(<<d, _::binary>> = s) when d in ?0..?9, do: "n" <> s
  defp normalize_identifier(s), do: s

  defp normalize_segment(""), do: "Unknown"
  defp normalize_segment(<<d, _::binary>> = s) when d in ?0..?9, do: "N" <> s
  defp normalize_segment(s), do: s

  # Belt-and-suspenders: the transforms above already guarantee a safe result,
  # so this only fires if one of them regresses — in which case aborting
  # generation is far safer than emitting the name into code.
  defp assert_matches(value, regex) do
    if value =~ regex do
      value
    else
      raise ArgumentError,
            "refusing to emit unsafe generated identifier #{inspect(value)} " <>
              "(expected #{inspect(regex.source)})"
    end
  end
end
