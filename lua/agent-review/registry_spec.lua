local registry = require "agent-review.registry"

describe("agent-review runner registry", function()
    before_each(function()
        registry.reset()
    end)

    after_each(function()
        registry.reset()
    end)

    it("provides sorted built-in runners", function()
        assert.same({ "codex", "opencode" }, registry.names())
        assert.same(
            { "codex", "review" },
            registry.build("codex", nil, "/project").argv
        )
    end)

    it("merges runner overrides and invocation arguments", function()
        registry.reset {
            opencode = {
                default_args = { "--command", "review" },
            },
        }
        local invocation =
            registry.build("opencode", { "--model", "test" }, "/project")
        assert.same({
            "opencode",
            "run",
            "--command",
            "review",
            "--model",
            "test",
        }, invocation.argv)
        assert.equal("/project", invocation.cwd)
        assert.equal("opencodereview", invocation.compiler)
    end)

    it("requires OpenCode review instructions", function()
        local invocation, err = registry.build("opencode", {}, "/project")
        assert.is_nil(invocation)
        assert.truthy(err:find("requires review instructions", 1, true))
    end)

    it("registers and copies custom runners", function()
        local spec = {
            argv = { "custom-review" },
            compiler = "make",
        }
        registry.register("custom", spec)
        spec.argv[1] = "changed"
        assert.equal("custom-review", registry.get("custom").argv[1])
    end)

    it("supports dynamic builders with a structured context", function()
        local received
        registry.register("dynamic", {
            compiler = "make",
            default_args = { "--default" },
            build = function(ctx)
                received = ctx
                return { argv = { "dynamic", ctx.args[1] } }
            end,
        })
        local invocation = registry.build("dynamic", { "a b" }, "/project")
        assert.same({
            name = "dynamic",
            args = { "a b" },
            default_args = { "--default" },
            cwd = "/project",
        }, received)
        assert.same({ "dynamic", "a b" }, invocation.argv)
        assert.equal("make", invocation.compiler)
        assert.equal("/project", invocation.cwd)
    end)

    it("reports unknown and failing dynamic runners", function()
        local invocation, err = registry.build("missing", {}, "/project")
        assert.is_nil(invocation)
        assert.truthy(err:find("unknown runner", 1, true))

        registry.register("broken", {
            compiler = "make",
            build = function()
                error "builder failed"
            end,
        })
        invocation, err = registry.build("broken", {}, "/project")
        assert.is_nil(invocation)
        assert.truthy(err:find("builder failed", 1, true))
    end)

    it("validates runner schemas", function()
        assert.has_error(function()
            registry.register("bad name", {})
        end, "unsupported characters")
        assert.has_error(function()
            registry.register("missing-argv", { compiler = "make" })
        end, "non-empty argv")
        assert.has_error(function()
            registry.register("bad-compiler", {
                argv = { "review" },
                compiler = "bad compiler",
            })
        end, "compiler")
        assert.has_error(function()
            registry.register("bad-args", {
                argv = { "review" },
                compiler = "make",
                default_args = { "" },
            })
        end, "non-empty string")
    end)
end)
