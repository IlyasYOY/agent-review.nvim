local agent_review = require "agent-review"

local function eq(expected, actual, message)
    if not vim.deep_equal(expected, actual) then
        error(
            (message or "values differ")
                .. "\nexpected: "
                .. vim.inspect(expected)
                .. "\nactual: "
                .. vim.inspect(actual),
            0
        )
    end
end

local function truthy(value, message)
    if not value then
        error(message or "expected a truthy value", 0)
    end
end

local function parse(compiler, lines)
    vim.cmd "unlet! current_compiler b:current_compiler"
    vim.cmd("compiler " .. compiler)
    return vim.fn.getqflist({
        lines = lines,
        efm = vim.bo.errorformat,
        items = 0,
    }).items
end

local function with_executable(callback)
    local original = vim.fn.executable
    vim.fn.executable = function()
        return 1
    end
    local ok, err = xpcall(callback, debug.traceback)
    vim.fn.executable = original
    if not ok then
        error(err, 0)
    end
end

local tests = {}

tests[#tests + 1] = {
    name = "registers unified and compatibility commands",
    run = function()
        local commands = vim.api.nvim_get_commands { builtin = false }
        truthy(commands.AgentReview)
        truthy(commands.CodexReview)
        truthy(commands.OpenCodeReview)
    end,
}

