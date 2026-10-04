# skein-static

The static file handler for a [skein](https://github.com/shruggr/skein), as
an app: it serves files from the instance's `main` tree over HTTP,
through rows of the instance's dispatch table. It is a route handler: the
front door calls it with each request and the row that matched, it writes
nothing, and each request is still an entry in the log. Version **0.2.1**.

## What it is

One program, `bin/static.wasm`, function `get` (interface
`static.files/1`, `writes: false`):

| request | answer |
|---|---|
| GET, HEAD of a file | 200, content type by extension, the blob's CID (git-raw, sha1) as the ETag, `cache-control: no-cache` (caches revalidate; nothing stale) |
| `If-None-Match` with that ETag | 304 |
| a path ending in `/` | its `index` (default `index.html`) |
| a directory named without its `/` | 301 |
| missing, `..`, NUL, a bad escape | 404: nothing is served from outside `root` |
| any other method | 405 |

A row's own settings reach the handler as `match`: `root` (the directory, or
a single file for an exact row; default the tree's top) and `index`.
`src/main.zig` documents the contract in full.

## Use it

Install it as an app; its rows are under `/<app>/`, here `/static/`:

```
skein-host install https://github.com/shruggr/skein-static --instance <handle>
```

The manifest, `etc/app.json` (description left out):

```json
{
  "kind": "app",
  "name": "static",
  "version": "0.2.1",
  "programs": { "static": "bin/static.wasm" },
  "provides": [{ "interface": "static.files/1", "functions": {
    "get": { "writes": false,
      "args": { "method?": "string", "route?": "string", "path?": "string", "query?": "string", "headers?": "map", "match?": "map" },
      "answer": { "status": "int", "type": "string", "headers": "map", "body": "bytes" } } } }],
  "requires": [],
  "dispatch": [
    { "transport": "http", "address": "/site", "prefix": true, "sender": "*", "program": "static", "fn": "get", "root": "www" },
    { "transport": "http", "address": "/", "sender": "*", "program": "static", "fn": "get", "root": "www" }
  ]
}
```

- `prefix: true` serves everything under the address; an exact row serves
  one path. Sender `*` serves without a BRC-104 session; `session` requires
  one.
- It reads the tree of the head `main` (`root` is a path in that tree), not
  the app's own tree. It writes nothing, so the name rule (an app writes
  only heads under its own name) does not constrain it.
- Another app can carry the handler: ship `bin/static.wasm` (or
  `bin/static.cid` when the instance already holds the module) and put that
  program on the app's own http rows.
- An instance booted from a system tree (`skein-host add <handle> --boot
  <dir>`, skein `docs/BOOTSTRAP.md`) wires it with the same rows in
  `etc/dispatch.json`, where the addresses are absolute:

```json
[
  {"transport": "http", "address": "/site", "prefix": true, "sender": "*", "program": "static", "fn": "get", "root": "www"},
  {"transport": "http", "address": "/favicon.ico", "sender": "*", "program": "static", "fn": "get", "root": "www/favicon.ico"}
]
```

## Build and test

Zig 0.16.0 (`mise.toml`).

```
zig build          # zig-out/bin/static.wasm
zig build bin      # the same, into bin/static.wasm (committed; the build is reproducible)
zig build test     # content types, paths, escapes refused, If-None-Match (natively)
```

skein runs this app end to end in `kernel-zig/equiv/static.ts` (a pinned
commit of this repo): the index, nested files, the 301, the 404s, the 405,
HEAD, ETag and 304, every request an entry, and a replay.

## Docs

| what | where |
|---|---|
| the handler's contract | `src/main.zig` |
| apps, manifests, install | skein `docs/APPS.md` |
| route handlers and the dispatch table | skein `docs/MESSAGES.md` |

## Versions

| | |
|---|---|
| this app | 0.2.1 (tag `v0.2.1`) |
| skein-sdk | v0.4.0, by tag tarball and hash in `build.zig.zon` (`cbor`, `sk`; no wallet) |
| skein | log format 8; skein's equivs pin this repo by commit |

0.2.0 reads the dispatch row shape of shruggr/skein#77 only (`prefix: true`
and the path in `address`; shruggr/skein#79).

## Contributing

Work is tracked in shruggr/skein; start at issue
[#31](https://github.com/shruggr/skein/issues/31). MIT, as skein.
