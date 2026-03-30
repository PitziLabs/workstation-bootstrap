#!/usr/bin/env bash
# ============================================================================
# PATCH GUIDE: org config + Tailscale for workstation-bootstrap
# ============================================================================
#
# Apply to: setup-crostini-lab.sh, setup-xubuntu-workstation.sh,
#           setup-fedora-workstation.sh
#
# New file:  config  →  ~/.config/workstation-bootstrap/config
#            (template ships separately; bootstrap creates it on first run)
#
# DESIGN PRINCIPLES:
#   - The bootstrap scripts NEVER hardcode an org name. They reference
#     $GITHUB_ORG and $GITHUB_DEFAULT_OWNER only.
#   - Tailscale is installed and enabled but NOT authenticated. The user
#     runs `tailscale up` post-bootstrap (same pattern as AWS, gh, claude).
#
# This is NOT an executable script. It's a structured reference for applying
# 10 zones of changes to each bootstrap script.
#
# Fastest path: download this file into your repo, then in Claude Code:
#   "Read PATCH-GUIDE.sh and apply it to all three setup scripts"
#
# ============================================================================
#
# WHAT THIS ADDS:
#
#   Org config (Zones 1–6):
#   - ~/.config/workstation-bootstrap/config — user config file, created on
#     first run with commented-out placeholder values
#   - GITHUB_ORG env var — clone org repos alongside personal repos
#   - GITHUB_DEFAULT_OWNER env var — default owner for gh repo create
#   - ghnew / ghclone aliases — wired to GITHUB_DEFAULT_OWNER
#   - Preflight output shows org setting
#   - Summary output shows org + config path
#   - Fully backward-compatible: empty GITHUB_ORG = original behavior
#
#   Tailscale (Zones 7–8):
#   - Tailscale installed via official repo (APT for Crostini/Xubuntu,
#     DNF for Fedora)
#   - Service enabled but not authenticated
#   - Post-install checklist updated
#   - Enables secure RDP/SSH from Chromebook without exposing ports
#
#   Housekeeping (Zone 9):
#   - TOTAL_STEPS bumped by 1 in each script
#   - All subsequent step numbers shift accordingly
#
#   Bugfix (Zone 10):
#   - Starship: move scan_timeout from [directory] section to top-level
#   - Was causing "[WARN] Unknown key" on every shell login
#
# ============================================================================


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 1 — Config variables + source config file                        ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# ANCHOR: Find this line (exists in all three):
#   GIT_EMAIL="${GIT_EMAIL:-}"
#
# INSERT AFTER that line (before the blank line / INTERACTIVE detection):

# --- Workstation config (personal overrides) --------------------------------
# Source user config if it exists. This lets you set GITHUB_ORG,
# GITHUB_DEFAULT_OWNER, and future preferences without editing the script.
WS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/workstation-bootstrap/config"
GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_DEFAULT_OWNER="${GITHUB_DEFAULT_OWNER:-}"

if [[ -f "$WS_CONFIG" ]]; then
  # shellcheck source=/dev/null
  . "$WS_CONFIG"
fi


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 2 — Create config template on first run                          ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# ANCHOR: Find this line (exists in all three):
#   sudo -v
#
# INSERT AFTER "sudo -v" (still inside the Preflight section):

# --- Create workstation config template if it doesn't exist ---
WS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/workstation-bootstrap"
if [[ ! -f "$WS_CONFIG_DIR/config" ]]; then
  mkdir -p "$WS_CONFIG_DIR"
  cat > "$WS_CONFIG_DIR/config" << 'WS_CONF'
# ============================================================================
# Workstation bootstrap config — sourced by setup-*-workstation.sh scripts
# Location: ~/.config/workstation-bootstrap/config
#
# This file personalizes your workstation without modifying the bootstrap
# scripts themselves. The scripts stay portable; your preferences live here.
# Re-running any bootstrap script will NOT overwrite this file.
# ============================================================================

# --- GitHub org to clone alongside personal repos --------------------------
# Set this to also clone all repos from a GitHub organization during
# bootstrap. Leave empty to only clone your personal repos.
# The bootstrap script clones BOTH personal and org repos when set.
#GITHUB_ORG=""

# --- Default owner for new repos ------------------------------------------
# Used by the 'ghnew' alias to default gh repo create to this owner.
# Leave empty to default to your personal account.
#GITHUB_DEFAULT_OWNER=""
WS_CONF
  info "Created workstation config at $WS_CONFIG_DIR/config"
  info "Edit this file to set your GitHub org and other preferences."
