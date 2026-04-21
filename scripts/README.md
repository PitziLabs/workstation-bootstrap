# scripts/

Small CLI helpers that are distributed to workstations provisioned by this repo. Files here will be symlinked into `~/.local/bin/` by a bootstrap helper (coming in a follow-up issue).

## Install contract

Files in this directory are installed to `~/.local/bin/` when:

- The file has **no extension** (e.g., `gh-issue`, not `gh-issue.sh`)
- The file has the **executable bit set** (`chmod +x`)

Files with extensions (`.sh`, `.md`, `.bak`, etc.) or without `+x` are ignored. This lets drafts and documentation coexist in the directory without being auto-installed.

## Script header convention

Each script starts with:

- Shebang: `#!/usr/bin/env bash`
- A comment block containing:
  - One-line description
  - Dependencies (external commands expected on `PATH`)
  - Usage example

Example:

```bash
#!/usr/bin/env bash
# gh-issue — Draft GitHub issues without shell-escape drama.
# Dependencies: gh
# Usage: gh-issue <repo> <title> <body-file>
```

## Adding a new script

1. Create `scripts/<name>` — **no file extension**
2. Add the shebang and header comment
3. Write your code
4. `chmod +x scripts/<name>`
5. Commit

The next bootstrap run on any workstation will symlink it into `~/.local/bin/`.

## Available tools

| Tool | Description |
|---|---|
| `gh-issue` | Create GitHub issues without shell-escape drama; see the script header for full usage. |
