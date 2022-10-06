local M = {}

local cache = {}

local function query_and_cache(opts)
  if type(cache[opts.bufnr]) == "number" then
    -- request is being processed
    return
  end
  cache[opts.bufnr] = 0

  local clients = vim.lsp.get_active_clients({
    bufnr = opts.bufnr,
  })

  clients = vim.tbl_filter(function(client)
    return client.server_capabilities.documentFormattingProvider and (not opts.filter or opts.filter(client))
  end, clients)
  if #clients == 0 then
    cache[opts.bufnr] = false
    return
  end

  local params = vim.lsp.util.make_formatting_params(opts.formatting_options)

  local do_query
  do_query = function(idx)
    _, cache[opts.bufnr] = clients[idx].request("textDocument/formatting", params, function(_, result, _, _)
      if result and #result > 0 then
        cache[opts.bufnr] = true
        return
      end

      if idx + 1 <= #clients then
        do_query(idx + 1)
      else
        cache[opts.bufnr] = false
      end
    end, opts.bufnr)
  end
  do_query(1)
end

local function clear(bufnr)
  cache[bufnr] = nil
end

local function normalize_opts(opts)
  opts = opts or {}
  if not opts.bufnr then
    opts = vim.tbl_extend("force", opts, { bufnr = vim.api.nvim_get_current_buf() })
  end
  return opts
end

function M.update(opts)
  query_and_cache(normalize_opts(opts))
end

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

function M.setup()
  local augroup = vim.api.nvim_create_augroup("lsp-query-format", {})
  vim.api.nvim_create_autocmd("LspAttach", {
    group = augroup,
    callback = function(args)
      clear(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = function(args)
      M.update({ bufnr = args.buf })
    end,
  })
  -- vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
  --   group = augroup,
  --   callback = vim.schedule_wrap(M.update),
  -- })
end

return M
