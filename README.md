# Listish.nvim

![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/arsham/listish.nvim)
![License](https://img.shields.io/github/license/arsham/listish.nvim)

Neovim plugin for quickfix and local lists. You can add and remove items, or
you can create notes on current position to either lists. It can show in the
`signcolumn` where the note is made, and/or show as `extmarks`.

1. [Demo](#demo)
2. [Requirements](#requirements)
3. [Installation](#installation)
   - [Lazy](#lazy)
   - [Packer](#packer)
   - [Config](#config)
   - [Highlight Groups](#highlight-groups)
   - [Lazy Loading](#lazy-loading)
4. [Related Projects](#related-projects)
5. [License](#license)

## Demo

Both Quickfix and Location lists have the same set of functionalities.

Adding current location to the list:

![add](https://user-images.githubusercontent.com/428611/148661079-efbb29b9-369b-487b-8ff9-ece794f3bd3b.gif)

Deleting from list:

![delete](https://user-images.githubusercontent.com/428611/148661080-4e8f1531-e470-45eb-bf0d-fe78290bb2fa.gif)

Adding notes to the list:

![notes](https://user-images.githubusercontent.com/428611/148661081-caa84b55-664d-45ea-ac41-32f5791a8f01.gif)

## Requirements

This library supports [Neovim
v0.10.0](https://github.com/neovim/neovim/releases/tag/v0.10.0) and newer.

This plugin depends are the following libraries. Please make sure to add them
as dependencies in your package manager:

- [arshlib.nvim](https://github.com/arsham/arshlib.nvim)
- (Optional) [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)

The _nvim-treesitter-textobjects_ is only used for repeating the actions of
next/previous item movements.

Please consider using the [nvim-bqf](https://github.com/kevinhwang91/nvim-bqf)
plugin to get the most out of your lists.

## Installation

Use your favourite package manager to install this library.

### Lazy

```lua
{
  "arsham/listish.nvim",
  dependencies = {
    "arsham/arshlib.nvim",
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = true,
  -- or to provide configuration
  -- config = { theme_list = false, ..}
}
```

### Packer

```lua
use({
  "arsham/listish.nvim",
  requires = {
    "arsham/arshlib.nvim",
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    require("listish").config({})
  end,
})
```

### Config

By default this pluging adds all necessary commands and mappings, and updates
the theme of the buffer. However you can change or disable them to your liking.

To disable set them to `false`. For example:

```lua
require("listish").config({
  theme_list = false,
  local_list = false,
  signs = false,
})
```

Here is the default settings:

```lua
{
  theme_list = true,
  clearqflist = "Clearquickfix",  -- command
  clearloclist = "Clearloclist",  -- command
  clear_notes = "ClearListNotes", -- command
  lists_close = "<leader>cc",     -- closes both qf/local lists
  in_list_dd = "dd",              -- delete current item in the list
  signs = {                       -- show signs on the signcolumn
    loclist = "",                -- the icon/sigil/sign on the signcolumn
    qflist = "",                 -- the icon/sigil/sign on the signcolumn
    priority = 10,
  },
  extmarks = {                    -- annotate with extmarks
    loclist_text = "loclist Note",
    qflist_text = "Quickfix Note",
  },
  quickfix = {
    open = "<leader>qo",
    on_cursor = "<leader>qq",     -- add current position to the list
    add_note = "<leader>qn",      -- add current position with your note to the list
    clear = "<leader>qd",         -- clear all items
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
}
```

### Highlight Groups

There are four highlight groups for signs and extmarks:

- `ListishQfSign`
- `ListishQfExt`
- `ListishLocalSign`
- `ListishLocalExt`

### Lazy Loading

You can let your package manager to load this plugin on either key-mapping
events or when the first quickfix/local list is opened. Packer example:

```lua
use({
  "arsham/listish.nvim",
  dependencies = {
    "arsham/arshlib.nvim",
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    require("listish").config({})
  end,
  keys = {
    "<leader>qq",
    "<leader>qn",
    "<leader>qo",
    "<leader>ww",
    "<leader>wn",
    "<leader>wo",
  },
  ft = { "qf" },
})
```

## Related Projects

- [nvim-bqf](https://github.com/kevinhwang91/nvim-bqf): manipulate lists with fzf
- [replacer.nvim](https://github.com/gabrielpoca/replacer.nvim): makes a quickfix list editable in both content and file path
- [quickfix-reflector.vim](https://github.com/stefandtw/quickfix-reflector.vim): change code right in the quickfix window

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.

<!--
vim: foldlevel=1
-->
