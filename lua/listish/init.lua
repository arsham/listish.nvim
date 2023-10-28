---@type Quick
local quick = require("arshlib.quick")

local unique_id = "Z"
local visual = require("listish.visual")

---When using `dd` in the quickfix list, remove the item from the quickfix
-- list.
local function delete_list_item() -- {{{
  local cur_list = {}
  local close_cmd = "close"
  local win_id = vim.fn.win_getid()
  local is_loc = vim.fn.getwininfo(win_id)[1].loclist == 1

  if is_loc then
    cur_list = vim.fn.getloclist(win_id)
    close_cmd = "lclose"
  else
    cur_list = vim.fn.getqflist()
  end

  local count = vim.v.count
  if count == 0 then
    count = 1
  end
  if count > #cur_list then
    count = #cur_list
  end

  local item = vim.api.nvim_win_get_cursor(0)[1]
  for _ = item, item + count - 1 do
    table.remove(cur_list, item)
  end

  if is_loc then
    vim.fn.setloclist(win_id, cur_list)
  else
    vim.fn.setqflist(cur_list)
  end

  if #cur_list == 0 then
    vim.api.nvim_command(close_cmd)
  elseif item ~= 1 then
    quick.normal("n", ("%dj"):format(item - 1))
  end
end --}}}

---Inserts the current position of the cursor in the qf/location list with the
-- note. If extmarks and/or signs are enabled will update them.
---@param items ListItem[]
---@param is_loc boolean if true, the item goes into the location list.
local function insert_list(items, is_loc) --{{{
  local cur_list = {}
  if is_loc then
    cur_list = vim.fn.getloclist(0)
  else
    cur_list = vim.fn.getqflist()
  end

  cur_list = vim.list_extend(cur_list, items)

  if is_loc then
    vim.fn.setloclist(0, cur_list)
  else
    vim.fn.setqflist(cur_list)
  end

  if visual.extmarks.set_extmarks then
    visual.insert_extmarks(items, is_loc)
  end
  if visual.extmarks.set_signs then
    visual.insert_signs(items, is_loc)
  end
  visual.setup_buf_autocmds(is_loc)
end --}}}

---Inserts the current position of the cursor in the qf/location list.
---@param note string
---@param is_loc boolean if true, the item goes into the location list.
local function insert_note_to_list(note, is_loc) --{{{
  local location = vim.api.nvim_win_get_cursor(0)
  local item = {
    bufnr = vim.fn.bufnr(),
    lnum = location[1],
    col = location[2] + 1,
    text = note,
    type = unique_id,
  }
  insert_list({ item }, is_loc)
end

local clearqflist = function()
  vim.fn.setqflist({})
  vim.cmd.cclose()
  if visual.extmarks.set_extmarks then
    visual.update_extmarks()
  end
  if visual.extmarks.set_signs then
    visual.update_signs()
  end
end

local clearloclist = function()
  vim.fn.setloclist(0, {})
  vim.cmd.lclose()
  if visual.extmarks.set_extmarks then
    visual.update_extmarks()
  end
  if visual.extmarks.set_signs then
    visual.update_signs()
  end
end
--}}}

local function filter_listish_items(cur_list) -- {{{
  local new_list = {}
  for _, item in ipairs(cur_list) do
    if item.type ~= unique_id then
      table.insert(new_list, item)
    end
  end
  return new_list
end -- }}}

---Clears the items added by this plugin from the quickfix list and the
-- location list of the current window.
local function clear_notes() --{{{
  local new_list = filter_listish_items(vim.fn.getloclist(0))
  vim.fn.setloclist(0, new_list)

  new_list = filter_listish_items(vim.fn.getqflist())
  vim.fn.setqflist(new_list)
end --}}}

---Opens a popup for a note, and adds the current line and column with the note
-- to the list.
---@param is_loc boolean if true, the item goes into the location list.
local function add_note(is_loc) --{{{
  vim.ui.input({
    prompt = "Note: ",
  }, function(value)
    if value then
      insert_note_to_list(value, is_loc)
    end
  end)
end --}}}

