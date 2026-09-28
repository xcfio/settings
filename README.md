# Settings

[English](README.md) | [বাংলা](README.bn.md)

Personal dev environment config: VS Code, Prettier, oxlint, TypeScript, and monorepo tooling.

## Contents

- [Quick start](#quick-start-powershell)
- [Manual copy method](#manual-copy-method)
- [Uninstall](#uninstall-powershell)
- [Prerequisites](#prerequisites)
- [Files](#files)
- [Conventions](#conventions)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Resources](#resources)

## Quick start (PowerShell)

Run inside your project folder:

```powershell
iwr https://raw.githubusercontent.com/xcfio/settings/main/install.ps1 | iex
```

What [install.ps1](./install.ps1) does:

1. Automatically upgrades execution to PowerShell Core (`pwsh`) if available.
2. Replaces your global VS Code settings (existing file safely backed up as `settings.json.bak`).
3. Installs recommended extensions (skips already installed extensions for speed, use `-Force` to reinstall).
4. Downloads `.prettierrc`, `.gitattributes`, `.gitignore`, `oxlint.config.mts`, and configures `.vscode/settings.json`.
5. Optionally installs TypeScript config (`-TsConfig backend` or `-TsConfig frontend`).

Optional tsconfig (or run `.\install.ps1 -TsConfig backend` / `frontend`):

```powershell
$base = "https://raw.githubusercontent.com/xcfio/settings/main"
iwr "$base/tsconfig-backend.json" -OutFile tsconfig.json
iwr "$base/tsconfig-fronend.json" -OutFile tsconfig.json
```

Optional dev tooling:

```powershell
pnpm add -D oxlint oxlint-plugin-eslint oxlint-tsgolint prettier typescript turbo lefthook commitlint @commitlint/config-conventional @commitlint/format @commitlint/types
```

> Overwrites existing files in the current folder and your global VS Code settings.
> Requires [pnpm](https://pnpm.io), VS Code, and the `code` CLI on PATH.

## Manual copy method

If you prefer to copy or download files individually without running the automated install script:

### Option A: From a cloned repository

1. **Clone the repository:**
   ```bash
   git clone https://github.com/xcfio/settings.git
   cd settings
   ```

2. **Copy global VS Code settings:**
   - **Windows (PowerShell):**
     ```powershell
     Copy-Item settings.json "$env:APPDATA\Code\User\settings.json" -Force
     ```
   - **macOS:**
     ```bash
     cp settings.json "$HOME/Library/Application Support/Code/User/settings.json"
     ```
   - **Linux:**
     ```bash
     cp settings.json "$HOME/.config/Code/User/settings.json"
     ```

3. **Install recommended extensions:**
   - **PowerShell:**
     ```powershell
     (Get-Content extensions.json -Raw) -replace '(?m)^\s*//.*$', '' | ConvertFrom-Json |
         Select-Object -ExpandProperty recommendations | ForEach-Object { code --install-extension $_ }
     ```
   - **Bash:**
     ```bash
     grep -o '"[^"]*"' extensions.json | grep '\.' | tr -d '"' | xargs -L 1 code --install-extension
     ```

4. **Copy project configuration files to your project folder:**
   - **PowerShell:**
     ```powershell
     $target = "path/to/your-project"
     Copy-Item .prettierrc, .gitattributes, .gitignore, oxlint.config.mts "$target/"
     New-Item -ItemType Directory -Path "$target/.vscode" -Force | Out-Null
     Copy-Item .vscode/settings.json "$target/.vscode/settings.json"
     ```
   - **Bash:**
     ```bash
     TARGET="path/to/your-project"
     cp .prettierrc .gitattributes .gitignore oxlint.config.mts "$TARGET/"
     mkdir -p "$TARGET/.vscode"
     cp .vscode/settings.json "$TARGET/.vscode/settings.json"
     ```

5. **Copy TypeScript template (pick one):**
   - **Backend / Node.js:**
     ```powershell
     Copy-Item tsconfig-backend.json "path/to/your-project/tsconfig.json"
     ```
   - **Frontend / React:**
     ```powershell
     Copy-Item tsconfig-fronend.json "path/to/your-project/tsconfig.json"
     ```

### Option B: Download individually via PowerShell (inside your project folder)

```powershell
$base = "https://raw.githubusercontent.com/xcfio/settings/main"

# Global VS Code settings
iwr "$base/settings.json" -OutFile "$env:APPDATA\Code\User\settings.json"

# Project configuration files
".prettierrc", ".gitattributes", ".gitignore", "oxlint.config.mts" | ForEach-Object { iwr "$base/$_" -OutFile $_ }
New-Item -ItemType Directory -Path .vscode -Force | Out-Null
iwr "$base/.vscode/settings.json" -OutFile .vscode/settings.json

# TypeScript configuration (pick one)
iwr "$base/tsconfig-backend.json" -OutFile tsconfig.json
# iwr "$base/tsconfig-fronend.json" -OutFile tsconfig.json
```

## Uninstall (PowerShell)

Roll back settings, extensions, and project files:

```powershell
iwr https://raw.githubusercontent.com/xcfio/settings/main/uninstall.ps1 | iex
```

What [uninstall.ps1](./uninstall.ps1) does:

1. Restores global VS Code settings from `settings.json.bak` (if backup exists).
2. Uninstalls all recommended extensions.
3. Removes downloaded project configuration files (`.prettierrc`, `.gitattributes`, `.gitignore`, `oxlint.config.mts`) and cleans up `oxc.configPath` from `.vscode/settings.json`.
4. Restores original `tsconfig.json` from `tsconfig.json.bak` if present.

Flags supported: `-SkipSettings`, `-SkipExtensions`, `-SkipConfigs`, `-RemoveTsConfig`, `-Force`, `-NoPwsh`.

## Prerequisites

| Tool                                                                                                       | Version | Check                       |
| ---------------------------------------------------------------------------------------------------------- | ------- | --------------------------- |
| [Node.js](https://nodejs.org)                                                                              | 26.x    | `node -v`                   |
| [pnpm](https://pnpm.io)                                                                                    | 12.x    | `pnpm -v`                   |
| [VS Code](https://code.visualstudio.com)                                                                   | Latest  | `code --version`            |
| [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows) | 7       | `$PSVersionTable.PSVersion` |

The `code` CLI must be on PATH. The VS Code installer adds it by default.

## Files

### VS Code

| File                    | Purpose                                                                  |
| ----------------------- | ------------------------------------------------------------------------ |
| `settings.json`         | Full editor settings. Installed as your global VS Code user settings.    |
| `extensions.json`       | Recommended extensions. Installed automatically via the `code` CLI.      |
| `.vscode/settings.json` | Workspace override that points the Oxc extension to `oxlint.config.mts`. |

**`settings.json` highlights**

- Font: Cascadia Code (editor), Cascadia Mono (terminal)
- Format on save with Prettier, autosave on focus change, minimap off
- TypeScript native preview (`tsgo`) enabled
- pnpm as the npm package manager
- Code Runner: `node --watch` for JS, `tsx watch` for TS, plus many other languages
- Terminal: PowerShell on Windows, fish on Linux
- Theme: Dark Modern, Tailwind association for `.css`
- File nesting rules for JS/TS outputs, lockfiles, and SQLite files

**`extensions.json` highlights**

Prettier, Oxc, Tailwind CSS, ArkDark, Error Lens, Pretty TS Errors, TypeScript Native Preview, Conventional Commits, Version Lens, Code Spell Checker, Code Runner, Live Server, GitHub Actions/Codespaces, Expo tools, MDX, Tokyo Night, and more.

### Formatting

**`.prettierrc`**

- 4-space indent, 120 print width
- No semicolons, double quotes
- No trailing commas
- Always-parenthesized arrow params
- CRLF line endings

The same values are mirrored in `settings.json` under `prettier.*`.

### Linting

**`oxlint.config.mts`**

- Type-aware linting via `oxlint-tsgolint`
- Plugins: `node`, `nextjs`, `eslint`, `typescript`, plus `oxlint-plugin-eslint` as a JS plugin
- Categories `correctness`, `suspicious`, `pedantic`, `perf` all set to `error`
- Noisy rules disabled (`no-explicit-any`, `max-depth`, `no-await-in-loop`, etc.)
- Unused vars warn, `_`-prefixed names ignored
- **`Date` is banned.** Use the Temporal API instead (`new Date`, `Date.now()`, `Date.parse()` all error)
- Ignores `node_modules`, `dist`, `.turbo`, `.next`, `.temp`, `out`, `.expo`, `.agents`

### TypeScript

| File                    | Use for                                                                                                                                   |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `tsconfig-backend.json` | Node.js projects: `NodeNext` modules, `types: ["node"]`, `noEmit`, `strict`, `.ts` imports allowed                                        |
| `tsconfig-fronend.json` | Browser/React projects: `esnext`, DOM libs, `react-jsx`, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes` |

Rename to `tsconfig.json` in your project.

### Git

| File             | Purpose                                                                             |
| ---------------- | ----------------------------------------------------------------------------------- |
| `.gitignore`     | Node, build outputs, env files, Next.js, Expo, Turbo, Vercel, Yarn, IDE files, logs |
| `.gitattributes` | Counts `.json` in GitHub language stats, ignores `.xml` and `.html`                 |

### Root tooling

**`package.json`**

- Package manager: `pnpm`
- Dev dependencies: `turbo`, `lefthook`, `commitlint` (conventional config), `oxlint` (+ plugin and tsgolint), `prettier`, `typescript`

## Conventions

Rules enforced by the configs:

- **Formatting (Prettier):** 4 spaces, 120 columns, no semicolons, double quotes, no trailing commas, CRLF line endings.
- **No `Date`.** oxlint errors on `new Date`, `Date.now()`, `Date.parse()`, and any `Date` identifier. Use the Temporal API.
- **Strict lint categories.** `correctness`, `suspicious`, `pedantic`, and `perf` are all `error`. Only rules that were too noisy are switched off.
- **Unused variables** warn. Prefix with `_` to silence (`_req`, `_unused`).
- **Commits** follow Conventional Commits (`commitlint` + `@commitlint/config-conventional`).
- **Package manager** is pnpm only.

## Customization

- **Different font:** change `editor.fontFamily` and `terminal.integrated.fontFamily` in `settings.json`.
- **Different theme:** change `workbench.colorTheme`.
- **LF instead of CRLF:** set `endOfLine` to `"lf"` in `.prettierrc` and `prettier.endOfLine` in `settings.json`.
- **Allow `Date`:** remove the `eslint-js/no-restricted-syntax` block from `oxlint.config.mts`.
- **Fewer extensions:** delete lines from `extensions.json` before running the install step.
- **Default terminal:** change `terminal.integrated.defaultProfile.windows` / `.linux`.
- **Keep your own settings:** skip the global settings step and copy only the keys you want.

## Troubleshooting

| Problem                                      | Fix                                                                                                                                      |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`                                                                                    |
| `code : The term 'code' is not recognized`   | Reinstall VS Code with "Add to PATH" checked, or in VS Code run **Shell Command: Install 'code' command in PATH**. Restart the terminal. |
| Extension install fails or is skipped        | Run `code --list-extensions` to see what installed, then retry the extension step.                                                       |
| `iwr` returns 404                            | The default branch is not `main`. Change `$base` to the correct branch.                                                                  |
| Old settings needed back                     | Restore with `Copy-Item "$env:APPDATA\Code\User\settings.json.bak" "$env:APPDATA\Code\User\settings.json" -Force`                        |
| Prettier not formatting on save              | Confirm **Prettier - Code formatter** is installed and set as default formatter.                                                         |
| oxlint not running in editor                 | Confirm the **Oxc** extension is installed and `oxc.configPath` points to `oxlint.config.mts`.                                           |

## License

MIT — see [LICENSE](LICENSE) for details.

## Resources

| Resource    | URL                                      |
| ----------- | ---------------------------------------- |
| GitHub      | https://github.com/xcfio/settings        |
| Bug reports | https://github.com/xcfio/settings/issues |
| Help        | https://dsc.gg/xcfio                     |

---

Made with ❤️ by [xcfio](https://github.com/xcfio)
