defmodule Googly.Changelog do
  @moduledoc """
  Builds and updates each client's `CHANGELOG.md`.

  Unlike the rest of a client, the changelog is *accumulated* history, so it is
  **not** regenerated from scratch on every `mix googly.generate` — like each
  client's `@version`, it lives in the committed client dir and is preserved
  across regenerations. `mix googly.generate` only lays down a baseline when a
  brand-new client has none (`ensure/3`); `mix googly.release` prepends a dated
  entry when it bumps the version (`add_release/4`). It carries no
  "auto generated" banner precisely because a human may refine an entry before
  publishing.
  """

  @header """
  # Changelog

  All notable changes to this package are documented here.
  This file is maintained by `mix googly.release`; edit an entry to add detail
  before you publish.
  """

  @doc "Path to a client dir's changelog."
  def path(dir), do: Path.join(dir, "CHANGELOG.md")

  @doc """
  Writes a baseline changelog for a fresh client. No-op if one already exists,
  so it never clobbers accumulated history on regeneration.
  """
  def ensure(dir, version, date) do
    file = path(dir)
    unless File.exists?(file), do: File.write!(file, baseline(version, date))
    :ok
  end

  @doc "Prepends a release entry for `version` above the most recent entry (creates the file if absent)."
  def add_release(dir, version, date, notes) do
    file = path(dir)
    existing = if File.exists?(file), do: File.read!(file), else: @header
    File.write!(file, prepend(existing, entry(version, date, notes)))
    :ok
  end

  @doc "Initial changelog content for a brand-new client."
  def baseline(version, date), do: @header <> "\n" <> entry(version, date, ["Initial release."])

  @doc "A single changelog entry block (`## version - date` + bullet lines), newline-terminated."
  def entry(version, date, notes) do
    bullets = Enum.map_join(notes, "\n", &"- #{&1}")
    "## #{version} - #{date}\n\n#{bullets}\n"
  end

  @doc "Inserts `entry` above the most recent `## ` entry in `existing`, keeping the preamble on top."
  def prepend(existing, entry) do
    entry = String.trim_trailing(entry)

    case String.split(existing, "\n## ", parts: 2) do
      [head, rest] -> String.trim_trailing(head) <> "\n\n" <> entry <> "\n\n## " <> rest
      [_] -> String.trim_trailing(existing) <> "\n\n" <> entry <> "\n"
    end
  end
end
