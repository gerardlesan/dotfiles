# `snippets/` — your own snippets

`lua/plugins/completion.lua` loads this directory via LuaSnip's VS Code loader, in
addition to the `friendly-snippets` community collection.

Add one JSON file per filetype, in **VS Code snippet format**:

`snippets/python.json`
```json
{
  "Pytest fixture": {
    "prefix": "fix",
    "body": [
      "@pytest.fixture",
      "def ${1:name}():",
      "    ${2:yield}"
    ],
    "description": "A pytest fixture"
  }
}
```

- `$1`, `$2`, … are tab stops; `$0` is where the cursor ends up.
- `${1:default}` gives a placeholder you can type over.
- `${1|a,b,c|}` offers a choice list.
- `$TM_FILENAME_BASE`, `$CURRENT_YEAR` and the other VS Code variables work.

Then register the file in `package.json` beside it:

```json
{
  "name": "my-snippets",
  "contributes": {
    "snippets": [
      { "language": "python", "path": "./python.json" }
    ]
  }
}
```

Reload with `:Lazy reload LuaSnip`, or restart. Snippets appear in the completion
menu tagged as coming from the `snippets` source.

> Note: LuaSnip's `jsregexp` build step is deliberately **not** enabled in this
> config (see the comment in `lua/plugins/completion.lua`). It needs a compiler,
> fails often on Windows, and only affects regex *transformations* inside snippets —
> everything above works without it.
