local M = {}

local function notify(message)
    vim.notify("agent-review: " .. message, vim.log.levels.ERROR)
end

local function validate(invocation)
    if type(invocation.argv) ~= "table" or #invocation.argv == 0 then
        return nil, "runner returned an empty argv list"
    end
    for index, value in ipairs(invocation.argv) do
        if type(value) ~= "string" or value == "" then
            return nil, "argv[" .. index .. "] must be a non-empty string"
        end
        if value:find "[\r\n]" then
            return nil, "argv[" .. index .. "] must not contain newlines"
        end
    end
    if
        type(invocation.compiler) ~= "string"
        or not invocation.compiler:match "^[%w_.-]+$"
    then
        return nil, "compiler contains unsupported characters"
    end
    if
        invocation.cwd ~= nil
        and (type(invocation.cwd) ~= "string" or invocation.cwd == "")
    then
        return nil, "cwd must be a non-empty string"
    end
    if vim.fn.executable(invocation.argv[1]) ~= 1 then
        return nil, "executable '" .. invocation.argv[1] .. "' was not found"
    end
    return invocation
end

function M.shell_join(argv)
    return table.concat(
        vim.tbl_map(function(value)
            return vim.fn.shellescape(value)
        end, argv),
        " "
    )
end

local function dispatch(invocation)
    local parts = { "-compiler=" .. invocation.compiler }
    if invocation.cwd and invocation.cwd ~= vim.fn.getcwd() then
        parts[#parts + 1] = "-dir=" .. vim.fn.fnameescape(invocation.cwd)
    end
    parts[#parts + 1] = vim.fn.escape(M.shell_join(invocation.argv), "%#<|")
    local ok, err = pcall(vim.cmd, "Dispatch " .. table.concat(parts, " "))
    if not ok then
        notify("Dispatch failed: " .. tostring(err))
        return false
    end
    return true
end

local function make(invocation)
    local bufnr = vim.api.nvim_get_current_buf()
    local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
        local saved = {
            makeprg = vim.bo.makeprg,
            errorformat = vim.bo.errorformat,
            current_compiler = vim.b.current_compiler,
        }
        local run_ok, run_err = xpcall(function()
            vim.cmd("compiler " .. invocation.compiler)
            local command = vim.fn.escape(M.shell_join(invocation.argv), "%#<")
            if invocation.cwd and invocation.cwd ~= vim.fn.getcwd() then
                command = "cd "
                    .. vim.fn.shellescape(invocation.cwd)
                    .. " && "
                    .. command
            end
            vim.bo.makeprg = command
            vim.cmd "silent make!"
        end, debug.traceback)
        vim.bo.makeprg = saved.makeprg
        vim.bo.errorformat = saved.errorformat
        vim.b.current_compiler = saved.current_compiler
        if not run_ok then
            error(run_err, 0)
        end
    end)
    if not ok then
        notify(":make fallback failed: " .. tostring(err))
        return false
    end
    return true
end

function M.run(raw, requested)
    local invocation, err = validate(raw)
    if not invocation then
        notify(err)
        return false
    end
    local backend = requested
    if backend == "auto" then
        backend = vim.fn.exists ":Dispatch" == 2 and "dispatch" or "make"
    end
    if backend == "dispatch" and vim.fn.exists ":Dispatch" ~= 2 then
        notify "backend is 'dispatch', but :Dispatch is unavailable"
        return false
    end
    if backend == "dispatch" then
        return dispatch(invocation)
    end
    return make(invocation)
end

return M
