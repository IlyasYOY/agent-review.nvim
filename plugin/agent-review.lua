if vim.g.loaded_agent_review then
    return
end
vim.g.loaded_agent_review = true

require("agent-review").create_commands()
