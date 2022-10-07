# lsp-query-format.nvim

![lsp-query-format.nvim](https://user-images.githubusercontent.com/2226696/194503377-036758f5-c657-4902-b40c-cb6cffa2e845.gif)

A neovim plugin to query "formattable status" by LSP.
"formattable" means `vim.lsp.buf.format` changes the buffer content.

In practice, you would use [lualine.nvim] to display the formattable status.
See below for more details.

[lualine.nvim]: https://github.com/nvim-lualine/lualine.nvim

## Installation

Using [packer.nvim]:
```lua
use {
  "aznhe21/lsp-query-format.nvim",
  config = function()
    require("lsp-query-format").setup()
  end,
}
```

[packer.nvim]: https://github.com/wbthomason/packer.nvim

## Configuration

By default, formattable status is updated only when files are saved.
You can update the status more frequently by using autocmd, such as `CursorHold`.
**Note**: This may be annoying because some LSP servers (such as null-ls) report formatting progress.

```lua
require("lsp-query-format").setup {
  update_events = { "BufEnter", "BufWritePost", "CursorHold", "InsertLeave" },
}
```

## Usage

This plugin sets a boolean value to `b:lqf_formattable` for each buffer.
There is also an autocmd, `LqfDone`, which is executed when the formattable queries are done.

Display formattable status in a statusline:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "LqfDone",
  callback = function(args)
    vim.b[args.buf].lqf_status = vim.b[args.buf].lqf_formattable and " [F]" or ""
  end,
})
vim.opt.statusline = [[%f%{get(b:, "lqf_status", "")}]]
```

You can use [lualine.nvim] for more convenient and customizable display.
See below for more details.

## Extensions

### lualine.nvim

<https://user-images.githubusercontent.com/2226696/194503049-8471f52c-0909-4ba2-b85a-923120bd918e.mp4>

You can use `filename_lqf` instead of `filename` to display `[F]` marker when formatting is available.
In addition to `filename` options, `filename_lqf` has its own options.

```lua
sections = {
  lualine_a = {
    {
      'filename_lqf',
      file_status = true,      -- Displays file status (readonly status, modified status)
      newfile_status = false,  -- Display new file status (new file means no write after created)
      format_status = true,    -- [LQF] Display formattable status
      path = 0,                -- 0: Just the filename
                               -- 1: Relative path
                               -- 2: Absolute path
                               -- 3: Absolute path, with tilde as the home directory

      shorting_target = 40,    -- Shortens path to leave 40 spaces in the window
                               -- for other components. (terrible name, any suggestions?)
      symbols = {
        modified = '[+]',      -- Text to show when the file is modified.
        readonly = '[-]',      -- Text to show when the file is non-modifiable or readonly.
        unnamed = '[No Name]', -- Text to show for unnamed buffers.
        newfile = '[New]',     -- Text to show for new created file before first writting
        formattable = '[F]',   -- [LQF] Text to show for formattable buffers.
      }
    }
  },
}
```

## LICENSE

[GPLv3]

[GPLv3]: https://www.gnu.org/licenses/gpl-3.0.html
