vim.api.nvim_create_user_command("Trust", function()
  local root = require("trust").trust()
  vim.notify(("Trusted project: %s"):format(root), vim.log.levels.INFO)
end, { desc = "Trust current project and enable LSP" })

vim.api.nvim_create_user_command("Untrust", function()
  local root = require("trust").untrust()
  vim.notify(("Removed trust for: %s"):format(root), vim.log.levels.INFO)
end, { desc = "Untrust current project and stop LSP" })
