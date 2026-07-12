local M = {}

local runners = {}

local function validate_argv(argv, field)
    if type(argv) ~= "table" or #argv == 0 then
        error("agent-review: " .. field .. " must be a non-empty argv list", 0)
    end
    for index, value in ipairs(argv) do
        if type(value) ~= "string" or value == "" then
            error(
                "agent-review: "
                    .. field
                    .. "["
                    .. index
                    .. "] must be a non-empty string",
                0
            )
        end
    end
end

local function validate(name, spec)
    if type(name) ~= "string" or not name:match "^[%w_.-]+$" then
        error("agent-review: runner name contains unsupported characters", 0)
    end
    if type(spec) ~= "table" then
        error("agent-review: runner '" .. name .. "' must be a table", 0)
    end
    if type(spec.build) ~= "function" then
        validate_argv(spec.argv, "runner '" .. name .. "'.argv")
    end
    if spec.default_args ~= nil then
        if type(spec.default_args) ~= "table" then
            error(
                "agent-review: runner '"
                    .. name
                    .. "'.default_args must be an argv list",
                0
            )
        end
        for index, value in ipairs(spec.default_args) do
            if type(value) ~= "string" or value == "" then
                error(
                    "agent-review: runner '"
                        .. name
                        .. "'.default_args["
                        .. index
                        .. "] must be a non-empty string",
                    0
                )
            end
        end
    end
    if
        type(spec.compiler) ~= "string"
        or not spec.compiler:match "^[%w_.-]+$"
    then
        error(
            "agent-review: runner '"
                .. name
                .. "'.compiler contains unsupported characters",
            0
        )
    end
    if spec.require_args ~= nil and type(spec.require_args) ~= "boolean" then
        error(
            "agent-review: runner '" .. name .. "'.require_args must be boolean",
            0
        )
    end
end

function M.reset(overrides)
    runners = {
        codex = {
            argv = { "codex", "review" },
            compiler = "codexreview",
        },
        opencode = {
            argv = { "opencode", "run" },
            compiler = "opencodereview",
            require_args = true,
        },
    }
    for name, override in pairs(overrides or {}) do
        local base = runners[name] or {}
        runners[name] = vim.tbl_extend("force", vim.deepcopy(base), override)
    end
    for name, spec in pairs(runners) do
        validate(name, spec)
    end
end

function M.register(name, spec)
    validate(name, spec)
    runners[name] = vim.deepcopy(spec)
end

function M.get(name)
    return runners[name]
end

function M.names()
    local names = vim.tbl_keys(runners)
    table.sort(names)
    return names
end

function M.build(name, args, cwd)
    local spec = runners[name]
    if not spec then
        return nil, "unknown runner '" .. name .. "'"
    end
    args = args or {}
    local configured = spec.default_args or {}
    if spec.require_args and #configured == 0 and #args == 0 then
        return nil,
            "runner '"
                .. name
                .. "' requires review instructions in command arguments or default_args"
    end
    local ctx = {
        args = vim.deepcopy(args),
        cwd = cwd,
        default_args = vim.deepcopy(configured),
        name = name,
    }
    local invocation
    if spec.build then
        local ok, value = pcall(spec.build, ctx)
        if not ok then
            return nil, "runner '" .. name .. "' failed: " .. tostring(value)
        end
        invocation = value
    else
        invocation = {
            argv = vim.deepcopy(spec.argv),
            cwd = cwd,
            compiler = spec.compiler,
        }
        vim.list_extend(invocation.argv, vim.deepcopy(configured))
        vim.list_extend(invocation.argv, vim.deepcopy(args))
    end
    if type(invocation) ~= "table" then
        return nil, "runner '" .. name .. "' must return an invocation table"
    end
    invocation.compiler = invocation.compiler or spec.compiler
    invocation.cwd = invocation.cwd or cwd
    return invocation
end

return M
