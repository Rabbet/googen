defmodule Googly.Generator.UrlSafetyTest do
  # A discovery document is untrusted input (googly generates a client for *any*
  # API). Method and media-upload *paths* are taken verbatim from it and become
  # the request URL in the generated client via `@base_url |> URI.merge(path)`.
  #
  # RFC 3986 reference resolution says a reference that begins with "//" (a
  # protocol-relative URL) or carries a scheme ("https:...") REPLACES the base
  # host. So a crafted path can redirect an authenticated request to an
  # attacker-controlled host — leaking the caller's `Authorization: Bearer
  # <token>` (and, for uploads, the payload). Every generated path must be
  # reduced to a host-relative one so it can only ever address the API's own host.
  use ExUnit.Case, async: true

  alias Googly.Generator.Endpoint
  alias Googly.Generator.ResourceContext

  @base "https://legit.googleapis.com/"

  describe "malicious paths cannot hijack the request host (generation level)" do
    test "a protocol-relative method path stays on the API host" do
      assert on_host?(url_for(method("//attacker.example/exfil/{widgetId}")))
    end

    test "an absolute-URL method path stays on the API host" do
      assert on_host?(url_for(method("https://attacker.example/exfil/{widgetId}")))
    end

    test "a protocol-relative media-upload path stays on the API host" do
      m =
        Map.merge(method("widgets"), %{
          httpMethod: "POST",
          request: %{"$ref": "Widget"},
          mediaUpload: %{protocols: %{simple: %{path: "//attacker.example/upload"}}}
        })

      # from_method yields [basic, media, multipart]; every emitted url must be on-host.
      urls = for ep <- Endpoint.from_method("insert", m, ctx()), do: merged(ep.path)
      assert Enum.all?(urls, &on_host?/1), "off-host url emitted: #{inspect(urls)}"
    end

    test "a legitimate relative path is preserved and on-host (regression guard)" do
      url = url_for(method("widgets/{widgetId}"))
      assert on_host?(url)
      assert URI.parse(url).path == "/widgets/{widgetId}"
    end
  end

  # -- helpers ---------------------------------------------------------------

  defp method(path) do
    %{
      httpMethod: "GET",
      path: path,
      parameterOrder: ["widgetId"],
      parameters: %{"widgetId" => %{type: "string", location: "path", required: true}},
      response: %{"$ref": "Widget"}
    }
  end

  defp ctx do
    ResourceContext.empty()
    |> ResourceContext.with_namespace("Googly.Test")
    |> ResourceContext.with_models_by_name(%{})
  end

  defp url_for(method) do
    [ep] = Endpoint.from_method("get", method, ctx())
    merged(ep.path)
  end

  # Reproduce the generated client's runtime URL construction.
  defp merged(path), do: @base |> URI.merge(path) |> URI.to_string()

  defp on_host?(url), do: URI.parse(url).host == URI.parse(@base).host
end
