local M = {}

local defaults = {
    backend = "auto",
    default_runner = "codex",
    runners = {},
}

local values = vim.deepcopy(defaults)

local function validate(opts)
    if type(opts) ~= "table" then
        error("agent-review: setup options must be a table", 0)
    end
    if
        opts.backend ~= nil
        and opts.backend ~= "auto"
        and opts.backend ~= "dispatch"
        and opts.backend ~= "make"
    then
        error("agent-review: backend must be 'auto', 'dispatch', or 'make'", 0)
    end
    if
        opts.default_runner ~= nil
        and (type(opts.default_runner) ~= "string" or opts.default_runner == "")
    then
        error("agent-review: default_runner must be a non-empty string", 0)
    end
    if opts.runners ~= nil and type(opts.runners) ~= "table" then
        error("agent-review: runners must be a table", 0)
    end
end

function M.setup(opts)
    opts = opts or {}
    validate(opts)
    values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
end

function M.get()
    return values
end

return M
