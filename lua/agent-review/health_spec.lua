local health = require "agent-review.health"

local function capture_health()
    local reports = {}
    local captured = {}
    for _, level in ipairs { "start", "ok", "warn", "error", "info" } do
        captured[level] = function(message, advice)
            reports[#reports + 1] = {
                level = level,
                message = message,
                advice = advice,
            }
        end
    end
    return captured, reports
end

local function has_report(reports, level, fragment)
    for _, report in ipairs(reports) do
        if report.level == level and report.message:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

describe("agent-review health", function()
    local original_executable
    local original_health

    before_each(function()
        original_executable = vim.fn.executable
        original_health = vim.health
    end)

    after_each(function()
        vim.fn.executable = original_executable
        vim.health = original_health
    end)

    it("reports core runtime and commands", function()
        local captured, reports = capture_health()
        vim.health = captured
        vim.fn.executable = function()
            return 1
        end

        health.check()

        assert.truthy(has_report(reports, "start", "agent-review.nvim"))
        assert.truthy(has_report(reports, "ok", "Neovim 0.11"))
        assert.truthy(has_report(reports, "ok", ":AgentReview"))
        assert.truthy(has_report(reports, "ok", "codex is executable"))
    end)

    it("treats optional tools as informational", function()
        local captured, reports = capture_health()
        vim.health = captured
        vim.fn.executable = function()
            return 0
        end

        health.check()

        assert.truthy(has_report(reports, "info", "codex is not installed"))
        assert.truthy(has_report(reports, "info", "opencode is not installed"))
        assert.truthy(
            has_report(reports, "info", "vim-dispatch is not installed")
        )
    end)
end)
