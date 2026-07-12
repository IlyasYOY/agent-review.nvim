local M = {}

local config = require "agent-review.config"
local registry = require "agent-review.registry"

local function notify(message)
    vim.notify("agent-review: " .. message, vim.log.levels.ERROR)
end

---@class AgentReviewSetup
---@field backend? "auto"|"dispatch"|"make"
---@field default_runner? string
---@field runners? table<string, AgentReviewRunner>

---@class AgentReviewRunner
---@field argv? string[]
---@field build? fun(ctx: table): table
---@field default_args? string[]
---@field compiler string
---@field require_args? boolean

function M.setup(opts)
    config.setup(opts)
    registry.reset(config.get().runners)
end

function M.register_runner(name, spec)
    registry.register(name, spec)
end

function M.runners()
    return registry.names()
end

function M.run(opts)
    opts = opts or {}
    if type(opts) ~= "table" then
        notify "run options must be a table"
        return false
    end
    local name = opts.runner or config.get().default_runner
    local args = opts.args or {}
    if type(args) ~= "table" then
        notify "args must be an argv list"
        return false
    end
    local cwd = opts.cwd or vim.fn.getcwd()
    local invocation, err = registry.build(name, args, cwd)
    if not invocation then
        notify(err)
        return false
    end
    return require("agent-review.backend").run(invocation, config.get().backend)
end

local function command_runner(fargs, fixed)
    local args = vim.deepcopy(fargs)
    local runner = fixed
    if not runner and registry.get(args[1]) then
        runner = table.remove(args, 1)
    end
    return M.run { runner = runner, args = args }
end

function M.complete(arglead, cmdline)
    local before_cursor = cmdline:sub(1, #cmdline - #arglead)
    local words = vim.split(vim.trim(before_cursor), "%s+")
    if #words > 1 then
        return {}
    end
    return vim.tbl_filter(function(name)
        return vim.startswith(name, arglead)
    end, registry.names())
end

function M.create_commands()
    vim.api.nvim_create_user_command("AgentReview", function(opts)
        command_runner(opts.fargs)
    end, {
        nargs = "*",
        complete = function(arglead, cmdline)
            return M.complete(arglead, cmdline)
        end,
        desc = "Run an agent code review and populate quickfix",
    })
    for command, runner in pairs {
        CodexReview = "codex",
        OpenCodeReview = "opencode",
    } do
        vim.api.nvim_create_user_command(command, function(opts)
            command_runner(opts.fargs, runner)
        end, {
            nargs = "*",
            desc = "Run " .. runner .. " review and populate quickfix",
        })
    end
end

M.setup()

return M