fi


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 3 — Update preflight info output to show org                     ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# FIND (Xubuntu + Fedora):
#   info "GitHub user: ${GITHUB_USER:-<will auto-detect>} | Repos dir: $REPOS_DIR"
# REPLACE WITH:
#   info "GitHub user: ${GITHUB_USER:-<will auto-detect>} | Org: ${GITHUB_ORG:-<none>} | Repos dir: $REPOS_DIR"
#
# FIND (Crostini — uses bare variable):
#   info "GitHub user: $GITHUB_USER | Repos dir: $REPOS_DIR"
# REPLACE WITH:
#   info "GitHub user: ${GITHUB_USER:-<will auto-detect>} | Org: ${GITHUB_ORG:-<none>} | Repos dir: $REPOS_DIR"


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 4 — Clone org repos after personal repos                         ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# ANCHOR: Find this line in the clone step (step 15 in Crostini,
# step 15 in Xubuntu/Fedora — will become step 16 after Zone 9):
#     info "Repos: $CLONE_COUNT cloned, $SKIP_COUNT already present, $FAIL_COUNT failed"
#   fi
# else
#
# REPLACE the "info Repos:" line AND the "fi" that closes the REPO_LIST
# block with the expanded block below. The "else" line that follows
# should remain unchanged.
#
# Note: indentation is 4 spaces (inside the "if gh auth status" block).

    info "Repos ($GITHUB_USER): $CLONE_COUNT cloned, $SKIP_COUNT already present, $FAIL_COUNT failed"

    # --- Clone org repos (if GITHUB_ORG is set) ---
    if [[ -n "${GITHUB_ORG:-}" ]] && [[ "$GITHUB_ORG" != "$GITHUB_USER" ]]; then
      echo ""
      info "Fetching repo list for org: $GITHUB_ORG..."

      ORG_REPO_LIST=$(gh repo list "$GITHUB_ORG" --limit 200 --json name,isPrivate \
        --jq '.[] | "\(.name)\t\(.isPrivate)"' 2>/dev/null) || true

      if [[ -z "${ORG_REPO_LIST:-}" ]]; then
        warn "No repos found for $GITHUB_ORG (or no access / API rate limited)."
      else
        ORG_CLONE_COUNT=0
        ORG_SKIP_COUNT=0
        ORG_FAIL_COUNT=0

        while IFS=$'\t' read -r REPO_NAME IS_PRIVATE; do
          DEST="$REPOS_DIR/$REPO_NAME"

          if [[ -d "$DEST" ]]; then
            skip "$REPO_NAME (already cloned)"
            ((ORG_SKIP_COUNT++)) || true
          else
            PRIVATE_TAG=""
            [[ "$IS_PRIVATE" == "true" ]] && PRIVATE_TAG=" 🔒"

            HTTPS_URL="https://github.com/${GITHUB_ORG}/${REPO_NAME}.git"
            if git clone --quiet "$HTTPS_URL" "$DEST" 2>/dev/null; then
              success "$REPO_NAME${PRIVATE_TAG} (${GITHUB_ORG})"
              ((ORG_CLONE_COUNT++)) || true
            else
              warn "Failed to clone $GITHUB_ORG/$REPO_NAME"
              ((ORG_FAIL_COUNT++)) || true
            fi
          fi
        done <<< "$ORG_REPO_LIST"

        echo ""
        info "Org repos ($GITHUB_ORG): $ORG_CLONE_COUNT cloned, $ORG_SKIP_COUNT already present, $ORG_FAIL_COUNT failed"
      fi
    fi
  fi
# ← the "else" / "warn GitHub CLI not authenticated" line follows unchanged


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 5 — Bashrc block additions                                       ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# Two insertions inside the BASHRC_BLOCK heredoc:
#
# ── 5a: Source config file ──
# ANCHOR: Find the PATH export line inside the heredoc:
#   export PATH="$HOME/.local/bin:$HOME/bin:$HOME/go/bin:/usr/local/go/bin:$PATH"
#
# INSERT AFTER it (before the "# --- nvm ---" line):

# --- Workstation config ---
WS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/workstation-bootstrap/config"
[[ -f "$WS_CONFIG" ]] && . "$WS_CONFIG"

