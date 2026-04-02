# Implementation Guide: Move Repo Cloning Immediately After GitHub CLI Auth

## Problem

On fresh VMs without an active desktop keyring (e.g., Xubuntu before first XFCE login, Fedora without kwallet), `gh auth login --with-token` reports success but silently fails to persist credentials. The scripts currently authenticate in step 10, then clone repos in step 15 — by which time auth is gone. The `hosts.yml` existence check meant to detect this is unreliable.

## Solution

Move the "Clone all GitHub repos" step to immediately follow the "GitHub CLI" step in all three scripts. This eliminates the gap between authentication and consumption. It also eliminates all deferred-clone recovery logic and the `_GH_TOKEN_DEFERRED` flag, since they exist solely to bridge that gap.

## Architectural Principle

**Consume credentials immediately after establishing them.** Don't trust credential persistence across unrelated steps on systems with unknown keyring configurations.

---

## Changes Required

### All three scripts share the same structural change. Apply to each:

- `setup-xubuntu-workstation.sh`
- `setup-fedora-workstation.sh`
- `setup-crostini-lab.sh`

---

## Step 1: Update TOTAL_STEPS (Crostini only)

**File:** `setup-crostini-lab.sh`

The Crostini script currently has `TOTAL_STEPS=14` and no XRDP/Tailscale steps. The total step count does NOT change — we're reordering, not adding/removing steps. No change needed to `TOTAL_STEPS` for any script.

---

## Step 2: Restructure Step 10 — GitHub CLI + Auth + Clone

**Applies to:** All three scripts

The current step 10 (GitHub CLI) should be expanded to include repo cloning immediately after authentication succeeds. This means the clone logic moves UP from its current location into the same step.

### 2a. In the step 10 section, after the existing auth + identity detection block, BEFORE the `GH_TOKEN` clearing logic:

Insert the repo cloning block. This is the entire clone block currently in step 15 (Xubuntu/Fedora) or step 14 (Crostini), moved here verbatim. The block starts with:

```bash
mkdir -p "$REPOS_DIR"
```

...and ends with:

```bash
_REPOS_CLONED=1
```

