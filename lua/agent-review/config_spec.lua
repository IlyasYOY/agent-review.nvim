local config = require "agent-review.config"

describe("agent-review config", function()
    after_each(function()
        config.setup {}
    end)

    it("provides stable defaults", function()
        config.setup {}
        assert.same({
            backend = "auto",
            default_runner = "codex",
            runners = {},
        }, config.get())
    end)

    it("stores configured runners", function()
        local opts = {
            backend = "make",
            default_runner = "custom",
            runners = {
                custom = {
                    argv = { "review" },
                    compiler = "make",
                },
            },
        }
        config.setup(opts)
        assert.equal("review", config.get().runners.custom.argv[1])
    end)

    it("rejects invalid setup options", function()
        assert.has_error(function()
            config.setup "invalid"
        end, "options must be a table")
        assert.has_error(function()
            config.setup { backend = "invalid" }
        end, "backend must be")
        assert.has_error(function()
            config.setup { default_runner = "" }
        end, "default_runner")
        assert.has_error(function()
            config.setup { runners = false }
        end, "runners must be a table")
    end)
end)
