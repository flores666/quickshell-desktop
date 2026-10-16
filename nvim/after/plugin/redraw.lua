vim.api.nvim_create_autocmd({ "VimResized", "FocusGained", "BufEnter" }, {
  callback = function()
    vim.schedule(function()
      pcall(vim.cmd, "redraw!")
    end)
  end,
})

vim.keymap.set("n", "<C-l>", function()
  vim.cmd("nohlsearch")
  vim.cmd("redraw!")
end, { desc = "Clear search and redraw screen" })