(On Crostini, the block doesn't set `_REPOS_CLONED` — add it for consistency.)

### 2b. After the clone block, clear GH_TOKEN unconditionally:

Replace the current conditional clearing logic:

```bash
# Clear GH_TOKEN unless we deferred it for the repo-cloning step.
# Leaving GH_TOKEN set can interfere with npm, VS Code, and other tools,
# but without a desktop keyring it's the only way gh stays authenticated.
if [[ "$_GH_TOKEN_DEFERRED" != "true" ]]; then
  unset GH_TOKEN 2>/dev/null || true
fi
```

With a simple unconditional clear:

```bash
# Cloning is done — clear GH_TOKEN so it doesn't interfere with npm,
# VS Code, or other tools that respect GitHub tokens in the environment.
unset GH_TOKEN 2>/dev/null || true
```

### 2c. Remove the `_GH_TOKEN_DEFERRED` flag entirely.

Delete these lines from step 10 (they appear in the auth block):

```bash
_GH_TOKEN_DEFERRED=false
```

And remove the deferred path inside the `gh auth login --with-token` success block. Specifically, delete:

```bash
      # Verify credentials actually persisted to the file-based store.
      # On a fresh install without an active desktop keyring (e.g. XFCE,
      # Crostini), gh may report success but fail to write hosts.yml.
      if [[ ! -s "${XDG_CONFIG_HOME:-$HOME/.config}/gh/hosts.yml" ]]; then
        warn "gh credential store is empty — no desktop keyring available."
        info "Keeping GH_TOKEN in environment until repo cloning is done."
        export GH_TOKEN="$_SAVED_TOKEN"
        _GH_TOKEN_DEFERRED=true
      fi
```

(The Fedora version has slightly different comments referencing kwallet — same deletion applies.)

(The Crostini version checks `gh auth status` instead of `hosts.yml` — same deletion applies.)

Replace the entire `if echo "$_SAVED_TOKEN" | gh auth login --with-token` block with a simpler version that doesn't try to detect credential persistence:

```bash
    _SAVED_TOKEN="$GH_TOKEN"
    unset GH_TOKEN
    if echo "$_SAVED_TOKEN" | gh auth login --with-token 2>&1; then
      # Re-export so gh commands work for the rest of this step.
      # We'll clear it after repo cloning is done.
      export GH_TOKEN="$_SAVED_TOKEN"
    else
      warn "GH_TOKEN authentication failed (bad token? expired? wrong scopes?)."
      info "Continuing without GitHub auth — remaining tools will still install."
      info "After setup, fix with: gh auth login"
      info "Or re-run with a valid token: GH_TOKEN=ghp_xxx bash $(basename "$0")"
    fi
    unset _SAVED_TOKEN
```

The key insight: we no longer care whether credentials persist to disk. We keep `GH_TOKEN` in the environment through the clone step (which happens immediately), then clear it. No persistence check, no deferred flag, no recovery logic.

---

## Step 3: Update the step 10 section header

The section header should reflect that it now includes cloning:

```bash
section "10/$TOTAL_STEPS — GitHub CLI + Clone Repos"
```

Also update the header comment in the script's preamble (the "What this does" list near the top):

**Xubuntu/Fedora** — Change:
```
#  10.  GitHub CLI (gh) + authenticate
...
#  15.  Clone all GitHub repos (auto-detected user)
```
To:
```
#  10.  GitHub CLI (gh) + authenticate + clone repos
```

And renumber all subsequent steps down by one. The new order for Xubuntu:

```
#  10.  GitHub CLI (gh) + authenticate + clone repos
#  11.  VS Code (via Microsoft APT repo)
#  12.  Claude Code
#  13.  Quality-of-life CLI tools
#  14.  Shell config (starship prompt, aliases, PATH wiring)
#  15.  XRDP configuration (remote desktop from Chromebook)
#  16.  Tailscale (mesh VPN)
```

For Fedora (same but RPM repo and KDE references):

```
#  10.  GitHub CLI (gh) + authenticate + clone repos
#  11.  VS Code (via Microsoft RPM repo)
#  12.  Claude Code
#  13.  Quality-of-life CLI tools
#  14.  Shell config (starship prompt, aliases, PATH wiring)
#  15.  XRDP configuration (remote desktop from Chromebook)
#  16.  Tailscale (mesh VPN)
```

**Crostini** — Change:
```
#  10.  GitHub CLI (gh) + authenticate
...
#  14.  Clone all GitHub repos
```
To:
```
#  10.  GitHub CLI (gh) + authenticate + clone repos
```

And renumber:
```
#  10.  GitHub CLI (gh) + authenticate + clone repos
#  11.  VS Code (via Microsoft APT repo)
#  12.  Claude Code
#  13.  Quality-of-life CLI tools
```

Crostini `TOTAL_STEPS` changes from `14` to `13`.

---

## Step 4: Renumber all section headers in the script body

Every `section "N/$TOTAL_STEPS — ..."` call after step 10 needs its number decremented by 1.

**Xubuntu** — `TOTAL_STEPS` changes from `17` to `16`:
- Old step 11 (VS Code) → `11/16 — VS Code`
- Old step 12 (Claude Code) → `12/16 — Claude Code`
- Old step 13 (CLI tools) → `13/16 — Quality-of-Life CLI Tools`
- Old step 14 (Shell config) → `14/16 — Shell Configuration`
- Old step 15 (Clone repos) → **DELETED** (moved into step 10)
- Old step 16 (XRDP) → `15/16 — XRDP Remote Desktop`
- Old step 17 (Tailscale) → `16/16 — Tailscale (mesh VPN)`

**Fedora** — `TOTAL_STEPS` changes from `17` to `16`:
- Same renumbering as Xubuntu above.

**Crostini** — `TOTAL_STEPS` changes from `14` to `13`:
- Old step 11 (VS Code) → `11/13 — VS Code`
- Old step 12 (Claude Code) → `12/13 — Claude Code`  
- Old step 13 (CLI tools) → `13/13 — Quality-of-Life CLI Tools`
- Old step 14 (Clone repos) → **DELETED** (moved into step 10)

Note: Crostini doesn't have shell config, XRDP, or Tailscale as numbered steps — its shell config and Starship setup happen inside step 13.

Wait — actually, let me re-check. The Crostini script has:
- Step 13: Quality-of-life CLI tools (includes shell config and starship within it)
- Step 14: Clone all GitHub repos

So Crostini goes from 14 steps to 13. The step 13 section header stays `13/13`.

---

## Step 5: Delete the old clone step entirely

**Xubuntu/Fedora:** Delete the entire old step 15 section, from:

```bash
# --- 15. Clone all GitHub repos ---------------------------------------------
section "15/$TOTAL_STEPS — Clone All GitHub Repos${GITHUB_USER:+ ($GITHUB_USER)}"
```

Through to (but not including) the next step section header or the `GH_TOKEN` deferred clearing block that follows it.

Also delete the `_GH_TOKEN_DEFERRED` clearing block that comes after the old clone step:

```bash
# Now that repo cloning is done, clear the deferred GH_TOKEN.
if [[ "${_GH_TOKEN_DEFERRED:-}" == "true" ]]; then
  unset GH_TOKEN 2>/dev/null || true
  info "Cleared deferred GH_TOKEN (repo cloning complete)."
fi
```

**Crostini:** Same — delete old step 14 and its trailing `_GH_TOKEN_DEFERRED` block.

---

## Step 6: Delete the deferred clone block at the end of each script

All three scripts have a "Deferred clone (non-interactive recovery)" block after the "Setup Complete!" section. Delete it entirely in all three scripts. It starts with:

```bash
# --- Deferred clone (non-interactive recovery) ---
```

And runs through the end of the `if [[ ! -t 0 ]] && [[ -z "${_REPOS_CLONED:-}" ]]; then` block (the closing `fi`).

This block exists solely as recovery for the credential gap we're eliminating. It's no longer needed.

---

## Step 7: Update the clone section header within step 10

Since repo cloning is now part of step 10 rather than its own numbered step, add a visual sub-header instead of a `section()` call. Inside step 10, before the clone block, add:

```bash
# --- Clone repos (while auth is fresh) ---
info "Cloning repos while GitHub auth is active..."
```

This keeps the output readable without implying it's a separate numbered step.

---

## Step 8: Update `TOTAL_STEPS` variable

- **Xubuntu:** `TOTAL_STEPS=17` → `TOTAL_STEPS=16`
- **Fedora:** `TOTAL_STEPS=17` → `TOTAL_STEPS=16`
- **Crostini:** `TOTAL_STEPS=14` → `TOTAL_STEPS=13`

---

## Step 9: Update the "Installed tools summary" in the completion banner

No changes needed — the summary doesn't reference step numbers.

---

## Step 10: Update README.md

The README has a "What this does" list for each script variant. These should reflect the new step order. The step list in each script's header comment (updated in step 3 above) is the canonical source.

Also update the step count mentioned anywhere in the README if applicable.

---

## Verification

After applying changes, verify with a dry read-through:

1. `TOTAL_STEPS` matches the actual number of `section()` calls
2. Every `section()` call uses sequential numbering with no gaps
3. No references to `_GH_TOKEN_DEFERRED` remain anywhere
4. No "Deferred clone" block remains at the end
5. The `GH_TOKEN` is cleared exactly once, right after clone completes in step 10
6. The old clone step (15 for Xubuntu/Fedora, 14 for Crostini) is fully removed
7. The header comment step list matches the actual step order

## Test plan

Run the Xubuntu script on a fresh VM with `GH_TOKEN=...` passed via environment. Verify:

1. Step 10 installs gh, authenticates, detects identity, and clones repos — all in one step
2. No `[WARN] GitHub CLI not authenticated` appears
3. Personal repos AND org repos (PitziLabs) are cloned
4. Steps 11+ (VS Code, Claude Code, etc.) proceed normally without GH_TOKEN in environment
5. No deferred clone output appears after "Setup Complete!"
