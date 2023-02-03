local default_config = {
  update_events = { "BufWritePost" },
}

local M = {}

--- Store formattable status or request id for each buffer.
---@type table<number, boolean|number|nil>
local cache = {}

--- Clear formattable status of the specified buffer.
---@param bufnr number
local function clear(bufnr)
  cache[bufnr] = nil
end

--- Query formattable status and stores to `cache` its result.
---@param opts table
local function query_and_cache(opts)
  if type(cache[opts.bufnr]) == "number" then
    -- request is being processed
    return
  end
  cache[opts.bufnr] = 0

  local done = function(value)
    if not vim.api.nvim_buf_is_loaded(opts.bufnr) then
      clear(opts.bufnr)
      return
    end

    cache[opts.bufnr] = value
    vim.b[opts.bufnr].lqf_formattable = value
    vim.api.nvim_buf_call(opts.bufnr, function()
      vim.api.nvim_exec_autocmds("User", { pattern = "LqfDone", modeline = false })
    end)
  end

  local clients = vim.lsp.get_active_clients({
    bufnr = opts.bufnr,
  })

  clients = vim.tbl_filter(function(client)
    return client.server_capabilities.documentFormattingProvider and (not opts.filter or opts.filter(client))
  end, clients)
  if #clients == 0 then
    done(false)
    return
  end

  local params = vim.lsp.util.make_formatting_params(opts.formatting_options)
  local do_query
  do_query = function(idx)
    _, cache[opts.bufnr] = clients[idx].request("textDocument/formatting", params, function(_, result, _, _)
      if result and #result > 0 then
        done(true)
        return
      end

      if idx + 1 <= #clients then
        do_query(idx + 1)
      else
        done(false)
      end
    end, opts.bufnr)
  end
  do_query(1)
end

--- Normalize options of APIs.
---@param opts table|nil
---@return table
local function normalize_opts(opts)
  opts = opts or {}
  if not opts.bufnr then
    opts = vim.tbl_extend("force", opts, { bufnr = vim.api.nvim_get_current_buf() })
  end
  return opts
end

--- Update formattable status. This function does not block.
---@param opts table|nil
---     - formatting_options (table|nil):
---         Can be used to specify FormattingOptions. Some unspecified options will be
---         automatically derived from the current Neovim options.
---         See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#formattingOptions
---     - bufnr (number|nil):
---         A buffer number to update status, defaults to the current buffer (0).
---     - filter (function|nil):
---         Predicate used to filter clients. Receives a client as argument and must return a
---         boolean. Clients matching the predicate are included. Example:
---
---         <pre>
---         -- Never request typescript-language-server for updating
---         require("lsp-query-format").update {
---           filter = function(client) return client.name ~= "tsserver" end
---         }
---         </pre>
function M.update(opts)
  query_and_cache(normalize_opts(opts))
end

--- Query formattable status. Returns `true` or `false` if status is available.
---@param opts table|nil
---     - formatting_options (table|nil):
---         Can be used to specify FormattingOptions. Some unspecified options will be
---         automatically derived from the current Neovim options.
---         See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#formattingOptions
---     - timeout_ms (integer|nil, default 10):
---         Time in milliseconds to block for a result.
---     - bufnr (number|nil):
---         A buffer number to query status, defaults to the current buffer (0).
---     - filter (function|nil):
---         Predicate used to filter clients. Receives a client as argument and must return a
---         boolean. Clients matching the predicate are included. Example:
---
---         <pre>
---         -- Never request typescript-language-server for querying
---         local formattable = require("lsp-query-format").query {
---           filter = function(client) return client.name ~= "tsserver" end
---         }
---         </pre>
---@return boolean|nil
function M.query(opts)
  opts = normalize_opts(opts)

  local result = cache[opts.bufnr]
  if type(result) ~= "boolean" then
    if result == nil then
      query_and_cache(opts)
    end
    result = nil

    -- wait a moment for the result
    vim.wait(opts.timeout_ms or 10, function()
      local r = cache[opts.bufnr]
      if type(r) == "boolean" then
        result = r
        return true
      end
      return false
    end, 10)
  end
  return result
end

--- Setup lsp-query-format.
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", opts or {}, default_config)

  local augroup = vim.api.nvim_create_augroup("lsp-query-format", {})
  vim.api.nvim_create_autocmd("LspAttach", {
    group = augroup,
    callback = function(args)
      clear(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd(opts.update_events, {
    group = augroup,
    callback = function(args)
      M.update({ bufnr = args.buf })
    end,
  })
end

return M