# ── 5b: GitHub org aliases ──
# ANCHOR: Find this line inside the heredoc:
#   # --- Aliases: safety nets ---
#
# INSERT BEFORE it:

# --- Aliases: GitHub org ---
if [[ -n "${GITHUB_DEFAULT_OWNER:-}" ]]; then
  alias ghnew='gh repo create --owner "$GITHUB_DEFAULT_OWNER"'
  alias ghclone='gh repo clone "$GITHUB_DEFAULT_OWNER"/'
fi


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 6 — Summary section updates                                      ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# ── 6a: Add config line ──
# ANCHOR: Find the "Your code:" echo line near the bottom.
# INSERT BEFORE it:
echo "  Config:       ~/.config/workstation-bootstrap/config (org: ${GITHUB_ORG:-<none>})"
#
# ── 6b: Replace "Your code" line ──
# FIND (Xubuntu + Fedora):
#   echo "  Your code:    ~/repos/ (all ${GITHUB_USER:-<configure gh>} repos)"
# FIND (Crostini):
#   echo "  Your code:    ~/repos/ (all $GITHUB_USER repos)"
#
# REPLACE WITH (same for all three):
if [[ -n "${GITHUB_ORG:-}" ]]; then
  echo "  Your code:    ~/repos/ (${GITHUB_USER:-<configure gh>} + ${GITHUB_ORG} repos)"
else
  echo "  Your code:    ~/repos/ (all ${GITHUB_USER:-<configure gh>} repos)"
fi


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 7 — Tailscale install step                                       ║
# ║ Apply to: ALL THREE SCRIPTS (with distro-specific install commands)    ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# ADD AS A NEW STEP. Insert AFTER the XRDP step in Xubuntu/Fedora (current
# step 16), or after the clone step in Crostini (current step 15).
# This becomes the NEW LAST NUMBERED STEP before the summary.
#
# The step number depends on the script:
#   - Crostini:  step 16 (was 15 steps, now 16)
#   - Xubuntu:   step 17 (was 16 steps, now 17)
#   - Fedora:    step 17 (was 16 steps, now 17)
#
# ── 7a: Crostini version (APT, Debian) ──

section "$TOTAL_STEPS/$TOTAL_STEPS — Tailscale (mesh VPN)"

if ! command_exists tailscale; then
  info "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if command_exists tailscale; then
  success "Tailscale installed."
  if ! tailscale status &>/dev/null; then
    info "Run 'sudo tailscale up' to authenticate and join your tailnet."
  else
    success "Tailscale is connected: $(tailscale ip -4 2>/dev/null || echo '<run tailscale up>')"
  fi
else
  warn "Tailscale install failed. Install manually: https://tailscale.com/download/linux"
fi

# ── 7b: Xubuntu version (APT, Ubuntu) ──
# Same as Crostini — Tailscale's install.sh auto-detects the distro.

section "$TOTAL_STEPS/$TOTAL_STEPS — Tailscale (mesh VPN)"

if ! command_exists tailscale; then
  info "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if command_exists tailscale; then
  sudo systemctl enable --now tailscaled
  success "Tailscale installed and service enabled."
  if ! tailscale status &>/dev/null; then
    info "Run 'sudo tailscale up' to authenticate and join your tailnet."
    info "Then connect via RDP from your Chromebook using the Tailscale IP."
  else
    success "Tailscale is connected: $(tailscale ip -4 2>/dev/null || echo '<run tailscale up>')"
  fi
else
  warn "Tailscale install failed. Install manually: https://tailscale.com/download/linux"
fi

# ── 7c: Fedora version (DNF) ──
# Tailscale's install.sh also works on Fedora, but we can use the DNF repo
# directly for consistency with how the rest of the Fedora script works.

section "$TOTAL_STEPS/$TOTAL_STEPS — Tailscale (mesh VPN)"

if ! command_exists tailscale; then
  info "Installing Tailscale..."
  # Tailscale's universal installer handles Fedora correctly.
  # Using it instead of manually adding the DNF repo keeps the install
  # path consistent across all three scripts.
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if command_exists tailscale; then
  sudo systemctl enable --now tailscaled
  success "Tailscale installed and service enabled."

  # Open firewall for Tailscale if firewalld is running
  if command_exists firewall-cmd && sudo firewall-cmd --state &>/dev/null; then
    # Tailscale creates its own interface (tailscale0). Adding it to the
    # trusted zone means traffic over the tailnet is unrestricted — which
    # is the right default since Tailscale handles its own auth and ACLs.
    sudo firewall-cmd --permanent --zone=trusted --add-interface=tailscale0 2>/dev/null || true
    sudo firewall-cmd --reload
    info "Added tailscale0 to firewalld trusted zone."
  fi

  if ! tailscale status &>/dev/null; then
    info "Run 'sudo tailscale up' to authenticate and join your tailnet."
    info "Then connect via RDP from your Chromebook using the Tailscale IP."
  else
    success "Tailscale is connected: $(tailscale ip -4 2>/dev/null || echo '<run tailscale up>')"
  fi
