#!/usr/bin/env bash
# Install lupa on this machine: build & install the gem (puts `lupa` on PATH via
# RubyGems) and link the Claude skill into the global skills dir. Idempotent.

set -euo pipefail

LUPA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$LUPA_HOME"

# 1. Build + install the gem -------------------------------------------------
if command -v ruby >/dev/null 2>&1 && ruby -e "require 'prism'" 2>/dev/null; then
  gem build lupa.gemspec -o lupa.gem
  gem install ./lupa.gem
  rm -f lupa.gem
  echo "✓ Gem installed — 'lupa' is on PATH via RubyGems ($(command -v lupa || echo 'restart shell'))"
else
  echo "⚠ Need Ruby 3.3+ with Prism on PATH to install the gem (got: $(ruby -v 2>/dev/null || echo none))." >&2
  exit 1
fi

# 2. Claude skill (global) ---------------------------------------------------
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$SKILLS_DIR"
ln -sfn "$LUPA_HOME/skill" "$SKILLS_DIR/lupa"
echo "✓ Skill: $SKILLS_DIR/lupa -> $LUPA_HOME/skill"

# 3. Prereq check ------------------------------------------------------------
command -v sqlite3 >/dev/null 2>&1 || echo "  ⚠ sqlite3 binary not found — install it (brew install sqlite)."

echo
echo "Done. Try it in any Ruby/Rails repo:"
echo "    cd /path/to/repo && lupa scan && lupa stats"
