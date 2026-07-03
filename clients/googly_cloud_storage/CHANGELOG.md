# Changelog

All notable changes to this package are documented here.
This file is maintained by `mix googly.release`; edit an entry to add detail
before you publish.

## 0.1.2 - 2026-07-03

- Read upload `File.Stream` data as raw bytes, so the request `Content-Length` matches the body actually sent (line-mode streams no longer corrupt uploads).
- Sanitize Google's descriptions in generated docs, so ExDoc builds cleanly without HTML warnings.
- Fix README usage examples to call real function heads from this client.

## 0.1.1 - 2026-07-02

- Fix RFC 6570 reserved expansion for `{+name}` resource-path parameters, so path values containing `/` (e.g. object names) are no longer over-encoded.
- Order optional parameters deterministically in generated function docs and specs.
- Prefix the package description with "Google" for discoverability on Hex.

## 0.1.0 - 2026-07-01

- Initial release.
