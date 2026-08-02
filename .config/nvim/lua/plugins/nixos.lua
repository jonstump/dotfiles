-- NixOS-only overrides. Inert everywhere else.
--
-- mason.nvim (pulled in by LazyVim core) installs language servers and
-- formatters by downloading upstream release tarballs. Nearly all of them are
-- dynamically linked against /lib64/ld-linux-x86-64.so.2, which NixOS doesn't
-- have — so they "install" successfully and then fail to exec.
--
-- LazyVim is happy to use whatever servers are already on PATH when mason is
-- disabled, so install lua-language-server, stylua, nil/nixd etc. via
-- home.packages in the flake/home-manager repo instead.
--
-- nvim-treesitter has the same problem for compiled parsers unless a compiler
-- and headers are on PATH, so don't auto-install those either.
local uv = vim.uv or vim.loop
if uv.fs_stat("/etc/NIXOS") == nil then
  return {}
end

return {
  { "williamboman/mason.nvim", enabled = false },
  { "williamboman/mason-lspconfig.nvim", enabled = false },
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { "nvim-treesitter/nvim-treesitter", opts = { auto_install = false } },
}
