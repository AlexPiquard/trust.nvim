# trust.nvim

A small Neovim plugin that blocks language servers from starting in projects you haven't explicitly **trusted** (a whitelist).

Opening a project that runs a build or a language server can execute arbitrary code. This plugin makes sure you only run LSP tooling in projects you've chosen to trust, so a fraudulent repository can't silently build or check your code.

Each project is identified by its root (detected via `.git`, `package.json`, `Cargo.toml`, etc.). If a project isn't on the trust list, no LSP starts and you get a notification prompting you to trust it.

## Features

- Persistent whitelist of trusted projects.
- Blocks LSP servers for untrusted projects.
- Notifications when an untrusted project tries to start an LSP.
- `:Trust` / `:Untrust` commands to manage the list.

## Requirements

- Neovim **0.10+**

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "AlexPiquard/trust.nvim",
  opts = {}
}
```

<details>
<summary>With <a href="https://neovim.io/doc/user/pack/#vim.pack">vim.pack</a></summary>

```lua
vim.pack.add({
  {
    src = "https://github.com/AlexPiquard/trust.nvim",
  },
})
```

</details>

## Usage

Register the servers to enable via `setup_lsp`, for example in a config-sourcing file (`after/plugin/` or an `autocmd` after your LSP config):

```lua
require("trust").setup_lsp({ "lua_ls", "rust_analyzer" })
```

- If the current project is trusted → the listed servers are enabled.
- Otherwise → you get a warning: LSP stays disabled until you run:

```vim
:Trust    " trust the current project and enable LSP
:Untrust  " remove trust and stop LSP clients for the root
```

## API

| Function | Description |
| --- | --- |
| `require("trust").setup_lsp(servers)` | Register the servers to enable; enables them or notifies depending on the current project's trust status. |
| `require("trust").root([bufnr])` | Return the project root (or that of the buffer). |
| `require("trust").is_trusted([root])` | `true` if the root is trusted. |
| `require("trust").trust([root])` | Add the root to the whitelist and enable LSP. |
| `require("trust").untrust([root])` | Remove the root from the whitelist and stop LSP clients for that root. |
| `require("trust").enable()` | Enable the registered servers. |
| `require("trust").disable([root])` | Stop LSP clients attached to the root. |

## License

[MIT](LICENSE)
