local M = {}
local health = require("health")

M.check = function()
  health.report_start("Listish Health Check")
  if not pcall(require, "arshlib") then
    health.report_error("arshlib.nvim was not found", {
      'Please install "arsham/arshlib.nvim"',
    })
  else
    health.report_ok("arshlib.nvim is installed")
  end

  if not pcall(require, "nvim") then
    health.report_error("nvim.lua was not found", {
      'Please install "norcalli/nvim.lua"',
    })
  else
    health.report_ok("nvim.lua is installed")
  end
end

return M