else
  warn "Tailscale install failed. Install manually: https://tailscale.com/download/linux"
fi


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 8 — Update summary and post-install checklist for Tailscale      ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# ── 8a: Add to post-install checklist ──
# ANCHOR: Find the "Run 'claude' to authenticate Claude Code" line in the
# post-install checklist.
# INSERT AFTER it:
echo "  • Run 'sudo tailscale up' to join your tailnet"
#
# ── 8b: Add Tailscale to installed tools summary ──
# ANCHOR: Find the "Remote:" line in the summary.
#
# FOR CROSTINI — currently has no "Remote:" line. INSERT BEFORE "Your code:":
echo "  Networking:   Tailscale (mesh VPN)"
#
# FOR XUBUNTU — FIND:
#   echo "  Remote:       XRDP (port 3389), SSH (port 22)"
# REPLACE WITH:
echo "  Remote:       XRDP (port 3389), SSH (port 22), Tailscale (mesh VPN)"
#
# FOR FEDORA — FIND:
#   echo "  Remote:       XRDP (port 3389), SSH (port 22)"
# REPLACE WITH:
echo "  Remote:       XRDP (port 3389), SSH (port 22), Tailscale (mesh VPN)"


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 9 — Bump TOTAL_STEPS                                             ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# Each script has a TOTAL_STEPS variable near the top, and every section
# header uses "$N/$TOTAL_STEPS" formatting. Bump the count:
#
# CROSTINI:
#   FIND:    TOTAL_STEPS=15
#   REPLACE: TOTAL_STEPS=16
#
# XUBUNTU:
#   FIND:    TOTAL_STEPS=16
#   REPLACE: TOTAL_STEPS=17
#
# FEDORA:
#   FIND:    TOTAL_STEPS=16
#   REPLACE: TOTAL_STEPS=17
#
# IMPORTANT: Because section headers use "$TOTAL_STEPS" in the denominator
# and explicit numbers in the numerator (e.g., "15/$TOTAL_STEPS"), you also
# need to renumber the XRDP step and clone step if they come BEFORE the new
# Tailscale step. Specifically:
#
# FOR XUBUNTU + FEDORA (currently 16 steps → 17):
#   - Steps 1–15 keep their numbers
#   - Current step 16 (XRDP) stays as step 16
#   - NEW step 17: Tailscale
#   - The "Setup Complete" section is unnumbered — no change needed
#
# FOR CROSTINI (currently 15 steps → 16):
#   - Steps 1–15 keep their numbers
#   - NEW step 16: Tailscale
#   - The "Setup Complete" section is unnumbered — no change needed
#
# Since Tailscale is the LAST numbered step in all scripts, no existing
# step numbers need to change. Only TOTAL_STEPS and the new section header.


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ ZONE 10 — Bugfix: Starship scan_timeout placement                     ║
# ║ Apply to: ALL THREE SCRIPTS                                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# BUG: scan_timeout is a TOP-LEVEL Starship config key, but all three
# scripts place it inside the [directory] section. This causes:
#   [WARN] - (starship::config): Error in 'Directory' at 'scan_timeout': Unknown key
# on every shell login.
#
# FIX: In the Starship config heredoc (inside step 14 of each script),
# move scan_timeout out of [directory] and into the top-level section.
#
# FIND this block inside the starship.toml heredoc (all three scripts):
#
#   [directory]
#   truncation_length = 0
#   truncate_to_repo = false
#   format = "[$path]($style) "
#   style = "bold cyan"
#   scan_timeout = 100
#
# REPLACE WITH:
#
#   [directory]
#   truncation_length = 0
#   truncate_to_repo = false
#   format = "[$path]($style) "
#   style = "bold cyan"
#
# AND ADD scan_timeout = 100 at the TOP of the starship.toml heredoc,
# before any [section] header. Insert it after the comment block header:
#
#   # ============================================================================
#   # Starship prompt — setup-*-workstation
#   # ...
#   # ============================================================================
#
#   scan_timeout = 100
#
#   format = """
#   ...
#
# The Crostini script also has a comment "# default 30ms too short for
# large repos" on the scan_timeout line — that comment can move with it
# or be dropped (it's self-explanatory at the top level).
#
# ALSO: The Crostini script's [directory] section has a longer comment
# block below scan_timeout. Make sure only scan_timeout is removed,
# not the comments about fish_style_pwd_dir_length.


