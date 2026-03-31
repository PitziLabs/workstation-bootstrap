# Bug Fix: stdin consumption kills script in `curl | bash` mode

## Background
When these scripts run via `curl -sL <url> | bash`, bash reads the script
from stdin. Any command that also reads from stdin will consume bytes of the
script itself, causing bash to lose its place and silently exit. Commands
that are fed by their own pipe (like `curl ... | sh`) are safe because the
inner process reads from the pipe, not from the parent's stdin.

## File 1: `setup-fedora-workstation.sh`

### Fix 1 — `ausearch` in step 16 (XRDP SELinux)

The `sudo ausearch` command reads from stdin when no file argument is given.
In `curl | bash` mode, it drinks the script stream and the script dies.

Find this line in the SELinux audit2allow block in step 16:

```bash
    XRDP_DENIALS=$(sudo ausearch -m avc -ts recent 2>/dev/null | grep xrdp 2>/dev/null || true)
```

Replace with:

```bash
    XRDP_DENIALS=$(sudo ausearch -m avc -ts recent < /dev/null 2>/dev/null | grep xrdp 2>/dev/null || true)
```

### Fix 2 — `fzf install` in step 13 (defensive)

The fzf installer script may read from stdin internally. The `--no-*` flags
suppress most prompts but `< /dev/null` prevents any residual reads.

Find:

```bash
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-zsh --no-fish
```

Replace with:

```bash
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-zsh --no-fish < /dev/null
```

## File 2: `setup-xubuntu-workstation.sh`

### Fix 3 — `fzf install` in step 13 (defensive, same as above)

Find:

```bash
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-zsh --no-fish
```

Replace with:

```bash
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-zsh --no-fish < /dev/null
```

## File 3: `setup-crostini-lab.sh`

### Fix 4 — `fzf install` in step 12 or 13 (defensive, same as above)

Find:

```bash
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-zsh --no-fish
```

Replace with:

```bash
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-zsh --no-fish < /dev/null
```

## Why `< /dev/null` and not other approaches

Redirecting stdin from `/dev/null` is the standard fix for commands that
shouldn't read from stdin. It's explicit, grep-able, and doesn't change
the command's behavior — it just closes the door on accidental reads.
The alternative (saving stdin to a file descriptor at script start) is
heavier than needed for a handful of commands.

## What NOT to fix

These `curl ... | sh` patterns are safe — curl feeds stdin via pipe:
- `curl -fsSL https://starship.rs/install.sh | sh -s -- -y`
- `curl -fsSL .../nvm/.../install.sh | PROFILE=/dev/null bash`
- `curl -fsSL https://tailscale.com/install.sh | sh`
- `curl -fsSL .../terraform-switcher/.../install.sh | sudo bash`

Do NOT add `< /dev/null` to these — it would break them by replacing
their piped input with nothing.

## Scope
Four changes across three files. No other modifications needed. Each is a
single-line edit adding `< /dev/null` before the existing redirects.

## Verify
After fixing, test the Fedora script in pipe mode:
```bash
curl -sL https://raw.githubusercontent.com/PitziLabs/workstation-bootstrap/main/setup-fedora-workstation.sh | GH_TOKEN=ghp_xxx bash
```
Confirm steps 16 and 17 both complete and the "Setup Complete" banner prints.
