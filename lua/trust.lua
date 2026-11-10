---@class Trust
local M = {}

local state_file = vim.fn.stdpath("state") .. "/trusted_projects.json"

local root_markers = {
  ".git",
  ".hg",
  ".svn",
  "Cargo.toml",
  "go.mod",
  "package.json",
  "pyproject.toml",
  "composer.json",
  "Gemfile",
  "Makefile",
  "meson.build",
}

---@type string[] Servers to enable
local servers = {}
---@type boolean[] Notified paths
local notified = {}

local function normalize(path)
  return vim.fs.normalize(path)
end

local function read_whitelist()
  local file = io.open(state_file, "r")
  if not file then
    return {}
  end

  local content = file:read("*a")
  file:close()

  local ok, list = pcall(vim.json.decode, content)
  if not ok or type(list) ~= "table" then
    return {}
  end

  local trusted = {}
  for _, path in ipairs(list) do
    if type(path) == "string" then
      trusted[normalize(path)] = true
    end
  end

  return trusted
end

local function write_whitelist(trusted)
  local list = vim.tbl_keys(trusted)
  table.sort(list)

  vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")

  local file = io.open(state_file, "w")
  if not file then
    vim.notify(("Cannot write trust file: %s"):format(state_file), vim.log.levels.WARN)
    return
  end

  file:write(vim.json.encode(list))
  file:close()
end

function M.root(bufnr)
  bufnr = bufnr or 0

  local name = vim.api.nvim_buf_get_name(bufnr)
  local start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()

  return normalize(vim.fs.root(start, root_markers) or start)
end

---@param root? string The root path of the project
function M.is_trusted(root)
  root = normalize(root or M.root())
  return read_whitelist()[root] == true
end

local function notify_untrusted(root)
  root = normalize(root or M.root())
  if notified[root] then
    return
  end

  notified[root] = true
  vim.schedule(function()
    vim.notify(("LSP disabled: %s is not trusted. Run :Trust to enable it."):format(root), vim.log.levels.WARN)
  end)
end

function M.enable()
  vim.lsp.enable(servers)
end

---@param root? string The root path of the project
function M.disable(root)
  root = normalize(root or M.root())
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.config.root_dir and normalize(client.config.root_dir) == root then
      client:stop()
    end
  end
end

---@param srvs string[] Enabled servers
function M.setup_lsp(srvs)
  servers = srvs

  local root = M.root()
  if M.is_trusted(root) then
    M.enable()
  else
    notify_untrusted(root)
  end
end

---@param root? string The root path of the project
function M.trust(root)
  root = normalize(root or M.root())

  local trusted = read_whitelist()
  trusted[root] = true
  write_whitelist(trusted)

  notified[root] = nil
  M.enable()

  return root
end

---@param root? string The root path of the project
function M.untrust(root)
  root = normalize(root or M.root())

  local trusted = read_whitelist()
  trusted[root] = nil
  write_whitelist(trusted)

  notified[root] = nil
  M.disable(root)

  return root
end

local lsp_start = vim.lsp.start
vim.lsp.start = function(config, opts)
  local bufnr = opts and opts.bufnr or 0

  if not M.is_trusted(M.root(bufnr)) then
    notify_untrusted(M.root(bufnr))
    return
  end

  return lsp_start(config, opts)
end

local lsp_start_client = vim.lsp.start_client
if lsp_start_client then
  vim.lsp.start_client = function(config)
    if not M.is_trusted(M.root()) then
      notify_untrusted(M.root())
      return
    end

    return lsp_start_client(config)
  end
end

function M.setup() end

return M
