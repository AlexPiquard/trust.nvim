-- Isolate the trust state file for this run.
vim.env.XDG_STATE_HOME = vim.fn.stdpath("cache") .. "/trust_test_" .. vim.fn.getpid() .. "_" .. vim.fn.localtime()

local trust = require("trust")

local function mkdir(path)
  vim.fn.mkdir(path, "p")
  return path
end

-- Create a fake project (with a .git marker) and return its normalized root.
local function new_root(name)
  local dir = vim.env.XDG_STATE_HOME .. "/projects/" .. name
  mkdir(dir .. "/.git")
  return vim.fs.normalize(dir)
end

describe("trust", function()
  local cwd = vim.fn.getcwd()

  after_each(function()
    vim.fn.chdir(cwd)
  end)

  describe("root()", function()
    it("finds the project root from the cwd", function()
      local project = new_root("root_cwd")
      vim.fn.chdir(project)
      assert.equals(project, trust.root())
    end)

    it("finds the project root from a buffer", function()
      local project = new_root("root_buf")
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, project .. "/src/main.lua")

      assert.equals(project, trust.root(bufnr))

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("whitelist", function()
    it("is not trusted by default", function()
      assert.is_false(trust.is_trusted(new_root("wl_default")))
    end)

    it("trust() adds the root to the whitelist", function()
      local project = new_root("wl_trust")
      assert.equals(project, trust.trust(project))
      assert.is_true(trust.is_trusted(project))
    end)

    it("untrust() removes the root from the whitelist", function()
      local project = new_root("wl_untrust")
      trust.trust(project)

      assert.equals(project, trust.untrust(project))
      assert.is_false(trust.is_trusted(project))
    end)

    it("persists the whitelist on disk", function()
      local project = new_root("wl_persist")
      trust.trust(project)

      package.loaded.trust = nil
      local reloaded = require("trust")
      assert.is_true(reloaded.is_trusted(project))
    end)
  end)

  describe("setup_lsp()", function()
    local old_enable

    before_each(function()
      old_enable = vim.lsp.enable
    end)

    after_each(function()
      vim.lsp.enable = old_enable
    end)

    it("enables servers when the project is trusted", function()
      local enabled
      vim.lsp.enable = function(srvs)
        enabled = srvs
      end

      local project = new_root("lsp_trusted")
      trust.trust(project)
      vim.fn.chdir(project)

      trust.setup_lsp({ "lua_ls" })
      assert.same({ "lua_ls" }, enabled)
    end)

    it("does not enable servers for an untrusted project", function()
      local enabled = false
      vim.lsp.enable = function()
        enabled = true
      end

      local project = new_root("lsp_untrusted")
      vim.fn.chdir(project)

      trust.setup_lsp({ "lua_ls" })
      assert.is_false(enabled)
    end)
  end)

  describe("disable()", function()
    it("stops the clients attached to the given root", function()
      local project = new_root("stop")
      local stopped = {}

      local old_get_clients = vim.lsp.get_clients
      vim.lsp.get_clients = function()
        return {
          {
            config = { root_dir = project },
            stop = function()
              table.insert(stopped, project)
            end,
          },
        }
      end

      trust.disable(project)
      assert.same({ project }, stopped)

      vim.lsp.get_clients = old_get_clients
    end)
  end)
end)
