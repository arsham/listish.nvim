---@type Quick
local quick = require("arshlib.quick")

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


---Inserts the current position of the cursor in the qf/local list with the
-- note.
---@param items ListItem[]
---@param is_local boolean if true, the item goes into the local list.
local function insert_list(items, is_local) --{{{
  local cur_list = {}
  if is_local then
    cur_list = vim.fn.getloclist(0)
  else
    cur_list = vim.fn.getqflist()
  end

  cur_list = vim.list_extend(cur_list, items)

  if is_local then
    vim.fn.setloclist(0, cur_list)
  else
    vim.fn.setqflist(cur_list)
  end
end --}}}

local unique_id = "Z"

---Inserts the current position of the cursor in the qf/local list.
---@param note string
---@param is_local boolean if true, the item goes into the local list.
local function insert_note_to_list(note, is_local) --{{{
  local location = vim.api.nvim_win_get_cursor(0)
  local item = {
    bufnr = vim.fn.bufnr(),
    lnum = location[1],
    col = location[2] + 1,
    text = note,
    type = unique_id,
  }
  insert_list({ item }, is_local)
end

local clearqflist = function()
  vim.fn.setqflist({})
  vim.cmd.cclose()
end
local clearloclist = function()
  vim.fn.setloclist(0, {})
  vim.cmd.lclose()
end
--}}}

local function filter_listish_items(cur_list)
  local new_list = {}
  for _, item in ipairs(cur_list) do
    if item.type ~= unique_id then
      table.insert(new_list, item)
    end
  end
  return new_list
end

---Clears the items added by this plugin from the quickfix list and the local
-- list of the current window.
local function clear_notes() --{{{
  local new_list = filter_listish_items(vim.fn.getloclist(0))
  vim.fn.setloclist(0, new_list)

  new_list = filter_listish_items(vim.fn.getqflist())
  vim.fn.setqflist(new_list)
end --}}}

---Opens a popup for a note, and adds the current line and column with the note
-- to the list.
---@param is_local boolean if true, the item goes into the local list.
local function add_note(is_local) --{{{
  vim.ui.input({
    prompt = "Note: ",
  }, function(value)
    if value then
      insert_note_to_list(value, is_local)
    end
  end)
end --}}}

-- selene: allow(global_usage)
function _G.add_quickfix_note()
  add_note(false)
end
-- selene: allow(global_usage)
function _G.add_locallist_note()
  add_note(true)
end

-- selene: allow(global_usage)
---Add the current line and the column to the quickfix list.
function _G.insert_to_quickfix()
  local line = vim.api.nvim_get_current_line()
  insert_note_to_list(line, false)
end

---Add the current line and the column to the local list.
-- selene: allow(global_usage)
function _G.insert_to_locallist()
  local line = vim.api.nvim_get_current_line()
  insert_note_to_list(line, true)
end

---Makes the quickfix and local list prettier. Borrowed from nvim-bqf.
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
---@param key string the key to map.
---@param next string the command to execute if there is a next item.
---@param wrap string the command to execute if there is no next item.
---@param desc string the description of the mapping.
local function jump_list_mapping(key, next, wrap, desc) --{{{
  if not key then
    -- this makes the config simpler.
    return
  end
  -- stylua: ignore
  vim.keymap.set("n", key, function()
    quick.cmd_and_centre(([[
      try
        %s
      catch /^Vim\%%((\a\+)\)\=:E553/
        %s
      catch /^Vim\%%((\a\+)\)\=:E42\|E776/
      endtry
      ]]):format(next, wrap))
    end, {desc = desc }
  )
end --}}}

