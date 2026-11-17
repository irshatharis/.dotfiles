-- Open a path in nvim in a floating pane.
--   cmd+o        prompt for a path (paste it, Enter opens, Esc closes)
--   cmd+shift+o  open the path selected in the focused pane
-- Relative paths resolve from the focused pane's directory. A trailing :LINE
-- or :LINE:COL, as agents print it, jumps to that line. :q closes the pane.
local prompt = [=[
setopt extendedglob
KEYTIMEOUT=1
bindkey '^[' send-break

p= auto=
if [[ $1 == selection ]]; then
  # Rex copies the selection only after the action returns, and this pane
  # starts unfocused so the copy reads the right pane. Wait, then take focus.
  sleep 0.25
  p=$(pbpaste)
  p=${p//$'\n'[[:space:]]#/}
  auto=1
  rex focus -s "$REX_SESSION" "$REX_BLOCK" >/dev/null 2>&1
fi

msg=
while :; do
  if [[ -z $auto ]]; then
    [[ -n $msg ]] && print -r -- $'\e[31m'"$msg"$'\e[0m'
    vared -p 'Open in nvim: ' p || exit
  fi
  auto=
  p=${${p##[[:space:]]#}%%[[:space:]]#}
  [[ -z $p ]] && exit
  f=${p/#\~/$HOME}
  line=()
  if [[ ! -e $f && $f =~ '^(.+):([0-9]+)(:[0-9]+)?$' ]]; then
    f=$match[1]; line=(+$match[2])
  fi
  [[ -e $f ]] && exec nvim $line -- $f
  msg="Not found: ${f:a}"
done
]=]

local terminal = "com.superlogical.terminal"

rex.action{
  name = "open_path_in_nvim",
  title = "Open Path in Neovim",
  description = "Open a pasted or selected file path in nvim in a floating pane.",
  keywords = "open file path nvim neovim vim editor float selection",
  args = { selection = "boolean?" },
  run = function(ctx, args)
    local selection = args and args.selection
    local cwd
    if ctx.block_id then
      local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id })
      if proc then
        cwd = (proc.foreground and proc.foreground.cwd)
          or (proc.ancestors and proc.ancestors[1] and proc.ancestors[1].cwd)
      end
    end
    local result, err = rex.session.new_layer{
      bounds = { 0.08, 0.06, 0.84, 0.88 },
      focus = not selection,
      layout = rex.layout.block{
        flavor = terminal .. ".shell",
        options = {
          command = { "zsh", "-c", prompt, "open-path", selection and "selection" or "" },
          cwd = cwd,
        },
      },
    }
    if selection and result then rex.client.queue("pane.copy") end
    return result, err
  end,
}

rex.bind("cmd+o", "open_path_in_nvim")
rex.bind("cmd+shift+o", "open_path_in_nvim", { selection = true })

-- cmd+j: the notes vault in Neovim, floating over whatever tab you're in.
-- The first press opens it (auto-session reopens the notes you had open).
-- Pressing it again hides it: the pane is detached, so Neovim keeps running
-- with your place, undo history and unsynced notes intact. The next press
-- brings that same Neovim back over the current tab. Quitting Neovim closes
-- the pane for good; the next press starts a fresh one.
local vault_dir = os.getenv("HOME") .. "/vaults/irsh-world"
local vault_bounds = { 0.1, 0.06, 0.8, 0.88 }

rex.action{
  name = "toggle_vault",
  title = "Toggle Notes Vault",
  description = "Show or hide the notes vault in a floating Neovim pane.",
  keywords = "notes vault obsidian journal tasks daily nvim neovim float",
  run = function()
    local view = rex.session.view{}
    local win
    for _, w in ipairs(view.windows) do
      if w.window_id == view.active_window_id then win = w end
    end
    local vault
    for _, b in ipairs(rex.session.list_blocks{}.blocks) do
      if b.label == "vault" then vault = b end
    end

    if not vault then
      return rex.session.new_layer{
        bounds = vault_bounds,
        focus = true,
        layout = rex.layout.block{
          flavor = terminal .. ".shell",
          label = "vault",
          -- -i loads .zshrc, which puts nvm's node on PATH for the language servers
          options = { command = { "zsh", "-ic", "exec nvim" }, cwd = vault_dir },
        },
      }
    end

    if vault.placement == "placed" and vault.window_id == win.window_id then
      if win.focused_block_id ~= vault.block_id then
        return rex.session.focus_block{ block_id = vault.block_id }
      end
      return rex.session.detach_block{ block_id = vault.block_id }
    end

    -- Bring it over this tab: place it beside a tiled pane here, then float it
    if vault.placement == "placed" then
      rex.session.detach_block{ block_id = vault.block_id }
    end
    local anchor
    for _, layer in ipairs(win.layers) do
      if layer.kind == "tiled" and layer.blocks[1] then anchor = layer.blocks[1].block_id end
    end
    rex.session.move_block{ block_id = vault.block_id, anchor_block_id = anchor }
    rex.session.float_block{ block_id = vault.block_id, bounds = vault_bounds }
    return rex.session.focus_block{ block_id = vault.block_id }
  end,
}

rex.bind("cmd+j", "toggle_vault")
