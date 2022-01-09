# Listish.nvim

![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/arsham/listish.nvim)
![License](https://img.shields.io/github/license/arsham/listish.nvim)

Neovim plugin for quickfix and local lists. You can add and remove items, or
you can create notes on current position to either lists.

1. [Demo](#demo)
2. [Requirements](#requirements)
3. [Installation](#installation)
   - [Config](#config)
   - [Lazy Loading](#lazy-loading)
4. [License](#license)

## Demo

Both quickfix and local lists have the same set of functionalities.

Adding current location to the list:

![add](https://user-images.githubusercontent.com/428611/148661079-efbb29b9-369b-487b-8ff9-ece794f3bd3b.gif)

Deleting from list:

![delete](https://user-images.githubusercontent.com/428611/148661080-4e8f1531-e470-45eb-bf0d-fe78290bb2fa.gif)

Adding notes to the list:

![notes](https://user-images.githubusercontent.com/428611/148661081-caa84b55-664d-45ea-ac41-32f5791a8f01.gif)

## Requirements

At the moment it works on the development release of Neovim, and will be
officially supporting [Neovim 0.7.0](https://github.com/neovim/neovim/releases/tag/v0.7.0).

This plugin depends are the following libraries. Please make sure to add them
as dependencies in your package manager:

- [arshlib.nvim](https://github.com/arsham/arshlib.nvim)
- [nvim.lua](https://github.com/norcalli/nvim.lua)

## Installation

Use your favourite package manager to install this library. Packer example:

```lua
use({
  "arsham/listish.nvim",
  requires = { "arsham/arshlib.nvim", "norcalli/nvim.lua" },
  config = function() require("listish").config({}) end,
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
})
```

Here is the default settings:

```lua
{
  theme_list = true,
  clearqflist = "Clearquickfix", -- command
  clearloclist = "Clearloclist", -- command
  lists_close = "<leader>cc",    -- closes both qf/loacal lists
  in_list_dd = "dd",             -- delete current item in the list
  quickfix = {
    open = "<leader>qo",
    on_cursor = "<leader>qq",    -- add current position to the list
    add_note = "<leader>qn",     -- add current position with your note to the list
    clear = "<leader>qd",        -- clear all items
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
}
```

### Lazy Loading

You can let your package manager to load this plugin on either key-mapping
events or when the first quickfix/local list is opened. Packer example:

```lua
use({
  "arsham/listish.nvim",
  requires = { "arsham/arshlib.nvim", "norcalli/nvim.lua" },
  config = function() require("listish").config({}) end,
  keys = {
    "<leader>qq", "<leader>qn", "<leader>qo",
    "<leader>ww", "<leader>wn", "<leader>wo",
  },
  ft = { "qf" },
})
```

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.

<!--
vim: foldlevel=1
-->
