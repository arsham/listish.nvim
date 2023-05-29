local M = {}

local libs = {
  arshlib = "arsham/arshlib.nvim",
}

M.check = function()
  vim.health.start("Listish Health Check")
  for name, package in pairs(libs) do
    if not pcall(require, name) then
      vim.health.error(package .. " was not found", {
        'Please install "' .. package .. '"',
      })
    else
      vim.health.ok(package .. " is installed")
    end
  end
end

return M
