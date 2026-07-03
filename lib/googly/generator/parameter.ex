defmodule Googly.Generator.Parameter do
  @moduledoc """
  An argument to an endpoint. Required parameters become positional function
  arguments (`variable_name`); optional ones are passed via `opts` keyed by
  their snake_case `name`, translated back to `wire` on the query string.
  """

  alias Googly.Generator.Naming
  alias Googly.Generator.ResourceContext
  alias Googly.Generator.Type

  @enforce_keys [:name, :wire, :variable_name, :type, :location]
  defstruct [:name, :wire, :variable_name, :description, :type, :location, reserved?: false]

  @type t :: %__MODULE__{
          name: String.t(),
          wire: String.t(),
          variable_name: String.t(),
          description: String.t() | nil,
          type: Type.t(),
          location: String.t(),
          reserved?: boolean()
        }

  @doc "Splits a method's parameters into `{required, optional}`."
  @spec from_method(map, ResourceContext.t()) :: {[t], [t]}
  def from_method(method, context) do
    params = method[:parameters] || %{}
    order = method[:parameterOrder] || []
    request = method[:request]
    path = method[:path] || ""

    {required, optional} = Enum.split_with(params, fn {_name, schema} -> schema[:required] end)

    required_by_name =
      Map.new(required, fn {name, schema} ->
        {to_string(name), build(to_string(name), schema, context, path)}
      end)

    required = Enum.map(order, &required_by_name[to_string(&1)]) |> Enum.reject(&is_nil/1)

    optional =
      optional
      |> Enum.map(fn {name, schema} -> build(to_string(name), schema, context, path) end)
      |> Enum.sort_by(& &1.name)

    optional = if request, do: optional ++ [body_param(request, context)], else: optional

    {required, optional}
  end

  defp body_param(request, context) do
    wire = request[:parameterName] || "body"

    %__MODULE__{
      name: "body",
      wire: wire,
      variable_name: "body",
      description: request[:description],
      type: Type.from_schema(request, context),
      location: "body"
    }
  end

  @doc "Builds a standalone parameter (e.g. a global query parameter)."
  def from_method_param(wire, schema, context), do: build(wire, schema, context, "")

  defp build(wire, schema, context, path) do
    name = Naming.field_name(wire)

    %__MODULE__{
      name: name,
      wire: wire,
      variable_name: name,
      description: schema[:description],
      type: Type.from_schema(schema, context),
      location: schema[:location] || "query",
      reserved?: reserved?(wire, path)
    }
  end

  # `{+wire}` in a discovery path is RFC 6570 reserved expansion: the value is a
  # resource name (e.g. `projects/p/locations/l/processors/x`) whose `/` must
  # survive into the URL. Plain `{wire}` (simple expansion) percent-encodes `/`,
  # which is what a single path segment such as a GCS object name wants.
  defp reserved?(wire, path), do: String.contains?(path, "{+#{wire}}")
end
