local agent_review = require "agent-review"

describe("agent-review entrypoint", function()
    local original_executable
    local original_notify

    before_each(function()
        original_executable = vim.fn.executable
        original_notify = vim.notify
        agent_review.setup {}
    end)

    after_each(function()
        vim.fn.executable = original_executable
        vim.notify = original_notify
        pcall(vim.api.nvim_del_user_command, "Dispatch")
        agent_review.setup {}
    end)

    it("registers unified and compatibility commands at startup", function()
        local commands = vim.api.nvim_get_commands { builtin = false }
        assert.is_not_nil(commands.AgentReview)
        assert.is_not_nil(commands.CodexReview)
        assert.is_not_nil(commands.OpenCodeReview)
    end)

    it("lists and completes registered runners", function()
        agent_review.register_runner("custom", {
            argv = { "custom-review" },
            compiler = "make",
        })
        assert.same({ "codex", "custom", "opencode" }, agent_review.runners())
        assert.same({ "opencode" }, agent_review.complete("o", "AgentReview o"))
        assert.same({}, agent_review.complete("-", "AgentReview opencode -"))
    end)

    it("selects explicit runners and preserves command argv", function()
        local received = {}
        vim.fn.executable = function()
            return 1
        end
        vim.api.nvim_create_user_command("Dispatch", function(opts)
            received[#received + 1] = opts.args
        end, { nargs = "*" })
        agent_review.setup {
            backend = "dispatch",
            runners = {
                opencode = { default_args = { "--command", "review" } },
            },
        }

        vim.cmd "AgentReview opencode extra"
        vim.cmd "CodexReview --title a\\ b"

        assert.truthy(
            received[1]:find(
                "'opencode' 'run' '--command' 'review' 'extra'",
                1,
                true
            )
        )
        assert.truthy(received[2]:find("'--title' 'a b'", 1, true))
    end)

    it("returns false and notifies for invalid API input", function()
        local messages = {}
        vim.notify = function(message)
            messages[#messages + 1] = message
        end
        assert.is_false(agent_review.run "invalid")
        assert.is_false(agent_review.run { args = "invalid" })
        assert.truthy(messages[1]:find("options must be a table", 1, true))
        assert.truthy(messages[2]:find("args must be an argv list", 1, true))
    end)
end)