tests[#tests + 1] = {
    name = "selects default and explicit runners and preserves argv",
    run = function()
        local received = {}
        agent_review.setup {
            backend = "dispatch",
            default_runner = "codex",
            runners = {
                opencode = { default_args = { "--command", "review" } },
            },
        }
        pcall(vim.api.nvim_del_user_command, "Dispatch")
        vim.api.nvim_create_user_command("Dispatch", function(opts)
            received[#received + 1] = opts.args
        end, { nargs = "*" })
        with_executable(function()
            vim.cmd "AgentReview --base main"
            vim.cmd "AgentReview opencode extra"
            vim.cmd "CodexReview --title a\\ b"
        end)
        truthy(received[1]:find("'codex' 'review' '--base' 'main'", 1, true))
        truthy(
            received[2]:find(
                "'opencode' 'run' '--command' 'review' 'extra'",
                1,
                true
            )
        )
        truthy(received[3]:find("'--title' 'a b'", 1, true))
    end,
}

tests[#tests + 1] = {
    name = "escapes Ex placeholders at the Dispatch boundary",
    run = function()
        local received
        agent_review.setup { backend = "dispatch" }
        agent_review.register_runner("fixture", {
            argv = { "printf", "%s\\n", "a#b|c<d" },
            compiler = "opencodereview",
        })
        pcall(vim.api.nvim_del_user_command, "Dispatch")
        vim.api.nvim_create_user_command("Dispatch", function(opts)
            received = opts.args
        end, { nargs = "*" })
        with_executable(function()
            truthy(agent_review.run { runner = "fixture" })
        end)
        truthy(received:find("\\%s", 1, true))
        truthy(received:find("a\\#b\\|c\\<d", 1, true))
    end,
}

tests[#tests + 1] = {
    name = "registers custom runner builders",
    run = function()
        local received
        agent_review.setup { backend = "dispatch" }
        agent_review.register_runner("custom", {
            compiler = "opencodereview",
            build = function(ctx)
                return {
                    argv = { "custom-review", ctx.args[1] },
                    cwd = ctx.cwd,
                }
            end,
        })
        pcall(vim.api.nvim_del_user_command, "Dispatch")
        vim.api.nvim_create_user_command("Dispatch", function(opts)
            received = opts.args
        end, { nargs = "*" })
        with_executable(function()
            truthy(
                agent_review.run { runner = "custom", args = { "a b;$HOME" } }
            )
        end)
        truthy(received:find("'a b;$HOME'", 1, true))
    end,
}

tests[#tests + 1] = {
    name = "requires OpenCode instructions",
    run = function()
        agent_review.setup { backend = "make" }
        local messages = {}
        local original = vim.notify
        vim.notify = function(message)
            messages[#messages + 1] = message
        end
        eq(false, agent_review.run { runner = "opencode" })
        vim.notify = original
        truthy(messages[1]:find("requires review instructions", 1, true))
    end,
}

tests[#tests + 1] = {
    name = "reports missing executables and Dispatch",
    run = function()
        local messages = {}
        local original_notify = vim.notify
        local original_executable = vim.fn.executable
        vim.notify = function(message)
            messages[#messages + 1] = message
        end
        vim.fn.executable = function()
            return 0
        end
        agent_review.setup { backend = "dispatch" }
        eq(false, agent_review.run { runner = "codex" })
        vim.fn.executable = function()
            return 1
        end
        pcall(vim.api.nvim_del_user_command, "Dispatch")
        eq(false, agent_review.run { runner = "codex" })
        vim.fn.executable = original_executable
        vim.notify = original_notify
        truthy(messages[1]:find("was not found", 1, true))
        truthy(messages[2]:find(":Dispatch is unavailable", 1, true))
    end,
}

tests[#tests + 1] = {
    name = "make fallback restores compiler options",
    run = function()
        agent_review.setup { backend = "make" }
        local original_cmd = vim.cmd
        local commands = {}
        vim.bo.makeprg = "original"
        vim.bo.errorformat = "%f:%l:%m"
        vim.cmd = function(command)
            commands[#commands + 1] = command
        end
        with_executable(function()
            truthy(agent_review.run { runner = "codex" })
        end)
        vim.cmd = original_cmd
        eq("original", vim.bo.makeprg)
        eq("%f:%l:%m", vim.bo.errorformat)
        eq("compiler codexreview", commands[1])
        eq("silent make!", commands[2])
    end,
}

tests[#tests + 1] = {
    name = "make fallback executes argv and populates quickfix",
    run = function()
        agent_review.setup { backend = "make" }
        agent_review.register_runner("fixture", {
            argv = {
                "printf",
                "%s\\n",
                "lua/fallback.lua:7: warning: fallback works",
            },
            compiler = "opencodereview",
        })
        truthy(agent_review.run { runner = "fixture" })
        local items = vim.fn.getqflist()
        eq(1, #items)
        eq(7, items[1].lnum)
        eq("W", items[1].type)
        eq("fallback works", items[1].text)
        truthy(
            vim.api.nvim_buf_get_name(items[1].bufnr):match "lua/fallback.lua$"
        )
    end,
}

tests[#tests + 1] = {
    name = "parses OpenCode findings and ignores no findings",
    run = function()
        local items = parse("opencodereview", {
            "lua/example.lua:12: warning: unsafe branch",
            "  additional context",
            "README.md:3: info: missing documentation",
            "main.lua:9: error: invalid state",
        })
        eq(3, #items)
        truthy(
            vim.api.nvim_buf_get_name(items[1].bufnr):match "lua/example.lua$"
        )
        eq(12, items[1].lnum)
        eq("W", items[1].type)
        truthy(items[1].text:find("additional context", 1, true))
        eq("I", items[2].type)
        eq("E", items[3].type)
        eq({}, parse("opencodereview", { "NO FINDINGS" }))
    end,
}

tests[#tests + 1] = {
    name = "parses Codex priorities, ranges, and continuations",
    run = function()
        local items = parse("codexreview", {
            "- [P1] Avoid stale state — lua/example.lua:20-24",
            "  State survives the failed run",
            "- [P2] Check fallback — /tmp/project/init.lua:8",
        })
        eq(2, #items)
        truthy(
            vim.api.nvim_buf_get_name(items[1].bufnr):match "lua/example.lua$"
        )
        eq(1, items[1].nr)
        eq(20, items[1].lnum)
        eq(24, items[1].end_lnum)
        eq("W", items[1].type)
        truthy(items[1].text:find("State survives", 1, true))
        eq(2, items[2].nr)
        eq("/tmp/project/init.lua", vim.api.nvim_buf_get_name(items[2].bufnr))
        eq({}, parse("codexreview", { "NO FINDINGS" }))
    end,
}

return tests
