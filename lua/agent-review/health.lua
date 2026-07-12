local M = {}

local commands = {
    "AgentReview",
    "CodexReview",
    "OpenCodeReview",
}

local function check_command(name)
    local available = vim.api.nvim_get_commands({ builtin = false })[name]
        ~= nil
    if available then
        vim.health.ok(":" .. name .. " is registered")
    else
        vim.health.error(":" .. name .. " is not registered")
    end
end

local function check_executable(name)
    if vim.fn.executable(name) == 1 then
        vim.health.ok(name .. " is executable")
    else
        vim.health.info(
            name .. " is not installed; its review runner is unavailable"
        )
    end
end

function M.check()
    vim.health.start "agent-review.nvim"

    if vim.fn.has "nvim-0.11" == 1 then
        vim.health.ok "Neovim 0.11 or newer is available"
    else
        vim.health.error "agent-review.nvim requires Neovim 0.11 or newer"
    end

    local loaded, module = pcall(require, "agent-review")
    if loaded and type(module.run) == "function" then
        vim.health.ok "agent-review.nvim is available"
    else
        vim.health.error(
            "agent-review.nvim could not be loaded",
            loaded and nil or tostring(module)
        )
    end

    for _, name in ipairs(commands) do
        check_command(name)
    end

    check_executable "codex"
    check_executable "opencode"

    if vim.fn.exists ":Dispatch" == 2 then
        vim.health.ok "vim-dispatch is available"
    else
        vim.health.info "vim-dispatch is not installed; the auto backend will use :make"
    end
end

return M