-- Lua global space functions {{{
local function add_quickfix_note()
  add_note(false)
end
local function add_locationlist_note()
  add_note(true)
end

---Add the current line and the column to the quickfix list.
local function insert_to_quickfix()
  local line = vim.api.nvim_get_current_line()
  insert_note_to_list(line, false)
end

---Add the current line and the column to the location list.
local function insert_to_location_list()
  local line = vim.api.nvim_get_current_line()
  insert_note_to_list(line, true)
end
-- }}}

---Makes the quickfix and location list prettier. Borrowed from nvim-bqf.
-- selene: allow(global_usage)
function _G.qftf(info) --{{{
  local items
  local ret = {}
  if info.quickfix == 1 then
    items = vim.fn.getqflist({ id = info.id, items = 0 }).items
  else
    items = vim.fn.getloclist(info.winid, { id = info.id, items = 0 }).items
  end
  local limit = 40
  local fname_fmt1, fname_fmt2 = "%-" .. limit .. "s", "…%." .. (limit - 1) .. "s"
  local valid_fmt = "%s │%5d:%-3d│%s %s"
  for i = info.start_idx, info.end_idx do
    local e = items[i]
    local fname = ""
    local str
    if e.valid == 1 then
      if e.bufnr > 0 then
        fname = vim.fn.bufname(e.bufnr)
        if fname == "" then
          fname = "[No Name]"
        else
          fname = fname:gsub("^" .. vim.env.HOME, "~")
        end
        if #fname <= limit then
          fname = fname_fmt1:format(fname)
        else
          fname = fname_fmt2:format(fname:sub(1 - limit))
        end
      end
      local lnum = e.lnum > 99999 and -1 or e.lnum
      local col = e.col > 999 and -1 or e.col
      local qtype = e.type == "" and "" or " " .. e.type:sub(1, 1):upper()
      str = valid_fmt:format(fname, lnum, col, qtype, e.text)
    else
      str = e.text
    end
    table.insert(ret, str)
  end
  return ret
end --}}}

---Creates a mapping for jumping through lists.
local function jump_list_mapping(opts) --{{{
  local move_fn = function(next, wrap)
    return function()
      local ok = pcall(vim.cmd, next)
      if not ok then
        pcall(vim.cmd, wrap)
      end
    end
  end
  local c_next = move_fn("cnext", "cfirst")
  local c_prev = move_fn("cprev", "clast")
  local l_next = move_fn("lnext", "lfirst")
  local l_prev = move_fn("lprev", "llast")
  local ok, ts_repeat_move = pcall(require, "nvim-treesitter.textobjects.repeatable_move")
  if ok then
    c_next, c_prev = ts_repeat_move.make_repeatable_move_pair(c_next, c_prev)
    l_next, l_prev = ts_repeat_move.make_repeatable_move_pair(l_next, l_prev)
  end

  if opts.quickfix.next then
    local desc = "jump to next item in qf list"
    vim.keymap.set("n", opts.quickfix.next, c_next, { desc = desc })
  end
  if opts.quickfix.prev then
    local desc = "jump to previous item in qf list"
    vim.keymap.set("n", opts.quickfix.prev, c_prev, { desc = desc })
  end
  if opts.loclist.next then
    local desc = "jump to next item in location list"
    vim.keymap.set("n", opts.loclist.next, l_next, { desc = desc })
  end
  if opts.loclist.prev then
    local desc = "jump to previous item in location list"
    vim.keymap.set("n", opts.loclist.prev, l_prev, { desc = desc })
  end
end --}}}

---Sets up the highlight groups if they are not already defined by user.
local function setup_highlight_groups() -- {{{
  local names = {
    qf_sign_hl = visual.extmarks.qf_sign_hl_group,
    qf_ext_hl = visual.extmarks.qf_ext_hl_group,
    local_sign_hl = visual.extmarks.local_sign_hl_group,
    local_ext_hl = visual.extmarks.loc_ext_hl_group,
  }
  for id, name in pairs(names) do
    local ok = pcall(vim.api.nvim_get_hl_by_name, name, true)
    if not ok then
      quick.highlight(name, visual.extmarks[id])
    end
  end
end -- }}}

