# agent-review.nvim Agent Guidelines

- Support Neovim 0.11 and newer.
- Keep argv structured until the Dispatch or `:make` shell boundary.
- `vim-dispatch` is optional; the fallback must use Neovim's `:make`.
- Keep result parsing compatible with both backends through compiler files.
- `make check` is the canonical formatting, lint, and test command.
- Do not commit or push unless the user explicitly asks.
