local backend = require "agent-review.backend"

local function parse(compiler, lines)
    vim.cmd "unlet! current_compiler b:current_compiler"
    vim.cmd("compiler " .. compiler)
    return vim.fn.getqflist({
        lines = lines,
        efm = vim.bo.errorformat,
        items = 0,
    }).items
end

describe("agent-review compiler integration", function()
    it("parses OpenCode findings and ignores clean output", function()
        local items = parse("opencodereview", {
            "lua/example.lua:12: warning: unsafe branch",
            "  additional context",
            "README.md:3: info: missing documentation",
            "main.lua:9: error: invalid state",
        })
        assert.equal(3, #items)
        assert.equal(12, items[1].lnum)
        assert.equal("W", items[1].type)
        assert.truthy(items[1].text:find("additional context", 1, true))
        assert.equal("I", items[2].type)
        assert.equal("E", items[3].type)
        assert.same({}, parse("opencodereview", { "NO FINDINGS" }))
    end)

    it("parses Codex priorities, ranges, and continuations", function()
        local items = parse("codexreview", {
            "- [P1] Avoid stale state — lua/example.lua:20-24",
            "  State survives the failed run",
            "- [P2] Check fallback — /tmp/project/init.lua:8",
        })
        assert.equal(2, #items)
        assert.equal(1, items[1].nr)
        assert.equal(20, items[1].lnum)
        assert.equal(24, items[1].end_lnum)
        assert.equal("W", items[1].type)
        assert.truthy(items[1].text:find("State survives", 1, true))
        assert.equal(2, items[2].nr)
        assert.equal(
            "/tmp/project/init.lua",
            vim.api.nvim_buf_get_name(items[2].bufnr)
        )
        assert.same({}, parse("codexreview", { "NO FINDINGS" }))
    end)

    it("populates quickfix through the real make fallback", function()
        local original_executable = vim.fn.executable
        vim.fn.executable = function()
            return 1
        end
        local ok, err = xpcall(function()
            assert.is_true(backend.run({
                argv = {
                    "printf",
                    "%s\\n",
                    "lua/fallback.lua:7: warning: fallback works",
                },
                compiler = "opencodereview",
            }, "make"))
        end, debug.traceback)
        vim.fn.executable = original_executable
        if not ok then
            error(err, 0)
        end

        local items = vim.fn.getqflist()
        assert.equal(1, #items)
        assert.equal(7, items[1].lnum)
        assert.equal("W", items[1].type)
        assert.equal("fallback works", items[1].text)
    end)
end)
