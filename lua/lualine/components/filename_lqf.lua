local M = require("lualine.components.filename"):extend()

local lqf = require("lsp-query-format")

local default_options = {
  symbols = {
    formattable = "[F]",
  },
  format_status = true,
}

local function is_new_file()
  local filename = vim.fn.expand("%")
  return filename ~= "" and vim.bo.buftype == "" and vim.fn.filereadable(filename) == 0
end

local function has_any_symbol(options)
  if options.file_status then
    if vim.bo.modified then
      return true
    end
    if vim.bo.modifiable == false or vim.bo.readonly == true then
      return true
    end
  end

  if options.newfile_status and is_new_file() then
    return true
  end

  return false
end

M.init = function(self, options)
  self.super.init(self, options)
  self.options = vim.tbl_deep_extend("force", self.options, default_options)
end

M.update_status = function(self)
  local data = self.super.update_status(self)

  if self.options.format_status and lqf.query() then
    if not has_any_symbol(self.options) then
      data = data .. " "
    end
    data = data .. self.options.symbols.formattable
  end

  return data
end

return M
