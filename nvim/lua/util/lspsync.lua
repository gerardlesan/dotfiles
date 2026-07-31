--- ~/.config/nvim/lua/util/lspsync.lua
---
--- KEEP LSP CHANGE TRACKING ALIVE across a server restart.
---
--- Symptom this exists for — seen on Windows with rust-analyzer, but nothing
--- about it is language- or platform-specific:
---
---   Error  Decoration provider "win" (ns=nvim.lsp.inlayhint):
---   .../vim/lsp/inlay_hint.lua:362: Invalid 'col': out of range
---
--- repeated on every redraw (so noice, diagnostics and anything else that calls
--- nvim__redraw each re-raise it), until the buffer is closed and reopened.
---
--- ── WHAT ACTUALLY BREAKS ─────────────────────────────────────────────────────
--- `runtime/lua/vim/lsp.lua` attaches ONE `nvim_buf_attach` callback per buffer.
--- It is the only thing that keeps `vim.lsp.util.buf_versions[buf]` equal to the
--- buffer's changedtick, and the only thing that pushes `textDocument/didChange`.
--- Its first lines are:
---
---   on_lines = function(_, _, changedtick, firstline, lastline, new_lastline)
---     if #lsp.get_clients({ bufnr = bufnr }) == 0 then
---       return #lsp.get_clients({ bufnr = bufnr, _uninitialized = true }) == 0
---     end
---     util.buf_versions[bufnr] = changedtick
---
--- Edit a buffer while its last client is gone — a crashed rust-analyzer,
--- `:LspRestart`, `:LspStop` — and that returns `true`, which means "detach me".
--- Two things then conspire:
---
---   1. A buffer callback that detaches itself by returning true does NOT get its
---      `on_detach` called. Verified: on_lines called once, on_detach never fired.
---      So lsp.lua's module-local `attached_buffers[bufnr]` is never cleared.
---   2. When a client attaches again, `buf_attach()` starts with
---      `if attached_buffers[bufnr] then return true end` — so `nvim_buf_attach`
---      is never called again for that buffer.
---
--- The buffer is now permanently unwatched: `buf_versions[buf]` is frozen at
--- whatever it was, and the server stops receiving didChange. Nothing reports it;
--- the editor just quietly drifts out of sync with the server.
---
--- Inlay hints are where it turns into a visible error. The decoration provider
--- guards itself with `if bufstate.version ~= util.buf_versions[bufnr] then
--- return end`, i.e. "only draw hints computed for the buffer as it is now".
--- With buf_versions frozen, that guard is satisfied forever, so hint columns
--- from an older, longer version of a line get handed to nvim_buf_set_extmark,
--- which rejects a column past the end of the line. There is no clamp in
--- inlay_hint.lua — verified by reading it at 0.12.4.
---
--- Reproduced end to end headless (decoration providers do run without a UI) with
--- one in-process server: healthy buf_versions tracks changedtick → stop the
--- client → one edit → buf_versions frozen at 6 while changedtick is 7 → restart
--- the client → shrink a hinted line → the exact error above.
---
--- ── WHAT THIS DOES ───────────────────────────────────────────────────────────
--- Attaches a SECOND buffer callback per LSP buffer that does nothing at all
--- while the runtime's own callback is alive, and takes over the two jobs it
--- dropped if it ever disappears. Detection is exact rather than heuristic:
--- lsp.lua calls `buf_attach()` before firing LspAttach, and buffer callbacks run
--- in registration order (verified), so by the time ours runs the runtime's has
--- already set `buf_versions[buf] = changedtick` — unless it is gone.
---
--- `vim.lsp._changetracking` is private, hence the pcall and the version gate.
---
--- ── WHEN TO REVISIT (NOT SIMPLY DELETE) ──────────────────────────────────────
--- Neovim 0.12.4 is the newest stable (2026-07-05) and the release-0.12 branch
--- still carries both halves. On master, only the SECOND half is fixed: the
--- inlay-hint rewrite in neovim/neovim#40569 (merged 2026-07-05) replaced the one
--- shared `bufstate.version` with per-client state. The first half is unchanged —
--- master's on_lines still returns `#lsp.get_clients({..., _uninitialized = true})
--- == 0`, and `attached_buffers` still guards `buf_attach`. So on 0.13 this stops
--- being a visible error and becomes a silent one: the server keeps working from
--- text you have since edited.
---
--- The gate below therefore turns this off at 0.13 out of caution — the private
--- module it leans on may well have changed shape by then, and misfiring would
--- mean double-sending didChange. Re-test the wedge on 0.13 before trusting it:
--- stop the server, edit the buffer, bring the server back, edit again and check
--- `vim.lsp.util.buf_versions[0] == vim.b.changedtick`. If that is false, lift the
--- gate rather than deleting the file.

local M = {}

--- Buffers we have hooked, so an LspAttach from a second client (or a restarted
--- one) does not stack a second callback.
---@type table<integer, boolean>
local hooked = {}

--- Buffers where the runtime's callback has been observed missing. Kept for
--- diagnosis: `:lua = require("util.lspsync").status()`.
---@type table<integer, boolean>
local repaired = {}

--- @return table<string, any>
function M.status()
  return { hooked = vim.tbl_keys(hooked), repaired = vim.tbl_keys(repaired) }
end

function M.setup()
  -- Fixed upstream: leave 0.13+ alone rather than shadowing whatever it does.
  if vim.fn.has("nvim-0.13") == 1 then
    return
  end

  local ok, changetracking = pcall(require, "vim.lsp._changetracking")
  if not ok then
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("cfg_lspsync", { clear = true }),
    desc = "Keep buf_versions and didChange alive if lsp.lua's buffer callback detaches",
    callback = function(ev)
      local buf = ev.buf
      if hooked[buf] then
        return
      end
      hooked[buf] = true

      vim.api.nvim_buf_attach(buf, false, {
        on_lines = function(_, b, changedtick, firstline, lastline, new_lastline)
          -- Never return a truthy value from here: that is exactly the
          -- self-detach this file exists to compensate for.
          if not vim.api.nvim_buf_is_loaded(b) then
            return
          end
          -- No clients: the runtime's callback is detaching itself right now and
          -- there is nobody to notify. Staying attached is the whole point.
          if #vim.lsp.get_clients({ bufnr = b }) == 0 then
            return
          end
          -- The runtime's callback ran first and did its job. Nothing to do —
          -- this is the path taken on essentially every keystroke.
          if vim.lsp.util.buf_versions[b] == changedtick then
            return
          end

          repaired[b] = true
          vim.lsp.util.buf_versions[b] = changedtick
          -- Same call the runtime makes, with the same arguments, so incremental
          -- sync diffs against the snapshot the last didOpen established.
          pcall(changetracking.send_changes, b, firstline, lastline, new_lastline)
        end,

        on_detach = function(_, b)
          hooked[b] = nil
          repaired[b] = nil
        end,
      })
    end,
  })
end

return M
