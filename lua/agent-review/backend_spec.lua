local backend = require "agent-review.backend"

describe("agent-review backend", function()
    local original_cmd
    local original_executable
    local original_notify

    before_each(function()
        original_cmd = vim.cmd
        original_executable = vim.fn.executable
        original_notify = vim.notify
    end)

    after_each(function()
        vim.cmd = original_cmd
        vim.fn.executable = original_executable
        vim.notify = original_notify
        pcall(vim.api.nvim_del_user_command, "Dispatch")
    end)

    it("shell-escapes every argv element", function()
        assert.equal(
            "'review' 'a b' '$HOME;true'",
            backend.shell_join { "review", "a b", "$HOME;true" }
        )
    end)

    it("validates invocations before crossing a shell boundary", function()
        local messages = {}
        vim.notify = function(message)
            messages[#messages + 1] = message
        end
        assert.is_false(backend.run({ argv = {}, compiler = "make" }, "make"))
        assert.is_false(backend.run({
            argv = { "review", "bad\narg" },
            compiler = "make",
        }, "make"))
        assert.is_false(backend.run({
            argv = { "review" },
            compiler = "bad compiler",
        }, "make"))
        assert.truthy(messages[1]:find("empty argv", 1, true))
        assert.truthy(messages[2]:find("must not contain newlines", 1, true))
        assert.truthy(messages[3]:find("compiler", 1, true))
    end)

    it("reports a missing executable", function()
        local message
        vim.notify = function(value)
            message = value
        end
        vim.fn.executable = function()
            return 0
        end
        assert.is_false(backend.run({
            argv = { "missing-review" },
            compiler = "make",
        }, "make"))
        assert.truthy(message:find("was not found", 1, true))
    end)

    it("builds an escaped Dispatch command", function()
        local received
        vim.fn.executable = function()
            return 1
        end
        vim.api.nvim_create_user_command("Dispatch", function(opts)
            received = opts.args
        end, { nargs = "*" })

        assert.is_true(backend.run({
            argv = { "review", "%s", "a#b|c<d", "a b;$HOME" },
            cwd = vim.fn.getcwd() .. "/project with spaces",
            compiler = "opencodereview",
        }, "dispatch"))

        assert.truthy(received:find("-compiler=opencodereview", 1, true))
        assert.truthy(received:find("-dir=", 1, true))
        assert.truthy(received:find("\\%s", 1, true))
        assert.truthy(received:find("a\\#b\\|c\\<d", 1, true))
        assert.truthy(received:find("'a b;$HOME'", 1, true))
    end)

    it("reports an explicitly unavailable Dispatch backend", function()
        local message
        vim.fn.executable = function()
            return 1
        end
        vim.notify = function(value)
            message = value
        end
        assert.is_false(backend.run({
            argv = { "review" },
            compiler = "make",
        }, "dispatch"))
        assert.truthy(message:find(":Dispatch is unavailable", 1, true))
    end)

    it("restores compiler options after the make fallback", function()
        local commands = {}
        vim.fn.executable = function()
            return 1
        end
        vim.bo.makeprg = "original"
        vim.bo.errorformat = "%f:%l:%m"
        vim.b.current_compiler = "original"
        vim.cmd = function(command)
            commands[#commands + 1] = command
        end

        assert.is_true(backend.run({
            argv = { "review", "a b" },
            compiler = "make",
        }, "make"))

        assert.equal("original", vim.bo.makeprg)
        assert.equal("%f:%l:%m", vim.bo.errorformat)
        assert.equal("original", vim.b.current_compiler)
        assert.same({ "compiler make", "silent make!" }, commands)
    end)
end)
