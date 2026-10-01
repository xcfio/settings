# সেটিংস (Settings)

[English](README.md) | [বাংলা](README.bn.md)

আমার প্রজেক্টের জন্য ব্যক্তিগত ডেভেলপমেন্ট পরিবেশের সেটিংস এবং কনফিগারেশন।

## সূচিপত্র (Contents)

- [কুইক স্টার্ট](#কুইক-স্টার্ট-powershell)
    - [PowerShell খোলার নিয়ম](#powershell-খোলার-নিয়ম)
    - [ইনস্টল (Install)](#ইনস্টল-install)
- [ম্যানুয়াল কপি পদ্ধতি](#ম্যানুয়াল-কপি-পদ্ধতি)
- [আনইনস্টল](#আনইনস্টল-powershell)
- [প্রয়োজনীয় শর্তাবলী (Prerequisites)](#প্রয়োজনীয়-শর্তাবলী-prerequisites)
- [ফাইলসমূহ (Files)](#ফাইলসমূহ-files)
- [নিয়মাবলী ও কনভেনশন](#নিয়মাবলী-ও-কনভেনশন)
- [কাস্টমাইজেশন](#কাস্টমাইজেশন)
- [সমস্যা সমাধান (Troubleshooting)](#সমস্যা-সমাধান-troubleshooting)
- [লাইসেন্স](#লাইসেন্স)
- [রিসোর্স (Resources)](#রিসোর্স-resources)

## কুইক স্টার্ট (PowerShell)

### PowerShell খোলার নিয়ম

প্রজেক্ট ফোল্ডারে PowerShell ওপেন করার জন্য Windows-এ নিচের যেকোনো পদ্ধতি ব্যবহার করতে পারেন:

- **রান ডায়ালগ (`Win + R`)**: কীবোর্ডে <kbd>Win</kbd> + <kbd>R</kbd> চাপুন, `powershell` (অথবা `pwsh`) লিখে <kbd>Enter</kbd> চাপুন। এরপর প্রজেক্ট ফোল্ডারে যেতে `cd path/to/your-project` লিখুন।
- **ফাইল এক্সপ্লোরার অ্যাড্রেস বার (সবচেয়ে সহজ)**: ফাইল এক্সপ্লোরারে প্রজেক্ট ফোল্ডারটি ওপেন করুন, উপরের অ্যাড্রেস বারে ক্লিক করুন (অথবা <kbd>Alt</kbd> + <kbd>D</kbd> চাপুন), `powershell` বা `pwsh` লিখে <kbd>Enter</kbd> চাপুন। সরাসরি ওই ফোল্ডারেই PowerShell চালু হবে।
- **রাইট-ক্লিক কনটেক্সট মেনু**: প্রজেক্ট ফোল্ডারের খালি জায়গায় রাইট-ক্লিক করুন (অথবা <kbd>Shift</kbd> চেপে রাইট-ক্লিক করুন) এবং **Open in Terminal** বা **Open PowerShell window here** নির্বাচন করুন।
- **পাওয়ার ইউজার মেনু (`Win + X`)**: কীবোর্ডে <kbd>Win</kbd> + <kbd>X</kbd> চাপুন এবং তালিকা থেকে **Terminal** বা **Windows PowerShell** বেছে নিন।
- **VS Code টার্মিনাল**: VS Code-এ প্রজেক্ট ফোল্ডার ওপেন থাকলে <kbd>Ctrl</kbd> + <kbd>`</kbd> (ব্যাকটিক) চাপুন অথবা মেনু থেকে **Terminal** > **New Terminal**-এ যান।
- **স্টার্ট মেনু**: কীবোর্ডে <kbd>Win</kbd> কী চাপুন, `PowerShell` লিখে সার্চ করে <kbd>Enter</kbd> চাপুন।

> **টিপস:** অ্যাডমিনিস্ট্রেটর হিসেবে চালাতে চাইলে রান ডায়ালগে কমান্ড টাইপ করে <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Enter</kbd> চাপুন অথবা রাইট-ক্লিক করে "Run as administrator" বেছে নিন।

### ইনস্টল (Install)

আপনার প্রজেক্ট ফোল্ডারের ভেতরে রান করুন:

```powershell
irm https://raw.githubusercontent.com/xcfio/settings/main/install.ps1 | iex
```

[install.ps1](./install.ps1) যা যা করে:

1. সিস্টেমে পাওয়া গেলে স্বয়ংক্রিয়ভাবে PowerShell Core (`pwsh`) দিয়ে স্ক্রিপ্ট এক্সিকিউট করে।
2. আপনার গ্লোবাল VS Code সেটিংস রিপ্লেস করে (আগের ফাইলটি নিরাপদে `settings.json.bak` হিসেবে ব্যাকআপ থাকে)।
3. প্রস্তাবিত এক্সটেনশনগুলো ইনস্টল করে (গতি বাড়ানোর জন্য ইতোমধ্যে ইনস্টল থাকা এক্সটেনশনগুলো স্কিপ করে, রি-ইনস্টল করতে `-Force` ব্যবহার করুন)।
4. `.prettierrc`, `.gitattributes`, `.gitignore`, `oxlint.config.mts` ডাউনলোড করে এবং `.vscode/settings.json` কনফিগার করে।
5. অপশনাল TypeScript কনফিগ ইনস্টল করার সুবিধা দেয় (`-TsConfig backend` অথবা `-TsConfig frontend`)।

অপশনাল tsconfig (অথবা রান করুন `.\install.ps1 -TsConfig backend` / `frontend`):

```powershell
$base = "https://raw.githubusercontent.com/xcfio/settings/main"
irm "$base/tsconfig-backend.json" -OutFile tsconfig.json
irm "$base/tsconfig-frontend.json" -OutFile tsconfig.json
```

অপশনাল ডেভ টুলিং:

```powershell
pnpm add -D oxlint oxlint-plugin-eslint oxlint-tsgolint prettier typescript turbo lefthook commitlint @commitlint/config-conventional @commitlint/format @commitlint/types
```

> এটি বর্তমান ফোল্ডারের বিদ্যমান ফাইল এবং আপনার গ্লোবাল VS Code সেটিংস ওভাররাইট করে।
> এর জন্য [pnpm](https://pnpm.io), VS Code এবং PATH-এ `code` CLI থাকা প্রয়োজন।

## ম্যানুয়াল কপি পদ্ধতি

আপনি যদি অটোমেটেড ইনস্টল স্ক্রিপ্ট রান না করে ফাইলগুলো নিজে নিজে কপি বা ডাউনলোড করতে চান:

### অপশন A: ক্লোন করা রিপোজিটরি থেকে

1. **রিপোজিটরি ক্লোন করুন:**

    ```bash
    git clone https://github.com/xcfio/settings.git
    cd settings
    ```

2. **গ্লোবাল VS Code সেটিংস কপি করুন:**
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

3. **প্রস্তাবিত এক্সটেনশনসমূহ ইনস্টল করুন:**
    - **PowerShell:**
        ```powershell
        (Get-Content extensions.json -Raw) -replace '(?m)^\s*//.*$', '' | ConvertFrom-Json |
            Select-Object -ExpandProperty recommendations | ForEach-Object { code --install-extension $_ }
        ```
    - **Bash:**
        ```bash
        grep -o '"[^"]*"' extensions.json | grep '\.' | tr -d '"' | xargs -L 1 code --install-extension
        ```

4. **আপনার প্রজেক্ট ফোল্ডারে কনফিগারেশন ফাইলগুলো কপি করুন:**
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

5. **TypeScript টেমপ্লেট কপি করুন (যেকোনো একটি বেছে নিন):**
    - **Backend / Node.js:**
        ```powershell
        Copy-Item tsconfig-backend.json "path/to/your-project/tsconfig.json"
        ```
    - **Frontend / React:**
        ```powershell
        Copy-Item tsconfig-frontend.json "path/to/your-project/tsconfig.json"
        ```

### অপশন B: PowerShell দিয়ে আলাদা আলাদা ফাইল ডাউনলোড (আপনার প্রজেক্ট ফোল্ডারের ভেতর)

```powershell
$base = "https://raw.githubusercontent.com/xcfio/settings/main"

# গ্লোবাল VS Code সেটিংস
irm "$base/settings.json" -OutFile "$env:APPDATA\Code\User\settings.json"

# প্রজেক্ট কনফিগারেশন ফাইলসমূহ
".prettierrc", ".gitattributes", ".gitignore", "oxlint.config.mts" | ForEach-Object { irm "$base/$_" -OutFile $_ }
New-Item -ItemType Directory -Path .vscode -Force | Out-Null
irm "$base/.vscode/settings.json" -OutFile .vscode/settings.json

# TypeScript কনফিগারেশন (যেকোনো একটি বেছে নিন)
irm "$base/tsconfig-backend.json" -OutFile tsconfig.json
# irm "$base/tsconfig-frontend.json" -OutFile tsconfig.json
```

## আনইনস্টল (PowerShell)

সেটিংস, এক্সটেনশন এবং প্রজেক্ট ফাইলগুলো রোলব্যাক বা রিমুভ করতে:

```powershell
irm https://raw.githubusercontent.com/xcfio/settings/main/uninstall.ps1 | iex
```

[uninstall.ps1](./uninstall.ps1) যা যা করে:

1. `settings.json.bak` থেকে গ্লোবাল VS Code সেটিংস রিস্টোর করে (যদি ব্যাকআপ ফাইল থাকে)।
2. সব প্রস্তাবিত এক্সটেনশন আনইনস্টল করে।
3. ডাউনলোড করা প্রজেক্ট কনফিগারেশন ফাইলগুলো (`.prettierrc`, `.gitattributes`, `.gitignore`, `oxlint.config.mts`) মুছে ফেলে এবং `.vscode/settings.json` থেকে `oxc.configPath` সরিয়ে ফেলে।
4. `tsconfig.json.bak` থাকলে আগের মূল `tsconfig.json` ফিরিয়ে আনে।

সাপোর্টেড ফ্ল্যাগসমূহ: `-SkipSettings`, `-SkipExtensions`, `-SkipConfigs`, `-RemoveTsConfig`, `-Force`, `-NoPwsh`।

## প্রয়োজনীয় শর্তাবলী (Prerequisites)

| টুল                                                                                                        | ভার্সন | চেক করার কমান্ড             |
| ---------------------------------------------------------------------------------------------------------- | ------ | --------------------------- |
| [Node.js](https://nodejs.org)                                                                              | 26.x   | `node -v`                   |
| [pnpm](https://pnpm.io)                                                                                    | 12.x   | `pnpm -v`                   |
| [VS Code](https://code.visualstudio.com)                                                                   | Latest | `code --version`            |
| [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows) | 7      | `$PSVersionTable.PSVersion` |

`code` CLI অবশ্যই PATH-এ থাকতে হবে। VS Code ইনস্টলার এটি ডিফল্টভাবেই যোগ করে।

## ফাইলসমূহ (Files)

### VS Code

| ফাইল                    | উদ্দেশ্য                                                                    |
| ----------------------- | --------------------------------------------------------------------------- |
| `settings.json`         | পূর্ণ এডিটর সেটিংস। আপনার গ্লোবাল VS Code ইউজার সেটিংস হিসেবে ইনস্টল হয়।    |
| `extensions.json`       | প্রস্তাবিত এক্সটেনশনসমূহ। `code` CLI-র মাধ্যমে স্বয়ংক্রিয়ভাবে ইনস্টল হয়। |
| `.vscode/settings.json` | ওয়ার্কস্পেস ওভাররাইড, যা Oxc এক্সটেনশনকে `oxlint.config.mts`-এ পয়েন্ট করে। |

**`settings.json`-এর বিশেষ সুবিধাসমূহ**

- ফন্ট: Cascadia Code (এডিটর), Cascadia Mono (টার্মিনাল)
- Prettier দিয়ে Format on save, ফোকাস চেঞ্জে autosave, minimap বন্ধ
- TypeScript নেটিভ প্রিভিউ (`tsgo`) সক্রিয়
- npm প্যাকেজ ম্যানেজার হিসেবে pnpm
- Code Runner: JS-এর জন্য `node --watch`, TS-এর জন্য `tsx watch`, সাথে অন্যান্য অনেক ভাষার সাপোর্ট
- টার্মিনাল: Windows-এ PowerShell, Linux-এ fish
- থিম: Dark Modern, `.css`-এর জন্য Tailwind অ্যাসোসিয়েশন
- JS/TS আউটপুট, লকফাইল এবং SQLite ফাইলের জন্য ফাইল নেস্টিং রুলস

**`extensions.json`-এর বিশেষ সুবিধাসমূহ**

Prettier, Oxc, Tailwind CSS, ArkDark, Error Lens, Pretty TS Errors, TypeScript Native Preview, Conventional Commits, Version Lens, Code Spell Checker, Code Runner, Live Server, GitHub Actions/Codespaces, Expo tools, MDX, Tokyo Night সহ আরো অনেক কিছু।

### ফরম্যাটিং (Formatting)

**`.prettierrc`**

- ৪-স্পেস ইনডেন্ট, ১২০ প্রিন্ট উইডথ
- কোনো সেমিকোলন নেই, ডাবল কোটেশন
- ট্রেইলিং কমা নেই
- সবসময় প্যারেন্থেসিসযুক্ত অ্যারো প্যারামিটার
- CRLF লাইন এন্ডিং

একই ভ্যালুগুলো `settings.json`-এ `prettier.*` এর অধীনে প্রতিফলিত রয়েছে।

### লিন্টিং (Linting)

**`oxlint.config.mts`**

- `oxlint-tsgolint`-এর মাধ্যমে Type-aware লিন্টিং
- প্লাগইন: `node`, `nextjs`, `eslint`, `typescript`, এবং JS প্লাগইন হিসেবে `oxlint-plugin-eslint`
- ক্যাটাগরি `correctness`, `suspicious`, `pedantic`, `perf` সবই `error` হিসেবে সেট করা
- অতিরিক্ত কোলাহলপূর্ণ রুলগুলো নিষ্ক্রিয় করা (`no-explicit-any`, `max-depth`, `no-await-in-loop`, ইত্যাদি)
- অব্যবহৃত ভ্যারিয়েবলগুলোতে সতর্কবার্তা (warn), `_` দিয়ে শুরু হওয়া নামগুলো উপেক্ষিত
- **`Date` সম্পূর্ণ নিষিদ্ধ।** পরিবর্তে Temporal API ব্যবহার করুন (`new Date`, `Date.now()`, `Date.parse()` সবগুলোই এরর হিসেবে ধরবে)
- যেসব ফোল্ডার ইগনোর করা হয়: `node_modules`, `dist`, `.turbo`, `.next`, `.temp`, `out`, `.expo`, `.agents`

### TypeScript

| ফাইল                     | ব্যবহারের ক্ষেত্র                                                                                                                               |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `tsconfig-backend.json`  | Node.js প্রজেক্ট: `NodeNext` মডিউল, `types: ["node"]`, `noEmit`, `strict`, `.ts` ইমপোর্ট অনুমোদিত                                               |
| `tsconfig-frontend.json` | ব্রাউজার/React প্রজেক্ট: `esnext`, DOM লাইব্রেরি, `react-jsx`, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes` |

আপনার প্রজেক্টে ফাইলের নাম পরিবর্তন করে `tsconfig.json` রাখুন।

### Git

| ফাইল             | উদ্দেশ্য                                                                               |
| ---------------- | -------------------------------------------------------------------------------------- |
| `.gitignore`     | Node, বিল্ড আউটপুট, env ফাইল, Next.js, Expo, Turbo, Vercel, Yarn, IDE ফাইল, লগ ইত্যাদি |
| `.gitattributes` | GitHub ল্যাঙ্গুয়েজ পরিসংখ্যানে `.json` গণনা করে, `.xml` এবং `.html` উপেক্ষা করে       |

### রুট টুলিং (Root tooling)

**`package.json`**

- প্যাকেজ ম্যানেজার: `pnpm`
- ডেভ ডিপেন্ডেন্সিসমূহ: `turbo`, `lefthook`, `commitlint` (conventional config), `oxlint` (+ plugin ও tsgolint), `prettier`, `typescript`

## নিয়মাবলী ও কনভেনশন (Conventions)

কনফিগারেশন দ্বারা প্রয়োগকৃত নিয়মাবলী:

- **ফরম্যাটিং (Prettier):** ৪টি স্পেস, ১২০ কলাম, সেমিকোলন ছাড়া, ডাবল কোটস, ট্রেইলিং কমা ছাড়া, CRLF লাইন এন্ডিং।
- **`Date` নিষিদ্ধ:** oxlint `new Date`, `Date.now()`, `Date.parse()` এবং যেকোনো `Date` আইডেন্টিফায়ারে এরর দেয়। Temporal API ব্যবহার করুন।
- **কঠোর লিন্ট ক্যাটাগরি:** `correctness`, `suspicious`, `pedantic`, এবং `perf` সবই `error`। শুধুমাত্র অতিরিক্ত কোলাহলপূর্ণ রুলগুলো বন্ধ করা হয়েছে।
- **অব্যবহৃত ভ্যারিয়েবল:** warn দেখাবে। সাইলেন্স করতে প্রিফিক্স হিসেবে `_` যোগ করুন (`_req`, `_unused`)।
- **কমিট বার্তা:** Conventional Commits অনুসরণ করে (`commitlint` + `@commitlint/config-conventional`)।
- **প্যাকেজ ম্যানেজার:** শুধুমাত্র pnpm।

## কাস্টমাইজেশন (Customization)

- **ভিন্ন ফন্ট ব্যবহার করতে:** `settings.json`-এ `editor.fontFamily` এবং `terminal.integrated.fontFamily` পরিবর্তন করুন।
- **ভিন্ন থিম ব্যবহার করতে:** `workbench.colorTheme` পরিবর্তন করুন।
- **CRLF-এর বদলে LF:** `.prettierrc`-তে `endOfLine` পরিবর্তন করে `"lf"` করুন এবং `settings.json`-এ `prettier.endOfLine` আপডেট করুন।
- **`Date` ব্যবহারের অনুমতি দিতে:** `oxlint.config.mts` থেকে `eslint-js/no-restricted-syntax` ব্লকটি মুছে দিন।
- **কম এক্সটেনশন রাখতে:** ইনস্টল করার আগে `extensions.json` থেকে অপ্রয়োজনীয় লাইনগুলো বাদ দিন।
- **ডিফল্ট টার্মিনাল পরিবর্তন:** `terminal.integrated.defaultProfile.windows` / `.linux` পরিবর্তন করুন।
- **নিজের সেটিংস বজায় রাখতে:** গ্লোবাল সেটিংস ইনস্টল করার ধাপটি এড়িয়ে যান এবং শুধুমাত্র প্রয়োজনীয় কী-গুলো কপি করুন।

## সমস্যা সমাধান (Troubleshooting)

| সমস্যা                                       | সমাধান                                                                                                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` রান করুন।                                                                                         |
| `code : The term 'code' is not recognized`   | "Add to PATH" সিলেক্ট করে VS Code পুনরায় ইনস্টল করুন, অথবা VS Code-এ **Shell Command: Install 'code' command in PATH** রান করে টার্মিনাল রিস্টার্ট দিন। |
| এক্সটেনশন ইনস্টল ব্যর্থ বা স্কিপ হলে         | কি কি ইনস্টল হয়েছে দেখতে `code --list-extensions` রান করুন, এরপর এক্সটেনশন ইনস্টল ধাপটি পুনরায় চেষ্টা করুন।                                             |
| `irm` 404 রিটার্ন করলে                       | ডিফল্ট ব্রাঞ্চ `main` নাও হতে পারে। সঠিক ব্রাঞ্চে `$base` পরিবর্তন করুন।                                                                                |
| পুরোনো সেটিংস ফিরিয়ে আনতে হলে                | `Copy-Item "$env:APPDATA\Code\User\settings.json.bak" "$env:APPDATA\Code\User\settings.json" -Force` কমান্ড দিয়ে রিস্টোর করুন।                          |
| সেভ করার সময় Prettier কাজ না করলে            | নিশ্চিত করুন **Prettier - Code formatter** এক্সটেনশন ইনস্টল করা আছে এবং ডিফল্ট ফরম্যাটার হিসেবে সেট করা আছে।                                            |
| এডিটরে oxlint কাজ না করলে                    | নিশ্চিত করুন **Oxc** এক্সটেনশন ইনস্টল করা আছে এবং `oxc.configPath` পাথটি `oxlint.config.mts`-এ নির্দেশ করছে।                                            |

## লাইসেন্স (License)

MIT — বিস্তারিত তথ্যের জন্য [LICENSE](LICENSE) ফাইলটি দেখুন।

## রিসোর্স (Resources)

| রিসোর্স     | লিঙ্ক                                    |
| ----------- | ---------------------------------------- |
| GitHub      | https://github.com/xcfio/settings        |
| Bug reports | https://github.com/xcfio/settings/issues |
| Help        | https://dsc.gg/xcfio                     |

---

Made with ❤️ by [xcfio](https://github.com/xcfio)
