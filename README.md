# agent-review.nvim

`agent-review.nvim` runs agent CLI code reviews and turns their diagnostics into
Neovim quickfix entries. Codex and OpenCode are built in, runners are
extensible, and [vim-dispatch](https://github.com/tpope/vim-dispatch) is used
when available. Without it, the plugin falls back to Neovim's `:make`.

The plugin provides execution and parsing only. It does not ship review prompts
or depend on personal Codex/OpenCode configuration.

## Requirements

- Neovim 0.11 or newer
- `codex` and/or `opencode` for the corresponding runner
- `vim-dispatch` is optional

Run `:checkhealth agent-review` after installation. The health provider checks
the Neovim version, startup commands, optional review CLIs, and optional
vim-dispatch integration without turning missing optional tools into load
errors.

## Installation

With Neovim 0.12 or newer, use the built-in `vim.pack`:

```lua
vim.pack.add {
    { src = "https://github.com/IlyasYOY/agent-review.nvim" },
}
```

Neovim 0.11 users should install the plugin with lazy.nvim or another package
manager.

With lazy.nvim:

```lua
{
    "IlyasYOY/agent-review.nvim",
    config = function()
        require("agent-review").setup {}
    end,
}
```

The plugin has no required Lua dependencies and registers its commands when
loaded. Calling `setup()` is optional.

## Configuration

```lua
require("agent-review").setup {
    default_runner = "codex",
    backend = "auto", -- "auto", "dispatch", or "make"
    runners = {
        -- OpenCode has no native review command. Configure your own command or
        -- pass a message on every invocation.
        opencode = {
            default_args = { "--command", "review" },
        },
    },
}
```

`auto` uses `:Dispatch` when vim-dispatch is loaded and otherwise uses
`silent make!`. An explicitly selected unavailable backend reports an error.

## Commands

| Command | Description |
| --- | --- |
| `:AgentReview [runner] [args...]` | Run an explicit runner or the configured default. |
| `:CodexReview [args...]` | Compatibility alias for the Codex runner. |
| `:OpenCodeReview [args...]` | Compatibility alias for the OpenCode runner. |

Examples:

```vim
:AgentReview
:AgentReview codex --base main
:CodexReview --uncommitted
:OpenCodeReview --command review
:OpenCodeReview Review the current changes
```

Command arguments become separate argv entries. Escape spaces using normal Ex
syntax, for example `:CodexReview --title my\ change`. The Lua API is preferred
when an argument itself contains whitespace:

```lua
require("agent-review").run {
    runner = "codex",
    args = { "--title", "my change" },
    cwd = vim.fn.getcwd(),
}
```

OpenCode refuses to run without invocation arguments or configured
`default_args`, because `opencode run` otherwise has no review instruction.

## Diagnostic formats

The OpenCode compiler accepts one finding per line:

```text
path:line: warning: message
path:line: info: message
path:line: error: message
```

Instruct the selected OpenCode prompt/command to print `NO FINDINGS` when the
review is clean. Two-space-indented lines continue the preceding finding.

The Codex compiler parses Codex's native `[P<n>]` review findings, line ranges,
and multiline details. Codex priorities are stored in the quickfix `nr` field;
findings use quickfix type `W`.

Repository-level findings must be anchored to the most relevant `path:line`.
Unmatched CLI chatter and `NO FINDINGS` do not create quickfix entries.

## Custom runners

Configure runners in `setup()` or register them later:

```lua
require("agent-review").register_runner("custom", {
    argv = { "custom-review", "--format", "quickfix" },
    compiler = "customreview",
    default_args = { "--changed" },
})
```

`argv` is the fixed command prefix, followed by `default_args` and invocation
arguments. For dynamic commands, use `build(ctx)` and return
`{ argv = {...}, cwd = "...", compiler = "..." }`. The context contains
`name`, `args`, and `cwd`.

Result formats use standard Neovim compiler files. Add
`compiler/customreview.vim` to your config or plugin and reference it from the
runner. This keeps the same parser in Dispatch and `:make` modes.

## Lua API

- `setup(opts)` replaces the default backend, runner, and runner overrides.
- `run({ runner?, args?, cwd? })` resolves and executes a structured
  invocation, returning whether the backend launched it.
- `register_runner(name, spec)` registers or replaces an extensible runner.
- `runners()` returns sorted registered runner names.

See `:help agent-review` for the full command, setup, runner, and diagnostic
reference.

## Development

```sh
make check
make test NVIM_VERSION=v0.11.7
make test NVIM_VERSION=v0.12.5
make test NVIM_VERSION=nightly
```

`make check` runs non-mutating StyLua and Luacheck checks, isolated headless
Neovim specs, and Vim help/tag validation.

## License

MIT. See [LICENSE](./LICENSE).
