local M = {}

---@type Extmarks
M.extmarks = { -- {{{
  unique_id = "Z",
  group = vim.api.nvim_create_augroup("LISTISH_AUTOCMDS", { clear = true }),
  ns = vim.api.nvim_create_namespace("listish-ns"),
  listener_name = "listish_autocmd_listener",
  sign_group = "listish_sign_group",
  qf_sign_hl = { fg = "#8a62c6", bg = "#2A2D30" },
  qf_ext_hl = { fg = "#8a62c6" },
  local_sign_hl = { fg = "#b5854a", bg = "#2A2D30" },
  local_ext_hl = { fg = "#b5854a" },

  set_signs = false,
  qf_sigil = "",
  qf_sign_hl_group = "ListishQfSign",
  local_sign_hl_group = "ListishLocalSign",
  local_sigil = "",
  priority = 1,

  set_extmarks = false,
  qf_badge = " Quickfix Note",
  qf_ext_hl_group = "ListishQfExt",
  local_badge = " Locallist Note",
  local_ext_hl_group = "ListishLocalExt",
} -- }}}

---Checks a variable is set on the buffer. If so, it returns truw, otherwise
-- it will set it and returns -false.
---@param bufnr number
---@return boolean
local function buf_autocmd_is_set(bufnr) --{{{
  local ok, _ = pcall(vim.api.nvim_buf_get_var, bufnr, M.extmarks.listener_name)
  if ok then
    return true
  end
  vim.api.nvim_buf_set_var(bufnr, M.extmarks.listener_name, true)
  return false
end --}}}

---For each item in the items list, it creates an extmark.
---@param items ListItem[]
---@param is_local boolean specifies what extmark text and colour to use.
function M.insert_extmarks(items, is_local) -- {{{
  local badge = M.extmarks.qf_badge
  local hl_group = M.extmarks.qf_ext_hl_group
  if is_local then
    badge = M.extmarks.local_badge
    hl_group = M.extmarks.local_ext_hl_group
  end

  local opts = {
    virt_text = { { badge, hl_group } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  }
  for _, item in ipairs(items) do
    if item.type == M.extmarks.unique_id then
      local line = vim.api.nvim_buf_get_lines(item.bufnr, item.lnum - 1, item.lnum, false)
      opts.virt_text[1][1] = line[1] == item.text and badge or item.text
    end
    vim.api.nvim_buf_set_extmark(item.bufnr, M.extmarks.ns, item.lnum - 1, item.col - 1, opts)
  end
end -- }}}

---Return only valid and loaded buffer handles.
---@return number[]
local function buffer_list() -- {{{
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      table.insert(buffers, buf)
    end
  end
  return buffers
end -- }}}

---Merges both lists and returns the new merged list.
---@param list1 ListItem[]
---@param list2 ListItem[]
---@return ListItem[]
local function merge_list(list1, list2) -- {{{
  for i = 1, #list2 do
    list1[#list1 + 1] = list2[i]
  end
  return list1
end -- }}}

---Updates all the extmarks based on the qflist and locallist values. We don't
---have a mechanism to detect item removeal, therefore it has to clear the
---extmarks and add them again on all buffers.
function M.update_extmarks() -- {{{
  local buffers = buffer_list()
  for _, buf in ipairs(buffers) do
    vim.api.nvim_buf_clear_namespace(buf, M.extmarks.ns, 0, -1)
  end

  local locallist = {}
  for _, buf in ipairs(buffers) do
    local list = vim.fn.getloclist(buf)
    if #list > 0 then
      locallist = merge_list(locallist, list)
    end
  end
  local qflist = vim.fn.getqflist()
  -- Bail early.
  if #locallist + #qflist == 0 then
    return
  end

  if #qflist > 0 then
    M.insert_extmarks(qflist, false)
  end

  local items = {}
  if #locallist > 0 then
    for _, item in ipairs(locallist) do
      if item.type == M.extmarks.unique_id then
        table.insert(items, item)
      end
    end
    M.insert_extmarks(items, true)
  end
end -- }}}

---For each item in the items list, it creates a sign.
---@param items ListItem[]
---@param is_local boolean specifies the highlight group
function M.insert_signs(items, is_local) -- {{{
  local sigil = M.extmarks.qf_sigil
  if is_local then
    sigil = M.extmarks.local_sigil
  end

  for _, item in ipairs(items) do
    vim.fn.sign_place(
      0,
      M.extmarks.sign_group,
      sigil,
      item.bufnr,
      { lnum = item.lnum, priority = M.extmarks.priority }
    )
  end
end -- }}}

---Updates all the signs based on the qflist and locallist values. We don't
---have a mechanism to detect item removeal, therefore it has to clear the
---signs and add them again on all buffers.
function M.update_signs() -- {{{
  vim.fn.sign_unplace(M.extmarks.sign_group)

  local locallist = {}
  local buffers = buffer_list()
  for _, buf in ipairs(buffers) do
    local list = vim.fn.getloclist(buf)
    if #list > 0 then
      locallist = merge_list(locallist, list)
    end
  end
  local qflist = vim.fn.getqflist()
  -- Bail early.
  if #locallist + #qflist == 0 then
    vim.api.nvim_clear_autocmds({ group = M.extmarks.group })
    return
  end

  if #qflist > 0 then
    M.insert_signs(qflist, false)
  end

  local items = {}
  if #locallist > 0 then
    for _, item in ipairs(locallist) do
      if item.type == M.extmarks.unique_id then
        table.insert(items, item)
      end
    end
    M.insert_signs(items, true)
  end
end -- }}}

---Returns buffer handles that appear in the list.
---@param is_local boolean
---@return number[]
local function get_buffers_in_list(is_local) -- {{{
  if is_local then
    return { 0 }
  end

  local buffers = {}
  local items = vim.fn.getqflist()
  for _, item in ipairs(items) do
    buffers[item.bufnr] = true
  end

  local list = {}
  for item in pairs(buffers) do
    table.insert(list, item)
  end
  return list
end -- }}}

---@param is_local boolean specifies what sign, extmark text and colour to use.
function M.setup_buf_autocmds(is_local) -- {{{
  local buffers = get_buffers_in_list(is_local)
  for _, bufnr in ipairs(buffers) do
    if not buf_autocmd_is_set(bufnr) then
      vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
        buffer = bufnr,
        group = M.extmarks.group,

        callback = function()
          local lazyredraw = vim.opt.lazyredraw:get()
          vim.opt.lazyredraw = true
          if M.extmarks.set_extmarks then
            M.update_extmarks()
          end

          if M.extmarks.set_signs then
            M.update_signs()
          end
          vim.opt.lazyredraw = lazyredraw
        end,
        desc = "Check for listish notes",
      })
    end
  end
end -- }}}

return M

-- vim: fdm=marker fdl=0
