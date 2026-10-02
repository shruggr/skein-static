# skein-static

The static file handler for a [skein](https://github.com/shruggr/skein)
instance (shruggr/skein#52), as an app (skein `docs/APPS.md`). Split out of
skein by shruggr/skein#71, with its history (`programs/static`).

It serves files from the instance's `main` tree through the instance's
dispatch table (skein #77). It is a **route handler**: the front door calls
its `fn "get"` with each request and the dispatch row that matched. It is
never stepped and writes nothing; each request is still an entry in the log
(skein #68). GET and HEAD are answered. A path ending in `/` serves its
`index` (default `index.html`). A directory named without the `/` is a 301.
A missing file, a `..` segment, a NUL or a bad escape is a 404, so nothing is
served from outside `root`. Any other method is a 405. The ETag is the blob's
CID (git-raw, sha1), and `If-None-Match` is answered 304. `src/main.zig`
documents the contract in full.

## The tree

```
bin/static.wasm   the module (wasm32-wasi, committed; `zig build bin` rewrites it)
etc/app.json      the manifest (skein docs/APPS.md §2)
src/main.zig      the handler
```

`bin/static.wasm` is the module skein pinned for `static` before #71:
raw CID `bafkreiewar6biptwbkvwmrymqixp24nyekcv6skzibbw57mnkwuiykvazu`. The build
is reproducible.

## Using it

A tree that serves files does two things:

1. It carries the module, as `bin/static.wasm` (copied from here) or as
   `bin/static.cid` (that CID, when the instance already holds the module).
   It may also carry `bin/static.json` (`{inputs, description}`).
2. It puts static on http rows in `etc/dispatch.json` (skein #77):

```json
[
  {"transport": "http", "address": "/site", "prefix": true, "sender": "*", "program": "static", "fn": "get", "root": "www"},
  {"transport": "http", "address": "/favicon.ico", "sender": "*", "program": "static", "fn": "get", "root": "www/favicon.ico"},
  {"transport": "http", "address": "/", "sender": "*", "program": "static", "fn": "get", "root": "www"}
]
```

`root` (default: the tree's top) and `index` (default `index.html`) are the
row's own settings, carried to the handler as `match`. Sender `*` serves the
files without a BRC-104 session; `session` requires one. An exact row whose
root is a file serves that file.

Installed as an app (`skein-host install`, skein docs/APPS.md), its rows are
`etc/app.json`'s, relative to `/static/`. 0.2.0 (skein #79) reads the #77 row
shape only (`prefix: true`, the path its `address`); 0.1.0 read the routes
table's `prefix` text.

Booting an instance from such a tree is `skein-host add <handle> --boot <dir>`
(skein `docs/BOOTSTRAP.md`). Installing into a running instance is the three
owner messages of skein `docs/APPS.md` §3: `objects` with the tree, `head`,
and the routes. Install by message is skein #72.

## Build and test

Zig 0.16.0 (`mise.toml`). The SDK is a URL+hash dependency in
`build.zig.zon` (`shruggr/skein-sdk`, fetched by `zig build`).

```
zig build          # zig-out/bin/static.wasm
zig build bin      # the same, into bin/static.wasm
zig build test     # content types, paths, escapes refused, If-None-Match (natively)
```

skein runs this app end to end in its `kernel-zig/equiv/static.ts`. That
test clones this repo at a pinned commit, boots an instance from a tree
carrying `bin/static.wasm`, and drives it through the router: the index, nested
files, the 301, the 404s, the 405, HEAD, ETag/304, every request an entry,
and a replay.

MIT, as skein.
