#!/usr/bin/env bash
# Dotfiles installer — idempotent. Symlinks config into place and bootstraps .env.
#
# Usage: ./install.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# symlink <src-relative-to-dotfiles> <absolute-dst>
symlink() {
  local src="$DOTFILES/$1"
  local dst="$2"

  [[ -e "$src" ]] || { echo "skip (missing in repo): $1"; return; }

  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok:   $dst"
    return
  fi

  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    local backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup"
    echo "moved existing -> $backup"
  fi

  ln -s "$src" "$dst"
  echo "link: $dst -> $src"
}

echo "==> home dotfiles"
symlink ".zshrc"        "$HOME/.zshrc"
symlink ".zsh_aliases"  "$HOME/.zsh_aliases"
symlink ".gitconfig"    "$HOME/.gitconfig"

echo "==> rex"
symlink "rex"           "$HOME/.config/rex"

echo "==> karabiner"
symlink "karabiner-elements.json" "$HOME/.config/karabiner/karabiner.json"

echo "==> claude code (settings.json is shareable config; auth/tokens stay local)"
symlink "claude/settings.json" "$HOME/.claude/settings.json"

echo "==> neovim"
symlink "init.lua"       "$HOME/.config/nvim/init.lua"
symlink "lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"

echo "==> git global ignore"
symlink "git/ignore"    "$HOME/.config/git/ignore"

echo "==> hunk (TUI git diff viewer)"
symlink "hunk/config.toml" "$HOME/.config/hunk/config.toml"

echo "==> usage-limit reset alerts (Claude Code + Codex)"
symlink "scripts/usage-alerts" "$HOME/.local/bin/usage-alerts"
if [[ -n "${SKIP_USAGE_ALERTS:-}" ]]; then
  echo "skip: usage-alerts launchd agent (SKIP_USAGE_ALERTS set)"
else
  python3 "$DOTFILES/scripts/usage-alerts" install
fi

echo "==> secrets"
if [[ ! -f "$DOTFILES/.env" ]]; then
  cp "$DOTFILES/.env.example" "$DOTFILES/.env"
  chmod 600 "$DOTFILES/.env"
  echo "Created $DOTFILES/.env from example — fill in real values."
else
  chmod 600 "$DOTFILES/.env"
  echo "ok:   $DOTFILES/.env (already present)"
fi

cat <<EOF

Done.
- Secrets live in $DOTFILES/.env (gitignored). .zshrc sources it automatically.
EOF
