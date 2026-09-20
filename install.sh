#!/usr/bin/env bash
# Install lupa on this machine: symlink the CLI onto PATH and the skill into
# Claude's global skills dir. Idempotent — safe to re-run after `git pull`.

set -euo pipefail

LUPA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. CLI on PATH ------------------------------------------------------------
if [[ -w /usr/local/bin ]]; then
  BIN_DIR=/usr/local/bin
else
  BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
fi
ln -sf "$LUPA_HOME/bin/lupa" "$BIN_DIR/lupa"
echo "✓ CLI: $BIN_DIR/lupa -> $LUPA_HOME/bin/lupa"

if ! command -v lupa >/dev/null 2>&1; then
  echo "  ⚠ $BIN_DIR is not on your PATH. Add it, e.g.:"
  echo "      echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
fi

# 2. Claude skill (global) --------------------------------------------------
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$SKILLS_DIR"
ln -sfn "$LUPA_HOME/skill" "$SKILLS_DIR/lupa"
echo "✓ Skill: $SKILLS_DIR/lupa -> $LUPA_HOME/skill"

# 3. Prereq check -----------------------------------------------------------
command -v sqlite3 >/dev/null 2>&1 || echo "  ⚠ sqlite3 CLI not found — install it (brew install sqlite)."
if command -v ruby >/dev/null 2>&1; then
  ruby -e "require 'prism'" 2>/dev/null || echo "  ⚠ ruby lacks Prism — use Ruby 3.3+ or set LUPA_RUBY."
fi

echo
echo "Done. Try it in any Ruby/Rails repo:"
echo "    cd /path/to/repo && lupa scan && lupa stats"