# ============================================================================
# TESTING CHECKLIST
# ============================================================================
#
# ── Org config tests ──
#
# □ Script runs clean on first run (no config file exists yet)
#   → Should create ~/.config/workstation-bootstrap/config
#   → Config template should have GITHUB_ORG and GITHUB_DEFAULT_OWNER
#     COMMENTED OUT (not pre-filled with any org name)
#   → Preflight should show "Org: <none>"
#   → Clone step should clone personal repos ONLY
#   → Summary should show config path and "Org: <none>"
#
# □ User edits config to set GITHUB_ORG, re-runs
#   → Preflight should show the org name
#   → Clone step should clone personal repos AND org repos
#   → Summary should show both
#
# □ Script is idempotent (re-run doesn't break anything)
#   → Config file should NOT be overwritten on re-run
#   → Already-cloned repos (personal and org) should show [SKIP]
#
# □ Empty GITHUB_ORG works (backward-compatible)
#   → Default config has it commented out → original behavior
#
# □ GITHUB_ORG via env var overrides config file
#   → GITHUB_ORG=SomeOrg bash setup-*.sh
#   → Should clone from SomeOrg, regardless of config file contents
#
# □ ghnew alias works in new shell (after editing config)
#   → source ~/.bashrc
#   → type ghnew → should resolve to gh repo create --owner <whatever>
#
# □ ghclone alias works
#   → ghclone some-repo → should clone <GITHUB_DEFAULT_OWNER>/some-repo
#
# □ Grep all three scripts for any hardcoded org name
#   → grep -i pitzilabs setup-*.sh → should return ZERO matches
#
# ── Tailscale tests ──
#
# □ Tailscale installs successfully on each platform
#   → tailscale --version returns a version number
#
# □ tailscaled service is enabled (Xubuntu + Fedora)
#   → systemctl is-enabled tailscaled → "enabled"
#
# □ Fedora: tailscale0 is in firewalld trusted zone
#   → sudo firewall-cmd --zone=trusted --list-interfaces → includes tailscale0
#
# □ Post-bootstrap auth works
#   → sudo tailscale up → opens auth URL → device appears in admin console
#
# □ RDP over Tailscale works (Xubuntu/Fedora)
#   → From Chromebook with Tailscale Android app connected
#   → Microsoft Remote Desktop → connect to VM's 100.x.x.x:3389
#   → KDE Plasma / XFCE session appears
#
# □ Crostini Tailscale can reach VM Tailscale
#   → ping <vm-tailscale-ip> from Crostini → works
#   → ssh <vm-tailscale-ip> from Crostini → works
#
# □ TOTAL_STEPS is correct in each script
#   → Crostini: 16
#   → Xubuntu: 17
#   → Fedora: 17
#
# □ Section headers match (last step number = TOTAL_STEPS)
#
# ── Starship bugfix tests ──
#
# □ No "[WARN] Unknown key" on shell login
#   → source ~/.bashrc → no starship warnings
#
# □ scan_timeout is at top level in starship.toml
#   → head -20 ~/.config/starship.toml → scan_timeout appears before any [section]
#
# □ scan_timeout is NOT inside [directory] section
#   → grep -A5 '\[directory\]' ~/.config/starship.toml → no scan_timeout
#
# ============================================================================
# REPO COLLISION NOTE
# ============================================================================
#
# If a personal repo and an org repo have the same name, the first one
# cloned wins (the second gets [SKIP] because $REPOS_DIR/$REPO_NAME
# already exists). Personal repos clone first, so personal wins.
#
# This is the right default: your fork takes precedence over the org's
# copy. If you need both, you'd use a subdirectory structure
# (~/repos/<org>/foo vs ~/repos/<user>/foo) — but that's a bigger
# change to the clone logic and the projects()/pull-all() functions.
# Cross that bridge if/when it actually bites you.
# ============================================================================