local defaults = { --{{{
  theme_list = true,
  clearqflist = "Clearquickfix",
  clearloclist = "Clearloclist",
  clear_notes = "ClearListNotes",
  lists_close = "<leader>cc",
  in_list_dd = "dd",
  quickfix = {
    open = "<leader>qo",
    on_cursor = "<leader>qq",
    add_note = "<leader>qn",
    clear = "<leader>qd",
    close = "<leader>qc",
    next = "]q",
    prev = "[q",
  },

  locallist = {
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
  -- Validations {{{
  -- stylua: ignore
  vim.validate({
    opts                = { opts,            { "table",   false } },
    theme_list          = { opts.theme_list, { "boolean", "nil" }, false },
    clearqflist         = { opts.clearqflist,         string_type },
    clearloclist        = { opts.clearloclist,        string_type },
    clear_notes         = { opts.clear_notes,         string_type },
    lists_close         = { opts.lists_close,         string_type },
    in_list_dd          = { opts.in_list_dd,          string_type },
    quickfix            = { opts.quickfix,            { "table" } },
    locallist           = { opts.locallist,           { "table" } },
  })
  -- }}}

  if opts.lists_close then
    vim.keymap.set("n", opts.lists_close, function()
      vim.cmd.cclose()
      vim.cmd.lclose()
    end, { silent = true, desc = "Close quickfix list and local list windows" })
  end

  if opts.theme_list then
    vim.o.qftf = "{info -> v:lua.qftf(info)}"
  end

  -- Quickfix list mappings {{{
  if opts.clearqflist then
    quick.command(opts.clearqflist, clearqflist, { desc = "clear quickfix list items" })
  end

  if opts.clearloclist then
    quick.command(opts.clearloclist, clearloclist, { desc = "clear local list items" })
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
      vim.opt.opfunc = "v:lua.insert_to_quickfix"
      return "g@<cr>"
    end, { expr = true, desc = "add to quickfix list" })
  end

  if opts.quickfix.add_note then
    vim.keymap.set("n", opts.quickfix.add_note, function()
      vim.opt.opfunc = "v:lua.add_quickfix_note"
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

  if opts.locallist then
    -- stylua: ignore
    vim.validate({
      locallist_open      = { opts.locallist.open,      string_type },
      locallist_on_cursor = { opts.locallist.on_cursor, string_type },
      locallist_add_note  = { opts.locallist.add_note,  string_type },
      locallist_clear     = { opts.locallist.clear,     string_type },
      locallist_close     = { opts.locallist.close,     string_type },
      locallist_next      = { opts.locallist.next,      string_type },
      locallist_prev      = { opts.locallist.prev,      string_type },
    })
  else
    opts.locallist = {}
  end

  -- Local list mappings {{{
  if opts.locallist.open then
    vim.keymap.set("n", opts.locallist.open, function()
      vim.api.nvim_command("silent! lopen")
    end, { silent = true, desc = "open local list" })
  end

  if opts.locallist.on_cursor then
    vim.keymap.set("n", opts.locallist.on_cursor, function()
      vim.opt.opfunc = "v:lua.insert_to_locallist"
      return "g@<cr>"
    end, { expr = true, desc = "add to local list" })
  end

  -- stylua: ignore
  if opts.locallist.add_note then
    vim.keymap.set("n", opts.locallist.add_note, function()
      vim.opt.opfunc = "v:lua.add_locallist_note"
      return "g@<cr>"
    end, { expr = true, desc = "add to local list with node" })
  end

  -- stylua: ignore
  if opts.locallist.clear then
    vim.keymap.set("n", opts.locallist.clear, clearloclist,
      { silent = true, desc = "drop local list" }
    )
  end

  if opts.locallist.close then
    vim.keymap.set("n", opts.locallist.close, function()
      vim.cmd.lclose()
    end, { silent = true, desc = "close local list" })
  end
  -- }}}

  jump_list_mapping(opts.quickfix.next, "cnext", "cfirst", "jump to next item in qf list")
  jump_list_mapping(opts.quickfix.prev, "cprevious", "clast", "jump to previous item in qf list")
  jump_list_mapping(opts.locallist.next, "lnext", "lfirst", "jump to next item in local list")
  -- stylua: ignore
  jump_list_mapping(opts.locallist.prev, "lprevious", "llast", "jump to previous item in local list")

  if opts.in_list_dd then
    local qf_loc_lists_group = vim.api.nvim_create_augroup("QF_LOC_LISTS", { clear = true })
    vim.api.nvim_create_autocmd("Filetype", {
      group = qf_loc_lists_group,
      pattern = "qf",
      desc = "don't list qf/local lists",
      callback = function()
        vim.bo.buflisted = false
        ---@diagnostic disable-next-line: assign-type-mismatch
        vim.opt_local.cursorline = true
      end,
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = qf_loc_lists_group,
      pattern = "qf",
      desc = "delete from qf/local lists",
      callback = function()
        -- stylua: ignore
        vim.keymap.set("n", opts.in_list_dd, delete_list_item,
          { buffer = true, desc = "delete from qf/local lists" }
        )
      end,
    })
  end
  -- stylua: ignore end
end

return {
  insert_list = insert_list,
  setup = setup,
  config = setup,
}

-- vim: fdm=marker fdl=0
