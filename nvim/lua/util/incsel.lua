--- ~/.config/nvim/lua/util/incsel.lua
---
--- INCREMENTAL SELECTION — grow and shrink a visual selection along the syntax
--- tree, instead of counting lines or spamming motions.
---
---   <C-space>   select the node under the cursor; press again to select its parent
---   <BS>        step back down to the previous, smaller node
---   <A-space>   jump straight out to the enclosing multi-line construct
---
--- So on `map.insert(String::from("a"), vec![1, 2, 3])`, repeated <C-space> from
--- inside the string gives you: `"a"` → `String::from("a")` → the argument list →
--- the whole call → the statement.
---
--- WHY THIS EXISTS AS LOCAL CODE:
--- nvim-treesitter used to ship `nvim-treesitter.incremental_selection`, and every
--- tutorial online still configures it. That module was REMOVED in the `main`
--- branch rewrite, so those configs now fail with "module not found". Neovim has no
--- built-in replacement, so this is a small reimplementation on top of the public
--- `vim.treesitter` API. About 60 lines, no dependencies.

local M = {}

--- One node stack per buffer. The stack is what makes shrinking possible: we
--- remember the path we expanded through rather than trying to re-derive it.
---@type table<integer, TSNode[]>
local stacks = {}

--- Drop a buffer's stack. Called when the text changes, because a stored node
--- may no longer correspond to anything after an edit.
---@param buf integer?
function M.clear(buf)
  stacks[buf or vim.api.nvim_get_current_buf()] = nil
end

local function in_visual()
  local mode = vim.fn.mode()
  return mode == "v" or mode == "V" or mode == "\22" -- \22 is CTRL-V
end

--- Make `node` the current charwise visual selection.
---@param node TSNode
local function select_node(node)
  local srow, scol, erow, ecol = node:range()

  -- A node that ends at column 0 of a line actually ends at the end of the line
  -- BEFORE it. Selecting to column 0 would include one line too many — this is
  -- the single most common bug in hand-rolled versions of this function.
  if ecol == 0 and erow > srow then
    erow = erow - 1
    local last = vim.api.nvim_buf_get_lines(0, erow, erow + 1, false)[1] or ""
    ecol = #last
  end

  -- Leave any existing visual selection before repositioning, otherwise the
  -- anchor is wrong and the selection grows in the opposite direction.
  if in_visual() then
    vim.cmd([[execute "normal! \<Esc>"]])
  end

  vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
  vim.cmd("normal! v")
  -- End column is exclusive; step back one byte to land on the last character.
  vim.api.nvim_win_set_cursor(0, { erow + 1, math.max(ecol - 1, 0) })
end

---@param a TSNode
---@param b TSNode
local function same_range(a, b)
  local a1, a2, a3, a4 = a:range()
  local b1, b2, b3, b4 = b:range()
  return a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4
end

--- Start a selection at the smallest node under the cursor.
function M.init()
  local node = vim.treesitter.get_node()
  if not node then
    vim.notify(
      "No treesitter node here — is a parser installed for this filetype?\n"
        .. "Check with :checkhealth nvim-treesitter",
      vim.log.levels.WARN,
      { title = "Incremental selection" }
    )
    return
  end
  stacks[vim.api.nvim_get_current_buf()] = { node }
  select_node(node)
end

--- Grow the selection to the enclosing node.
function M.expand()
  local buf = vim.api.nvim_get_current_buf()
  local stack = stacks[buf]

  -- Not in a selection yet (or the stack was invalidated): start one.
  if not stack or #stack == 0 or not in_visual() then
    return M.init()
  end

  local current = stack[#stack]
  local parent = current:parent()

  -- Skip parents that cover exactly the same text. Syntax trees are full of
  -- single-child wrapper nodes, and without this the key appears to do nothing.
  while parent and same_range(current, parent) do
    current = parent
    parent = parent:parent()
  end

  if not parent then
    -- Already at the root of the tree; reselect so the key is never a no-op.
    select_node(stack[#stack])
    return
  end

  table.insert(stack, parent)
  select_node(parent)
end

--- Step back down to the previously selected, smaller node.
function M.shrink()
  local buf = vim.api.nvim_get_current_buf()
  local stack = stacks[buf]
  if not stack or #stack == 0 then
    return
  end
  if #stack > 1 then
    table.remove(stack)
  end
  select_node(stack[#stack])
end

--- Expand until the selection spans more lines than it did — i.e. jump straight
--- out to the enclosing multi-line construct (the block, function or match arm)
--- rather than climbing one node at a time.
---
--- Defined by line span rather than by node type on purpose: a list of
--- "scope-like" node names would need maintaining per language and would be wrong
--- for the next one you add. Line span is language-agnostic and predictable.
function M.expand_scope()
  local buf = vim.api.nvim_get_current_buf()
  if not stacks[buf] or #stacks[buf] == 0 or not in_visual() then
    M.init()
  end
  local stack = stacks[buf]
  if not stack or #stack == 0 then
    return
  end

  local start_row, _, end_row, _ = stack[#stack]:range()
  local start_span = end_row - start_row

  -- Climb until the span grows, with a hard bound so a pathological tree cannot
  -- spin here.
  for _ = 1, 100 do
    local current = stack[#stack]
    local parent = current:parent()
    if not parent then
      break
    end
    table.insert(stack, parent)
    local prow, _, perow, _ = parent:range()
    if (perow - prow) > start_span then
      break
    end
  end

  select_node(stack[#stack])
end

--- Register the keymaps and the invalidation autocmd.
---@param keys { init: string, expand: string, shrink: string, scope: string }
function M.setup(keys)
  vim.keymap.set("n", keys.init, M.init, { desc = "Select node (incremental)" })
  vim.keymap.set("x", keys.expand, M.expand, { desc = "Expand selection to parent node" })
  vim.keymap.set("x", keys.shrink, M.shrink, { desc = "Shrink selection to child node" })
  vim.keymap.set("x", keys.scope, M.expand_scope, { desc = "Expand selection to enclosing scope" })

  -- A stored node is only valid for the tree it came from. Editing the buffer
  -- invalidates the stack, so drop it rather than selecting a stale range.
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertEnter", "BufLeave" }, {
    group = vim.api.nvim_create_augroup("incsel_invalidate", { clear = true }),
    desc = "Invalidate the incremental-selection stack",
    callback = function(ev)
      M.clear(ev.buf)
    end,
  })
end

return M
