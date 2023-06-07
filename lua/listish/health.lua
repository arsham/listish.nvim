local M = {}

local libs = {
  {
    name = "arshlib",
    lib = "arsham/arshlib.nvim",
    fn = vim.health.error,
  },
  {
    name = "nvim-treesitter.textobjects.repeatable_move",
    lib = "nvim-treesitter/nvim-treesitter-textobjects",
    fn = vim.health.warn,
  },
}

M.check = function()
  vim.health.start("Listish Health Check")
  for _, package in ipairs(libs) do
    if not pcall(require, package.name) then
      package.fn(package.lib .. " was not found", {
        'Please install "' .. package.lib .. '"',
      })
    else
      vim.health.ok(package.lib .. " is installed")
    end
  end
end

return M
