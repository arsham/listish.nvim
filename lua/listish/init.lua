local nvim = require("nvim")
local util = require("arshlib.util")
local quick = require("arshlib.quick")

---When using `dd` in the quickfix list, remove the item from the quickfix
-- list.
local function delete_list_item() -- {{{
  local cur_list = {}
  local close = nvim.ex.close
  local win_id = vim.fn.win_getid()
  local is_loc = vim.fn.getwininfo(win_id)[1].loclist == 1

  if is_loc then
    cur_list = vim.fn.getloclist(win_id)
    close = nvim.ex.lclose
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
    close()
  elseif item ~= 1 then
    quick.normal("n", ("%dj"):format(item - 1))
  end
end --}}}

-- @class ListItem
-- @field bufnr number
-- @field lnum number
-- @field col number
-- @field text string

---Inserts the current position of the cursor in the qf/local list with the
-- note.
-- @param items ListItem[]
-- @param is_local boolean if true, the item goes into the local list.
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

---Inserts the current position of the cursor in the qf/local list.
-- @param note string
-- @param is_local boolean if true, the item goes into the local list.
local function inset_note_to_list(note, is_local) --{{{
  local location = vim.api.nvim_win_get_cursor(0)
  local item = {
    bufnr = vim.fn.bufnr(),
    lnum = location[1],
    col = location[2] + 1,
    text = note,
  }
  insert_list({ item }, is_local)
end

local clearqflist = function()
  vim.fn.setqflist({})
  nvim.ex.cclose()
end
local clearloclist = function()
  vim.fn.setloclist(0, {})
  nvim.ex.lclose()
end
--}}}

---Opens a popup for a note, and adds the current line and column with the note
-- to the list.
-- @param is_local boolean if true, the item goes into the local list.
local function add_note(is_local) --{{{
  util.user_input({
    prompt = "Note: ",
    on_submit = function(value)
      inset_note_to_list(value, is_local)
    end,
  })
end --}}}

-- selene: allow(global_usage)
function _G.add_quickfix_note()
  add_note(false)
end
function _G.add_locallist_note()
  add_note(true)
end

---Add the current line and the column to the list.
-- @param name string the name of the mapping for repeating.
-- @param is_local boolean if true, the item goes into the local list.
local function add_line(name, is_local) --{{{
  local note = vim.api.nvim_get_current_line()
  inset_note_to_list(note, is_local)
  local key = vim.api.nvim_replace_termcodes(name, true, false, true)
  vim.fn["repeat#set"](key, vim.v.count)
end --}}}

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
-- @param key string the key to map.
-- @param next string the command to execute if there is a next item.
-- @param wrap string the command to execute if there is no next item.
-- @param desc string the description of the mapping.
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
    end, {noremap=true, desc = desc }
  )
end --}}}