local defaults = { --{{{
  theme_list = true,
  clearqflist = "Clearquickfix",
  clearloclist = "Clearloclist",
  clear_notes = "ClearListNotes",
  lists_close = "<leader>cc",
  in_list_dd = "dd",
  signs = {
    loclist = "",
    qflist = "",
    priority = 10,
  },
  extmarks = {
    loclist_text = "Locationlist Note",
    qflist_text = "Quickfix Note",
  },
  quickfix = {
    open = "<leader>qo",
    on_cursor = "<leader>qq",
    add_note = "<leader>qn",
    clear = "<leader>qd",
    close = "<leader>qc",
    next = "]q",
    prev = "[q",
  },

  loclist = {
    open = "<leader>wo",
    on_cursor = "<leader>ww",
    add_note = "<leader>wn",
    clear = "<leader>wd",
    close = "<leader>wc",
    next = "]w",
    prev = "[w",
  },
} --}}}

local function setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})
  local string_type = { "string", "nil", "boolean" }
  local table_type = { "table", "nil", "boolean" }
  -- Validations {{{
  -- stylua: ignore
  vim.validate({
    opts         = { opts,              { "table", false } },
    theme_list   = { opts.theme_list,   { "boolean", "nil" }, false },
    clearqflist  = { opts.clearqflist,  string_type },
    clearloclist = { opts.clearloclist, string_type },
    clear_notes  = { opts.clear_notes,  string_type },
    lists_close  = { opts.lists_close,  string_type },
    in_list_dd   = { opts.in_list_dd,   string_type },
    signs        = { opts.signs,        table_type },
    extmarks     = { opts.extmarks,     table_type },
    quickfix     = { opts.quickfix,     { "table" } },
    loclist    = { opts.loclist,    { "table" } },
  })
  -- }}}

  setup_highlight_groups()

  -- Signs {{{
  if opts.signs then
    -- stylua: ignore
    vim.validate({
      signs_loclist = { opts.signs.loclist, string_type },
      signs_qflist    = { opts.signs.qflist,    string_type },
      signs_priority  = { opts.signs.priority,  { "number" }},
    })
    visual.extmarks.set_signs = true
    visual.extmarks.qf_sigil = opts.signs.qflist
    visual.extmarks.local_sigil = opts.signs.loclist
    visual.extmarks.priority = opts.signs.priority
    vim.fn.sign_define(
      visual.extmarks.qf_sigil,
      { text = visual.extmarks.qf_sigil, texthl = visual.extmarks.qf_sign_hl_group }
    )
    vim.fn.sign_define(
      visual.extmarks.local_sigil,
      { text = visual.extmarks.local_sigil, texthl = visual.extmarks.local_sign_hl_group }
    )
  end
  -- }}}

  -- Extmarks {{{
  if opts.extmarks then
    -- stylua: ignore
    vim.validate({
      extmarks_local_text = { opts.extmarks.loclist_text, string_type },
      extmarks_qf_text    = { opts.extmarks.qflist_text,    string_type },
    })
    visual.extmarks.set_extmarks = true
    visual.extmarks.qf_badge = opts.extmarks.qflist_text
    visual.extmarks.loc_badge = opts.extmarks.loclist_text
  end
  -- }}}

  if opts.lists_close then
    vim.keymap.set("n", opts.lists_close, function()
      vim.cmd.cclose()
      vim.cmd.lclose()
    end, { silent = true, desc = "Close quickfix list and location list windows" })
  end

  if opts.theme_list then
    vim.o.qftf = "{info -> v:lua.qftf(info)}"
  end

  -- Quickfix list mappings {{{
  if opts.clearqflist then
    quick.command(opts.clearqflist, clearqflist, { desc = "clear quickfix list items" })
  end

  if opts.clearloclist then
    quick.command(opts.clearloclist, clearloclist, { desc = "clear location list items" })
  end

  if opts.clear_notes then
    quick.command(opts.clear_notes, clear_notes, { desc = "clear notes from list" })
  end

  if opts.quickfix then
    -- stylua: ignore
    vim.validate({
      quickfix_open       = { opts.quickfix.open,       string_type },
      quickfix_on_cursor  = { opts.quickfix.on_cursor,  string_type },
      quickfix_add_note   = { opts.quickfix.add_note,   string_type },
      quickfix_clear      = { opts.quickfix.clear,      string_type },
      quickfix_close      = { opts.quickfix.close,      string_type },
      quickfix_next       = { opts.quickfix.next,       string_type },
      quickfix_prev       = { opts.quickfix.prev,       string_type },
    })
  else
    opts.quickfix = {}
  end

  if opts.quickfix.open then
    vim.keymap.set("n", opts.quickfix.open, function()
      vim.cmd.copen()
    end, { silent = true, desc = "open quickfix list" })
  end

  if opts.quickfix.on_cursor then
    vim.keymap.set("n", opts.quickfix.on_cursor, function()
      vim.opt.opfunc = "v:lua.require'listish'.insert_to_quickfix"
      return "g@<cr>"
    end, { expr = true, desc = "add to quickfix list" })
  end

  if opts.quickfix.add_note then
    vim.keymap.set("n", opts.quickfix.add_note, function()
      vim.opt.opfunc = "v:lua.require'listish'.add_quickfix_note"
      return "g@<cr>"
    end, { expr = true, desc = "add to quickfix list with node" })
  end

  -- stylua: ignore
  if opts.quickfix.clear then
    vim.keymap.set("n", opts.quickfix.clear, clearqflist,
      { silent = true, desc = "drop quickfix list" }
    )
  end

  if opts.quickfix.close then
    vim.keymap.set("n", opts.quickfix.close, function()
      vim.cmd.cclose()
    end, { silent = true, desc = "close quickfix list" })
  end
  -- }}}

  -- Local list mappings {{{
  if opts.loclist then
    -- stylua: ignore
    vim.validate({
      loclist_open      = { opts.loclist.open,      string_type },
      loclist_on_cursor = { opts.loclist.on_cursor, string_type },
      loclist_add_note  = { opts.loclist.add_note,  string_type },
      loclist_clear     = { opts.loclist.clear,     string_type },
      loclist_close     = { opts.loclist.close,     string_type },
      loclist_next      = { opts.loclist.next,      string_type },
      loclist_prev      = { opts.loclist.prev,      string_type },
    })
  else
    opts.loclist = {}
  end

  if opts.loclist.open then
    vim.keymap.set("n", opts.loclist.open, function()
      vim.api.nvim_command("silent! lopen")
    end, { silent = true, desc = "open local list" })
  end

  if opts.loclist.on_cursor then
    vim.keymap.set("n", opts.loclist.on_cursor, function()
      vim.opt.opfunc = "v:lua.require'listish'.insert_to_location_list"
      return "g@<cr>"
    end, { expr = true, desc = "add to local list" })
  end

  -- stylua: ignore
  if opts.loclist.add_note then
    vim.keymap.set("n", opts.loclist.add_note, function()
      vim.opt.opfunc = "v:lua.require'listish'.add_locationlist_note"
      return "g@<cr>"
    end, { expr = true, desc = "add to location list with node" })
  end

  -- stylua: ignore
  if opts.loclist.clear then
    vim.keymap.set("n", opts.loclist.clear, clearloclist,
      { silent = true, desc = "drop location list" }
    )
  end

  if opts.loclist.close then
    vim.keymap.set("n", opts.loclist.close, function()
      vim.cmd.lclose()
    end, { silent = true, desc = "close location list" })
  end
  -- }}}

  if opts.quickfix.next or opts.quickfix.prev or opts.loclist.next or opts.loclist.prev then
    jump_list_mapping(opts)
  end

  -- Delete items with dd {{{
  if opts.in_list_dd then
    local qf_loc_lists_group = vim.api.nvim_create_augroup("QF_LOC_LISTS", { clear = true })
    vim.api.nvim_create_autocmd("Filetype", {
      group = qf_loc_lists_group,
      pattern = "qf",
      desc = "don't list qf/location lists",
      callback = function()
        vim.bo.buflisted = false
        ---@diagnostic disable-next-line: assign-type-mismatch
        vim.opt_local.cursorline = true
      end,
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = qf_loc_lists_group,
      pattern = "qf",
      desc = "delete from qf/location lists",
      callback = function()
        -- stylua: ignore
        vim.keymap.set("n", opts.in_list_dd, delete_list_item,
          { buffer = true, desc = "delete from qf/location lists" }
        )
      end,
    })
  end
  -- }}}
  -- stylua: ignore end
end

return {
  insert_list = insert_list,
  add_locationlist_note = add_locationlist_note,
  add_quickfix_note = add_quickfix_note,
  insert_to_quickfix = insert_to_quickfix,
  insert_to_location_list = insert_to_location_list,
  setup = setup,
  config = setup,
}

-- vim: fdm=marker fdl=0
