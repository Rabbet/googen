defmodule Googen.Generator.TypeTest do
  use ExUnit.Case, async: true

  alias Googen.Generator.Model
  alias Googen.Generator.ResourceContext
  alias Googen.Generator.Type

  describe "scalars" do
    test "string" do
      assert %Type{name: "string", typespec: "String.t()", decode: :raw} =
               Type.from_schema(%{type: "string"}, ctx())
    end

    test "integer" do
      assert %{typespec: "integer()", decode: :raw} = Type.from_schema(%{type: "integer"}, ctx())
      assert %{typespec: "integer()"} = Type.from_schema(%{type: "int"}, ctx())
    end

    test "boolean, number, float, any" do
      assert %{typespec: "boolean()"} = Type.from_schema(%{type: "boolean"}, ctx())
      assert %{typespec: "number()"} = Type.from_schema(%{type: "number"}, ctx())
      assert %{typespec: "float()"} = Type.from_schema(%{type: "number", format: "double"}, ctx())
      assert %{typespec: "any()"} = Type.from_schema(%{type: "any"}, ctx())
    end

    test "int64 stays a string (JSON encodes it as a string)" do
      assert %{typespec: "String.t()", decode: :raw} =
               Type.from_schema(%{type: "string", format: "int64"}, ctx())
    end
  end

  describe "temporals" do
    test "date" do
      assert %Type{struct: "Date", typespec: "Date.t()", decode: :date} =
               Type.from_schema(%{type: "string", format: "date"}, ctx())
    end

    test "date-time / time / google-datetime all decode as DateTime" do
      for fmt <- ["date-time", "time", "google-datetime"] do
        assert %Type{struct: "DateTime", typespec: "DateTime.t()", decode: :datetime} =
                 Type.from_schema(%{type: "string", format: fmt}, ctx())
      end
    end
  end

  describe "arrays" do
    test "array of scalars is raw" do
      assert %Type{typespec: "list(String.t())", decode: :raw} =
               Type.from_schema(%{type: "array", items: %{type: "string"}}, ctx())
    end

    test "array of refs decodes via the element module (decode/1 handles lists)" do
      assert %Type{
               typespec: "list(Gcp.Widget.Model.Part.t())",
               struct: "Gcp.Widget.Model.Part",
               decode: {:struct, "Gcp.Widget.Model.Part"}
             } = Type.from_schema(%{type: "array", items: %{"$ref": "Part"}}, ctx())
    end

    test "array of date-times becomes a temporal list" do
      assert %Type{typespec: "list(DateTime.t())", decode: {:list, :datetime}} =
               Type.from_schema(
                 %{type: "array", items: %{type: "string", format: "date-time"}},
                 ctx()
               )
    end

    test "array of arrays nests the typespec" do
      schema = %{type: "array", items: %{type: "array", items: %{type: "string"}}}

      assert %Type{typespec: "list(list(String.t()))", decode: :raw} =
               Type.from_schema(schema, ctx())
    end
  end

  describe "maps (additionalProperties)" do
    test "scalar values -> map()" do
      assert %Type{name: "map", typespec: "map()", decode: :raw} =
               Type.from_schema(%{additionalProperties: %{type: "string"}}, ctx())
    end

    test "ref values -> typed map decoded per value" do
      assert %Type{
               typespec: "%{optional(String.t()) => Gcp.Widget.Model.Owner.t()}",
               decode: {:map, "Gcp.Widget.Model.Owner"}
             } = Type.from_schema(%{additionalProperties: %{"$ref": "Owner"}}, ctx())
    end
  end

  describe "$ref" do
    test "object ref" do
      assert %Type{
               name: "object",
               struct: "Gcp.Widget.Model.Owner",
               typespec: "Gcp.Widget.Model.Owner.t()",
               decode: {:struct, "Gcp.Widget.Model.Owner"}
             } = Type.from_schema(%{"$ref": "Owner"}, ctx())
    end

    test "ref to an array-typed model becomes a list" do
      models = %{"Parts" => %Model{name: "Parts", is_array: true}}

      assert %Type{name: "array", typespec: "list(Gcp.Widget.Model.Parts.t())"} =
               Type.from_schema(%{"$ref": "Parts"}, ctx(models))
    end
  end

  test "repeated schema behaves like an array" do
    assert %Type{typespec: "list(String.t())", decode: :raw} =
             Type.from_schema(%{type: "string", repeated: true}, ctx())
  end

  test "empty/0 is the nil return type" do
    assert %Type{typespec: "nil"} = Type.empty()
  end

  defp ctx, do: ResourceContext.with_namespace(ResourceContext.empty(), "Gcp.Widget")

  defp ctx(models_by_name), do: ResourceContext.with_models_by_name(ctx(), models_by_name)
end