local defaults = { --{{{
  theme_list = true,
  clearqflist = "Clearquickfix",
  clearloclist = "Clearloclist",
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

local function config(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts)
  local string_type = { "string", "nil", "boolean" }
  -- Validations {{{
  -- stylua: ignore start
  vim.validate({
    opts                = { opts,            { "table",   false } },
    theme_list          = { opts.theme_list, { "boolean", "nil" }, false },
    clearqflist         = { opts.clearqflist,         string_type },
    clearloclist        = { opts.clearloclist,        string_type },
    lists_close         = { opts.lists_close,         string_type },
    in_list_dd          = { opts.in_list_dd,          string_type },
    quickfix            = { opts.quickfix,            { "table" } },
    quickfix_open       = { opts.quickfix.open,       string_type },
    quickfix_on_cursor  = { opts.quickfix.on_cursor,  string_type },
    quickfix_add_note   = { opts.quickfix.add_note,   string_type },
    quickfix_clear      = { opts.quickfix.clear,      string_type },
    quickfix_close      = { opts.quickfix.close,      string_type },
    quickfix_next       = { opts.quickfix.next,       string_type },
    quickfix_prev       = { opts.quickfix.prev,       string_type },
    locallist           = { opts.locallist,           { "table" } },
    locallist_open      = { opts.locallist.open,      string_type },
    locallist_on_cursor = { opts.locallist.on_cursor, string_type },
    locallist_add_note  = { opts.locallist.add_note,  string_type },
    locallist_clear     = { opts.locallist.clear,     string_type },
    locallist_close     = { opts.locallist.close,     string_type },
    locallist_next      = { opts.locallist.next,      string_type },
    locallist_prev      = { opts.locallist.prev,      string_type },
  })
  -- }}}

  if opts.lists_close then
    vim.keymap.set("n", opts.lists_close, function()
      nvim.ex.cclose()
      nvim.ex.lclose()
    end, { noremap = true, silent = true, desc = "Close quickfix list and local list windows" })
  end

  if opts.theme_list then
    vim.o.qftf = "{info -> v:lua.qftf(info)}"
  end

  -- Quickfix list mappings {{{
  if opts.clearqflist then
    quick.command(opts.clearqflist, clearqflist)
  end

  if opts.clearloclist then
    quick.command(opts.clearloclist, clearloclist)
  end

  if opts.quickfix.open then
    vim.keymap.set("n", opts.quickfix.open, nvim.ex.copen,
      { noremap = true, silent = true, desc = "open quickfix list" }
    )
  end

  if opts.quickfix.on_cursor then
    vim.keymap.set("n", "<Plug>QuickfixAdd", function()
      add_line("<Plug>QuickfixAdd", false)
    end, { noremap = true, desc = "add to quickfix list" })

    vim.keymap.set("n", opts.quickfix.on_cursor, "<Plug>QuickfixAdd",
      { noremap = true, desc = "add to quickfix list" }
    )
  end

  if opts.quickfix.add_note then
    vim.keymap.set("n", opts.quickfix.add_note, function()
      vim.opt.opfunc = "v:lua.add_quickfix_note"
      return "g@<cr>"
    end, { noremap = true, expr = true, desc = "add to quickfix list with node" })
  end

  if opts.quickfix.clear then
    vim.keymap.set("n", opts.quickfix.clear, clearqflist,
      { noremap = true, silent = true, desc = "drop quickfix list" }
    )
  end

  if opts.quickfix.close then
    vim.keymap.set("n", opts.quickfix.close, nvim.ex.cclose,
      { noremap = true, silent = true, desc = "close quickfix list" }
    )
  end
  -- }}}

  -- Local list mappings {{{
  if opts.locallist.open then
    vim.keymap.set("n", opts.locallist.open, function()
      nvim.ex.silent_("lopen")
    end, { noremap = true, silent = true, desc = "open local list" }
    )
  end

  if opts.locallist.on_cursor then
    vim.keymap.set("n", "<Plug>LocallistAdd", function()
      add_line("<Plug>LocallistAdd", true)
    end, { noremap = true, desc = "add to local list" })
    vim.keymap.set("n", opts.locallist.on_cursor, "<Plug>LocallistAdd",
      { noremap = true, desc = "add to local list" }
    )
  end

  if opts.locallist.add_note then
    vim.keymap.set("n", opts.locallist.add_note, function()
      vim.opt.opfunc = "v:lua.add_locallist_note"
      return "g@<cr>"
    end, { noremap = true, expr = true, desc = "add to local list with node" })
  end

  if opts.locallist.clear then
    vim.keymap.set("n", opts.locallist.clear, clearloclist,
      { noremap = true, silent = true, desc = "drop local list" }
    )
  end

  if opts.locallist.close then
    vim.keymap.set("n", opts.locallist.close, nvim.ex.lclose,
      { noremap = true, silent = true, desc = "close local list" }
    )
  end
  -- }}}

  jump_list_mapping(opts.quickfix.next, "cnext", "cfirst", "jump to next item in qf list")
  jump_list_mapping(opts.quickfix.prev, "cprevious", "clast", "jump to previous item in qf list")
  jump_list_mapping(opts.locallist.next, "lnext", "lfirst", "jump to next item in local list")
  jump_list_mapping(opts.locallist.prev, "lprevious", "llast", "jump to previous item in local list")

  if opts.in_list_dd then
    quick.augroup({"QF_LOC_LISTS", {
      {"Filetype", "qf", docs = "don't list qf/local lists",
        run = function()
          vim.bo.buflisted = false
          vim.opt_local.cursorline = true
        end,
      },
      {"FileType", "qf", docs = "delete from qf/local lists",
        run = function()
          vim.keymap.set("n", opts.in_list_dd, delete_list_item,
            { noremap = true, buffer = true, desc = "delete from qf/local lists" }
          )
        end,
      },
    }})
  end
  -- stylua: ignore end
end

return {
  insert_list = insert_list,
  config = config,
}

-- vim: fdm=marker fdl=0
