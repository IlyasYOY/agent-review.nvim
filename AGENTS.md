# agent-review.nvim Agent Guidelines

## Project shape

- Support Neovim 0.11 and newer.
- Runtime Lua lives under `lua/agent-review/`; startup command registration
  lives in `plugin/agent-review.lua`.
- Compiler definitions in `compiler/` are public parsing contracts shared by
  Dispatch and the `:make` fallback.
- Unit specs are colocated with modules as `*_spec.lua`. Compiler and
  end-to-end integration specs stay under `tests/`.
- Public commands are `:AgentReview`, `:CodexReview`, and
  `:OpenCodeReview`.

## Runtime contracts

- Keep argv as a list until the Dispatch or `:make` shell boundary. Escape
  every argv item there; never accept raw shell command strings.
- Keep `vim-dispatch` optional. The `auto` backend must fall back to
  Neovim's `:make`; explicitly requesting unavailable Dispatch reports an
  error.
- Preserve runner schemas, command names, setup fields, completion behavior,
  and Lua return values.
- Preserve Codex and OpenCode quickfix parsing, including multiline findings,
  Codex priority/range fields, and `NO FINDINGS`.
- Optional CLIs and vim-dispatch must not cause load-time failures.

## Development

- `make check` is the canonical non-mutating format, lint, help, and test
  command.
- `make test` runs the isolated suite with the local Neovim.
- Before compatibility work is complete, run:
  - `make test NVIM_VERSION=v0.11.7`
  - `make test NVIM_VERSION=v0.12.5`
  - `make test NVIM_VERSION=nightly` as a compatibility probe
- Run one spec with:
  `nvim --headless --noplugin -i NONE -n -u tests/minimal_init.lua -c 'lua require("tests.runner").run({ files = { "lua/agent-review/config_spec.lua" }, verbose = true })' -c qa`.
- Tests must use the isolated XDG directories and ignored `.test-home` or
  `.test-work` paths, never the user's real state.

## Style and documentation

- StyLua uses 4 spaces, 80 columns, Unix line endings, preferred double quotes,
  and omitted call parentheses where supported.
- Luacheck and LuaLS settings live at the repository root.
- Update `README.md`, `doc/agent-review.txt`, and tracked `doc/tags` when
  public behavior changes.
- Add or update `lua/agent-review/health.lua` coverage when requirements or
  optional integrations change.

## Repository safety

- Do not commit, push, tag, publish, or dispatch a release unless the user
  explicitly asks.
- Preserve unrelated user changes and keep generated test state ignored.
