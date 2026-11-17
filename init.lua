-- Byte-compile and cache Lua modules in ~/.cache/nvim/luac (lazy.nvim did this for us)
vim.loader.enable()

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.o.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

vim.o.confirm = true

-- Leader key must be set before plugins
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Rounded borders for every floating window (hover, diagnostics, signature help, mason)
vim.o.winborder = "rounded"
-- New message UI (0.12, experimental): long messages and errors expand the
-- command line briefly instead of blocking on "Press ENTER to continue"
require("vim._core.ui2").enable({})

-- Plugins (built-in vim.pack manager; lockfile is nvim-pack-lock.json)
-- Update: :lua vim.pack.update()   Remove: :lua vim.pack.del({ "name" })
-- plugin start

-- Rebuild treesitter parsers whenever nvim-treesitter itself is updated
vim.api.nvim_create_autocmd("PackChanged", {
	group = vim.api.nvim_create_augroup("pack-hooks", { clear = true }),
	callback = function(ev)
		if ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
			if not ev.data.active then
				vim.cmd.packadd("nvim-treesitter")
			end
			vim.cmd("TSUpdate")
		end
	end,
})

local gh = function(repo)
	return "https://github.com/" .. repo
end

-- Sets up a plugin right after the first screen is drawn (lazy.nvim's VeryLazy),
-- for plugins the first screen doesn't need. They attach to the buffers that are
-- already open, including ones auto-session restored.
local function after_startup(fn)
	if vim.v.vim_did_enter == 1 then
		return fn()
	end
	vim.api.nvim_create_autocmd("VimEnter", {
		group = vim.api.nvim_create_augroup("after-startup", { clear = false }),
		once = true,
		callback = function()
			vim.schedule(fn)
		end,
	})
end

vim.pack.add({
	gh("rebelot/kanagawa.nvim"),
	gh("projekt0n/github-nvim-theme"),
	{ src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
	gh("windwp/nvim-autopairs"),
	gh("nvim-lua/plenary.nvim"), -- required by harpoon
	{ src = gh("ThePrimeagen/harpoon"), version = "harpoon2" },
	gh("mason-org/mason.nvim"),
	gh("mason-org/mason-lspconfig.nvim"),
	gh("neovim/nvim-lspconfig"),
	gh("folke/which-key.nvim"),
	{ src = gh("saghen/blink.cmp"), version = vim.version.range("1") },
	gh("stevearc/conform.nvim"),
	gh("lewis6991/gitsigns.nvim"),
	gh("nvim-tree/nvim-web-devicons"),
	gh("MeanderingProgrammer/render-markdown.nvim"),
	gh("nvim-lualine/lualine.nvim"),
	gh("stevearc/oil.nvim"),
	gh("folke/snacks.nvim"),
	gh("rmagatti/auto-session"),
})

-- Built-in optional plugins
vim.cmd.packadd("nvim.undotree")

-- Colorscheme
require("kanagawa").setup({
	keywordStyle = { italic = false },
	statementStyle = { bold = false },
	commentStyle = { italic = false },
	functionStyle = { bold = false },
})

-- Dark: kanagawa wave. Light: github light (instead of kanagawa lotus).
local function apply_theme()
	if vim.o.background == "light" then
		vim.cmd.colorscheme("github_light")
	else
		vim.cmd.colorscheme("kanagawa-wave")
	end
end
apply_theme()

-- Follow terminal light/dark changes detected after startup
vim.api.nvim_create_autocmd("OptionSet", {
	pattern = "background",
	group = vim.api.nvim_create_augroup("theme-switch", { clear = true }),
	nested = true, -- let ColorScheme autocmds (lualine, markdown colors) run on the switch
	callback = apply_theme,
})

-- Treesitter: nvim-treesitter (main branch) only installs parsers and queries.
-- Highlighting, folding and incremental selection are built into Neovim.
do
	local ts = require("nvim-treesitter")
	ts.install({
		"lua",
		"vim",
		"vimdoc",
		"query",
		"markdown",
		"markdown_inline",
		"javascript",
		"typescript",
		"tsx",
		"json",
		"html",
		"css",
		"bash",
		"rust",
		"toml",
		"yaml",
		"regex",
		"go",
		"gomod",
		"gosum",
		"gowork",
	})

	local function start(buf, lang)
		if not vim.api.nvim_buf_is_valid(buf) or not pcall(vim.treesitter.start, buf, lang) then
			return
		end
		if vim.treesitter.query.get(lang, "indents") then
			vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end

	-- Start treesitter for every filetype with a parser, installing missing ones on demand
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
		callback = function(ev)
			local lang = vim.treesitter.language.get_lang(ev.match)
			if not lang then
				return
			end
			if vim.treesitter.language.add(lang) then
				start(ev.buf, lang)
			elseif vim.list_contains(ts.get_available(), lang) then
				ts.install(lang):await(function()
					vim.schedule(function()
						start(ev.buf, lang)
					end)
				end)
			end
		end,
	})
end

-- Markdown rendering in the buffer: rendered in every mode so switching modes
-- never shifts the layout. <leader>m toggles between rendered and raw source.
-- Styled after Obsidian: plain bold headings with breathing room, muted list
-- markers, a tick for done tasks, and a centered reading column.
require("render-markdown").setup({
	render_modes = true,
	latex = { enabled = false },
	anti_conceal = { enabled = false },
	heading = {
		sign = false,
		icons = { "" },
		position = "inline",
		width = "block",
		backgrounds = {},
		-- Blank space above and below headings. Always drawn as extra virtual rows:
		-- reusing an empty line instead made a row appear the moment you typed on
		-- the line next to a heading, pushing everything below it down.
		border = true,
		border_virtual = true,
		above = " ",
		below = " ",
	},
	bullet = {
		icons = { "•" },
		highlight = "RenderMarkdownBullet",
	},
	checkbox = {
		unchecked = { icon = "⬜", highlight = "RenderMarkdownUnchecked" },
		checked = { icon = "✅", highlight = "RenderMarkdownChecked" },
		custom = {
			todo = { raw = "[-]", rendered = "⏳", highlight = "RenderMarkdownTodo" },
		},
	},
	code = {
		sign = false,
		width = "block",
		left_pad = 1,
		right_pad = 1,
	},
})

vim.keymap.set("n", "<leader>m", function()
	require("render-markdown").toggle()
end, { desc = "Toggle markdown rendering" })

-- <leader>l in a note: tick or untick a task. On a list item or plain text it
-- becomes a task; on an empty line it starts a new task in insert mode.
-- Edits touch only the characters that change: replacing the whole line would
-- wipe the line's rendering and flash raw markdown until it is redrawn.
local function toggle_task()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local indent, rest = line:match("^(%s*)(.*)$")

	local function insert(at, text)
		vim.api.nvim_buf_set_text(0, row - 1, at, row - 1, at, { text })
		vim.api.nvim_win_set_cursor(0, { row, col >= at and col + #text or col })
	end

	if rest == "" then
		insert(#line, "- [ ] ")
		vim.cmd("startinsert!")
		return
	end

	local marker, state = rest:match("^([-*+]%s+)%[(.)%]")
	if not marker then
		marker, state = rest:match("^(%d+[.)]%s+)%[(.)%]")
	end
	if marker then
		local at = #indent + #marker + 1
		vim.api.nvim_buf_set_text(0, row - 1, at, row - 1, at + 1, { state:lower() == "x" and " " or "x" })
		vim.api.nvim_win_set_cursor(0, { row, col })
		return
	end

	marker = rest:match("^[-*+]%s+") or rest:match("^%d+[.)]%s+")
	if marker then
		insert(#indent + #marker, "[ ] ")
	else
		insert(#indent, "- [ ] ")
	end
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	group = vim.api.nvim_create_augroup("markdown-tasks", { clear = true }),
	callback = function(ev)
		vim.keymap.set("n", "<leader>l", toggle_task, { buffer = ev.buf, desc = "Toggle task" })
	end,
})

-- Theme-aware markdown colors (re-applied whenever the colorscheme changes)
local function markdown_highlights()
	local function color(name)
		return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
	end
	local muted = color("Comment")
	-- Read the theme's base heading groups; the .markdown ones are overridden below
	local function heading(level)
		return color("@markup.heading." .. level) or color("@markup.heading") or color("Title")
	end
	local accent = heading(1)
	for level = 1, 6 do
		local fg = heading(level)
		vim.api.nvim_set_hl(0, "@markup.heading." .. level .. ".markdown", { fg = fg, bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH" .. level, { fg = fg, bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH" .. level .. "Bg", { fg = fg, bold = true })
	end
	vim.api.nvim_set_hl(0, "RenderMarkdownBullet", { fg = muted })
	vim.api.nvim_set_hl(0, "RenderMarkdownUnchecked", { fg = muted })
	vim.api.nvim_set_hl(0, "RenderMarkdownChecked", { fg = accent, bold = true })
end
-- VimEnter: render-markdown sets its default colors from its plugin script, after init.lua
vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
	group = vim.api.nvim_create_augroup("markdown-highlights", { clear = true }),
	callback = markdown_highlights,
})

-- Notes read like a document: wrapped at word boundaries, no line numbers,
-- signs, cursor line, indent guides or "~" filler lines
local function notes_view(win)
	local buf = vim.api.nvim_win_get_buf(win)
	if vim.bo[buf].buftype ~= "" or vim.api.nvim_win_get_config(win).relative ~= "" then
		return
	end
	local wo = vim.wo[win][0]
	if vim.bo[buf].filetype == "markdown" then
		vim.b[buf].snacks_indent = false
		-- Wrapped list items hang under their text, not the bullet. Task items
		-- count one extra column because their emoji checkbox is two cells wide.
		vim.bo[buf].formatlistpat = [[^\s*\(\d\+[.)]\|[-*+]\)\s\+\%(\%(\[.\]\s\)\@=\[\)\?]]
		wo.breakindentopt = "list:-1"
		wo.linebreak = true
		wo.number = false
		wo.cursorline = false
		wo.signcolumn = "no"
		wo.statuscolumn = ""
		wo.fillchars = "eob: ,vert: "
		wo.winbar = "%#Normal# " -- an empty top row, so a heading on line 1 isn't flush against the edge
	elseif wo.fillchars == "eob: ,vert: " then
		-- A code file in a window that showed (or was split from) a note: restore editor defaults
		for _, opt in ipairs({
			"linebreak",
			"breakindentopt",
			"number",
			"cursorline",
			"signcolumn",
			"fillchars",
			"winbar",
		}) do
			wo[opt] = vim.go[opt]
		end
	end
end

vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "SessionLoadPost" }, {
	group = vim.api.nvim_create_augroup("notes-view", { clear = true }),
	callback = function()
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			notes_view(win)
		end
	end,
})

-- Centered reading column: while a note is the only window on screen, empty
-- side windows keep it NOTES_WIDTH columns wide in the middle. Any split or
-- the explorer sidebar removes them until the note is alone again.
local NOTES_WIDTH = 88

local function notes_pads()
	return vim.tbl_filter(function(w)
		return vim.w[w].notes_pad == true
	end, vim.api.nvim_tabpage_list_wins(0))
end

local function notes_close_pads()
	for _, w in ipairs(notes_pads()) do
		pcall(vim.api.nvim_win_close, w, true)
	end
end

local function notes_layout()
	local editors = vim.tbl_filter(function(w)
		return vim.api.nvim_win_get_config(w).relative == "" and not vim.w[w].notes_pad
	end, vim.api.nvim_tabpage_list_wins(0))
	local note = editors[1]
	local width = math.floor((vim.o.columns - NOTES_WIDTH - 2) / 2)
	local buf = note and vim.api.nvim_win_get_buf(note)
	if #editors ~= 1 or vim.bo[buf].filetype ~= "markdown" or vim.bo[buf].buftype ~= "" or width < 2 then
		notes_close_pads()
		return
	end
	local pads = notes_pads()
	if #pads == 0 then
		for _, side in ipairs({ "left", "right" }) do
			local pad_buf = vim.api.nvim_create_buf(false, true)
			vim.bo[pad_buf].bufhidden = "wipe"
			local w = vim.api.nvim_open_win(pad_buf, false, { split = side, win = -1, style = "minimal" })
			vim.w[w].notes_pad = true
			vim.wo[w].fillchars = "eob: ,vert: "
			vim.wo[w].winfixwidth = true
			table.insert(pads, w)
		end
	end
	for _, w in ipairs(pads) do
		vim.api.nvim_win_set_width(w, width)
	end
end

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew", "WinClosed", "VimResized", "TabEnter", "SessionLoadPost" }, {
	group = vim.api.nvim_create_augroup("notes-layout", { clear = true }),
	callback = function()
		vim.schedule(notes_layout)
	end,
})

-- The side windows are never a destination: clicking or moving into one returns to the note
vim.api.nvim_create_autocmd("WinEnter", {
	group = vim.api.nvim_create_augroup("notes-pad-skip", { clear = true }),
	callback = function()
		if vim.w.notes_pad then
			vim.cmd.wincmd("p")
		end
	end,
})

-- :q on the note quits Neovim instead of leaving the empty side windows behind
vim.api.nvim_create_autocmd("QuitPre", {
	group = vim.api.nvim_create_augroup("notes-pad-quit", { clear = true }),
	callback = notes_close_pads,
})

-- Vault sync, replacing Obsidian Git. Notes in the vault save themselves as you
-- edit. A minute after the last change they are committed as "vault backup:
-- <date>", rebased onto anything new from the phone, and pushed. New changes are
-- pulled when a vault note opens, when Neovim regains focus, and on the first key
-- after a few idle minutes, at most once a minute. A conflict is never resolved
-- automatically: the rebase is undone and a macOS notification says so.
do
	local VAULT = vim.fs.normalize("~/vaults/irsh-world")
	local PUSH_DELAY = 60 * 1000 -- ms after the last save
	local PULL_GAP = 60 -- seconds between pulls at most
	local IDLE = 3 * 60 -- seconds without a key before the next key pulls
	local timer = assert(vim.uv.new_timer())
	local running, pending, exiting, conflicted = false, false, false, false
	local last_pull, last_key = 0, os.time()

	local function in_vault(buf)
		return vim.bo[buf].buftype == "" and vim.startswith(vim.api.nvim_buf_get_name(buf), VAULT .. "/")
	end

	local function vault_in_use()
		if vim.startswith(vim.fn.getcwd() .. "/", VAULT .. "/") then
			return true
		end
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) and in_vault(buf) then
				return true
			end
		end
		return false
	end

	-- OSC 777 makes Rex show a macOS notification
	local function notify(msg)
		vim.notify("Vault sync: " .. msg, vim.log.levels.WARN)
		pcall(vim.api.nvim_ui_send, "\27]777;notify;Vault sync;" .. msg:gsub("[;\27\7]", ",") .. "\7")
	end

	-- Runs git in the vault. While Neovim is quitting the whole chain runs
	-- synchronously, so a pending backup is pushed before it exits.
	local function git(args, done)
		local cmd = vim.list_extend({ "git", "-C", VAULT }, args)
		local opts = { text = true, env = { GIT_TERMINAL_PROMPT = "0" } }
		if exiting then
			return done(vim.system(cmd, opts):wait(20000))
		end
		vim.system(cmd, opts, vim.schedule_wrap(done))
	end

	local sync

	-- Only one Neovim syncs the vault at a time (say the floating panel and a
	-- tab both have it open). The lock is a directory: creating one is atomic.
	local LOCK = VAULT .. "/.git/nvim-vault-sync.lock"
	local function lock()
		if vim.uv.fs_mkdir(LOCK, 448) then
			return true
		end
		local stat = vim.uv.fs_stat(LOCK)
		if stat and os.time() - stat.mtime.sec > 120 then -- left behind by a crash
			vim.uv.fs_rmdir(LOCK)
			return vim.uv.fs_mkdir(LOCK, 448) == true
		end
		return false
	end

	local function finish()
		running = false
		vim.uv.fs_rmdir(LOCK)
		if not exiting then
			vim.cmd("silent! checktime") -- reload notes the pull changed
		end
		if pending then
			pending = false
			sync()
		end
	end

	-- Fetch, then rebase onto origin/main by name. (`git pull --rebase` reads
	-- FETCH_HEAD, which overlapping fetches can leave listing the branch twice:
	-- "cannot rebase onto multiple branches".)
	local function pull_rebase(next_step)
		git({ "fetch", "--quiet", "origin" }, function(f)
			last_pull = os.time()
			if f.code ~= 0 then
				-- Usually just offline; the next save or pull tries again
				vim.notify("Vault sync: fetch failed: " .. vim.trim(f.stderr or ""), vim.log.levels.WARN)
				return finish()
			end
			git({ "rebase", "--quiet", "@{upstream}" }, function(r)
				if r.code == 0 then
					conflicted = false
					return next_step()
				end
				if vim.uv.fs_stat(VAULT .. "/.git/rebase-merge") or vim.uv.fs_stat(VAULT .. "/.git/rebase-apply") then
					git({ "rebase", "--abort" }, function()
						if not conflicted then
							conflicted = true
							notify(
								"A note changed on both the phone and the Mac. Your edits are committed locally; run `git pull --rebase` in the vault to merge."
							)
						end
						finish()
					end)
				else
					if (r.stderr or ""):find("unstaged changes") then
						pending = true -- a note was saved mid-pull: back it up and try again
					else
						vim.notify("Vault sync: rebase failed: " .. vim.trim(r.stderr or ""), vim.log.levels.WARN)
					end
					finish()
				end
			end)
		end)
	end

	-- Commit everything, rebase onto the remote, push
	sync = function()
		if running then
			pending = true
			return
		end
		-- Another Neovim is syncing: try again shortly (when quitting, wait for it)
		if not (exiting and vim.wait(10000, lock, 200) or not exiting and lock()) then
			if not exiting then
				timer:start(10000, 0, vim.schedule_wrap(sync))
			end
			return
		end
		running = true
		timer:stop()
		git({ "add", "-A" }, function()
			git({ "diff", "--cached", "--quiet" }, function(staged)
				local function rebase_and_push()
					pull_rebase(function()
						git({ "push", "--quiet" }, function(r)
							if r.code ~= 0 then
								vim.notify("Vault sync: push failed: " .. vim.trim(r.stderr or ""), vim.log.levels.WARN)
							end
							finish()
						end)
					end)
				end
				if staged.code == 0 then
					return rebase_and_push()
				end
				git({ "commit", "--quiet", "-m", "vault backup: " .. os.date("%Y-%m-%d %H:%M:%S") }, rebase_and_push)
			end)
		end)
	end

	local function pull()
		if running or timer:is_active() or os.time() - last_pull < PULL_GAP or not vault_in_use() then
			return -- a sync already in flight or coming up pulls first anyway
		end
		if not lock() then
			return -- another Neovim is syncing right now
		end
		running = true
		git({ "status", "--porcelain" }, function(r)
			if vim.trim(r.stdout or "") ~= "" then
				running = false
				vim.uv.fs_rmdir(LOCK)
				return sync() -- local changes from an earlier session: back them up first
			end
			pull_rebase(finish)
		end)
	end

	local group = vim.api.nvim_create_augroup("vault-sync", { clear = true })
	vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost", "BufLeave" }, {
		group = group,
		nested = true, -- so the write fires BufWritePost and starts the backup countdown
		callback = function(ev)
			if in_vault(ev.buf) and vim.bo[ev.buf].modified then
				vim.api.nvim_buf_call(ev.buf, function()
					vim.cmd("silent! lockmarks update")
				end)
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		callback = function(ev)
			if in_vault(ev.buf) then
				timer:stop()
				timer:start(PUSH_DELAY, 0, vim.schedule_wrap(sync))
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(ev)
			if in_vault(ev.buf) then
				vim.b[ev.buf].disable_autoformat = true -- notes are saved as they're typed; don't let prettier rewrite them
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter", "FocusGained" }, {
		group = group,
		callback = function()
			pull()
		end,
	})
	vim.on_key(function()
		local now = os.time()
		if now - last_key > IDLE then
			vim.schedule(pull)
		end
		last_key = now
	end, vim.api.nvim_create_namespace("vault-sync"))
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			if timer:is_active() and not running then
				exiting = true
				sync()
			end
		end,
	})
	vim.api.nvim_create_user_command("VaultSync", function()
		sync()
	end, { desc = "Back up and sync the notes vault now" })
end

-- Auto pairs for brackets, quotes, etc.
after_startup(function()
	require("nvim-autopairs").setup({})
end)

-- Harpoon
after_startup(function()
	local harpoon = require("harpoon")
	harpoon.setup()

	vim.keymap.set("n", "<leader>a", function()
		harpoon:list():add()
	end)

	vim.keymap.set("n", "<leader>f", function()
		harpoon.ui:toggle_quick_menu(harpoon:list())
	end)

	vim.keymap.set("n", "<leader>1", function()
		harpoon:list():select(1)
	end)
	vim.keymap.set("n", "<leader>2", function()
		harpoon:list():select(2)
	end)
	vim.keymap.set("n", "<leader>3", function()
		harpoon:list():select(3)
	end)
	vim.keymap.set("n", "<leader>4", function()
		harpoon:list():select(4)
	end)

	-- Toggle previous & next buffers stored within Harpoon list
	vim.keymap.set("n", "<leader>[", function()
		harpoon:list():prev()
	end)
	vim.keymap.set("n", "<leader>]", function()
		harpoon:list():next()
	end)

	harpoon:extend(require("harpoon.extensions").builtins.highlight_current_file())
end)

-- Autocompletion
after_startup(function()
	require("blink.cmp").setup({
		-- 'enter' preset: Enter accepts. All presets also have:
		-- C-space: open menu/docs, C-n/C-p or Up/Down: select, C-e: hide, C-k: toggle signature help
		keymap = { preset = "enter" },

		appearance = {
			-- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
			nerd_font_variant = "mono",
		},

		completion = {
			-- Only show the documentation popup when manually triggered
			documentation = { auto_show = false },
			accept = {
				auto_brackets = {
					enabled = false,
				},
			},
		},

		signature = { enabled = true },

		-- Keep LSP/path, but disable the buffer source so random words from the
		-- current file are not suggested.
		sources = {
			default = { "lsp", "path" },
		},

		-- Rust fuzzy matcher (prebuilt binary downloaded for the release tag)
		fuzzy = { implementation = "prefer_rust_with_warning" },
	})
end)

-- LSP (after blink.cmp, whose capabilities every server gets). mason puts its
-- servers on PATH before mason-lspconfig enables them for the open buffers.
after_startup(function()
	require("mason").setup({
		ui = {
			icons = {
				package_installed = "✓",
				package_pending = "➜",
				package_uninstalled = "✗",
			},
		},
	})

	-- Global capabilities for every server (extended by blink.cmp)
	vim.lsp.config("*", {
		capabilities = require("blink.cmp").get_lsp_capabilities(),
	})

	vim.lsp.config("ts_ls", {
		root_markers = { "package.json", "tsconfig.json" },
		workspace_required = true,
		settings = {
			typescript = {
				inlayHints = {
					includeInlayParameterNameHints = "literals",
					includeInlayFunctionParameterTypeHints = true,
					includeInlayFunctionLikeReturnTypeHints = true,
				},
			},
			javascript = {
				inlayHints = {
					includeInlayParameterNameHints = "literals",
					includeInlayFunctionParameterTypeHints = true,
					includeInlayFunctionLikeReturnTypeHints = true,
				},
			},
		},
	})

	vim.lsp.config("lua_ls", {
		settings = {
			Lua = {
				diagnostics = { globals = { "vim" } },
				workspace = {
					library = vim.api.nvim_get_runtime_file("", true),
					checkThirdParty = false,
				},
				telemetry = { enable = false },
			},
		},
	})

	vim.lsp.config("rust_analyzer", {
		settings = {
			["rust-analyzer"] = {
				check = { command = "clippy" },
				cargo = { allFeatures = true },
			},
		},
	})

	vim.lsp.config("gopls", {
		settings = {
			gopls = {
				-- staticcheck adds the `go vet`-style lints gopls doesn't run by default
				staticcheck = true,
				gofumpt = true,
				analyses = {
					unusedparams = true,
					unusedwrite = true,
					nilness = true,
					shadow = true,
					useany = true,
				},
				hints = {
					assignVariableTypes = true,
					compositeLiteralFields = true,
					constantValues = true,
					functionTypeParameters = true,
					parameterNames = true,
					rangeVariableTypes = true,
				},
				codelenses = { gc_details = false, test = true, tidy = true },
				semanticTokens = true,
			},
		},
	})

	-- Auto-install LSP servers (mason-lspconfig v2 auto-enables installed servers)
	require("mason-lspconfig").setup({
		ensure_installed = {
			"ts_ls",
			"html",
			"cssls",
			"jsonls",
			"lua_ls",
			"bashls",
			"rust_analyzer",
			"gopls",
		},
	})

	-- LSP keybindings
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
		callback = function(event)
			local map = function(keys, func, desc)
				vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
			end

			map("gd", vim.lsp.buf.definition, "Goto Definition")
			vim.keymap.set("n", "grr", function()
				Snacks.picker.lsp_references()
			end, { desc = "Goto References" })
			map("gI", function()
				Snacks.picker.lsp_implementations()
			end, "Goto Implementation")
			map("gt", function()
				Snacks.picker.lsp_type_definitions()
			end, "Type Definition")
			map("<leader>st", function()
				Snacks.picker.lsp_symbols()
			end, "Document Symbols")
			map("<leader>sT", function()
				Snacks.picker.lsp_workspace_symbols()
			end, "Workspace Symbols")
			map("gh", vim.lsp.buf.hover, "Hover Documentation")
			map("gD", vim.lsp.buf.declaration, "Goto Declaration")

			local client = vim.lsp.get_client_by_id(event.data.client_id)
			if not client then
				return
			end

			-- Prefer LSP folding ranges over treesitter when the server provides them
			if client:supports_method("textDocument/foldingRange") then
				local win = vim.api.nvim_get_current_win()
				vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
			end

			-- Highlight references under cursor
			if client:supports_method("textDocument/documentHighlight") then
				local highlight_group = vim.api.nvim_create_augroup("lsp-highlight", { clear = false })
				vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
					buffer = event.buf,
					group = highlight_group,
					callback = vim.lsp.buf.document_highlight,
				})
				vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
					buffer = event.buf,
					group = highlight_group,
					callback = vim.lsp.buf.clear_references,
				})
			end
		end,
	})

	-- Clean up highlight autocmds when LSP detaches (e.g. on :lsp restart)
	vim.api.nvim_create_autocmd("LspDetach", {
		group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
		callback = function(event)
			vim.lsp.buf.clear_references()
			pcall(vim.api.nvim_clear_autocmds, { group = "lsp-highlight", buffer = event.buf })
		end,
	})
end)

after_startup(function()
	require("which-key").setup({
		delay = 2000,
	})
end)

-- Formatting
after_startup(function()
	require("conform").setup({
		formatters_by_ft = {
			javascript = { "prettier" },
			typescript = { "prettier" },
			javascriptreact = { "prettier" },
			typescriptreact = { "prettier" },
			css = { "prettier" },
			html = { "prettier" },
			json = { "prettier" },
			yaml = { "prettier" },
			markdown = { "prettier" },
			lua = { "stylua" },
			rust = { "rustfmt" },
			go = { "goimports", "gofumpt" },
		},
		format_after_save = function(bufnr)
			if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
				return
			end
			local formatters = require("conform").list_formatters(bufnr)
			if #formatters == 0 then
				return
			end
			return { lsp_format = "fallback" }
		end,
	})
end)

-- Git signs
after_startup(function()
	require("gitsigns").setup({
		signs = {
			add = { text = "+" },
			change = { text = "~" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
		},
		on_attach = function(bufnr)
			local gitsigns = require("gitsigns")

			local function map(mode, l, r, opts)
				opts = opts or {}
				opts.buffer = bufnr
				vim.keymap.set(mode, l, r, opts)
			end

			-- Navigation
			map("n", "]c", function()
				if vim.wo.diff then
					vim.cmd.normal({ "]c", bang = true })
				else
					gitsigns.nav_hunk("next")
				end
			end, { desc = "go to next hunk" })

			map("n", "[c", function()
				if vim.wo.diff then
					vim.cmd.normal({ "[c", bang = true })
				else
					gitsigns.nav_hunk("prev")
				end
			end, { desc = "go to prev hunk" })

			-- Actions
			map("n", "<leader>hs", gitsigns.stage_hunk, { desc = "stage hunk" })
			map("n", "<leader>hr", gitsigns.reset_hunk, { desc = "reset hunk" })

			map("v", "<leader>hs", function()
				gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end)

			map("v", "<leader>hr", function()
				gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end)

			map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "stage buffer" })
			map("n", "<leader>hR", gitsigns.reset_buffer, { desc = "reset buffer" })
			map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "preview hunk" })
			map("n", "<leader>hi", gitsigns.preview_hunk_inline, { desc = "preview hunk inline" })

			map("n", "<leader>hb", function()
				gitsigns.blame_line({ full = true })
			end, { desc = "open blame line full" })

			map("n", "<leader>hQ", function()
				gitsigns.setqflist("all")
			end)
			map("n", "<leader>hq", gitsigns.setqflist)

			-- Toggles
			map("n", "<leader>tb", gitsigns.toggle_current_line_blame, { desc = "toggle current line blame" })
		end,
	})
end)

require("lualine").setup({
	options = { globalstatus = true },
	sections = {
		lualine_a = {},
		lualine_b = { "branch", "diff" },
		lualine_c = { { "filename", path = 1, symbols = { modified = " ●" } } },
		lualine_x = { "diagnostics" },
	},
})

require("oil").setup({
	default_file_explorer = false,
	view_options = {
		show_hidden = true,
	},
	watch_for_changes = true,
	keymaps = {
		["<C-r>"] = "actions.refresh",
	},
})

require("snacks").setup({
	-- Disable treesitter/LSP/syntax on files >1.5MB so big generated files
	-- (minified bundles, GraphQL schemas, logs) open instantly instead of freezing.
	bigfile = { enabled = true },
	-- Indentation guides with the current scope highlighted
	indent = {
		enabled = true,
		animate = { enabled = false },
	},
	picker = {
		sources = {
			explorer = {
				layout = {
					auto_hide = { "input" },
					layout = {
						position = "right",
						width = 0.30,
					},
				},
				hidden = true,
				ignored = true,
				auto_close = false,
				win = {
					list = {
						keys = {
							["e"] = "toggle_maximize",
						},
					},
				},
			},
			smart = {
				layout = { preset = "dropdown", preview = false },
			},
		},
	},
})
vim.api.nvim_set_hl(0, "SnacksPickerTree", { fg = "#54546d", bg = "NONE" })

require("auto-session").setup({
	suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
})
-- plugins end

-- Editor settings
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.wrap = true
vim.opt.scrolloff = 8
-- vim.opt.sidescrolloff = 8
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.mouse = "a"
-- vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.laststatus = 3 -- one statusline at the bottom instead of one per window
vim.opt.updatetime = 250

vim.opt.undofile = true
vim.opt.breakindent = true

-- Fold settings: treesitter folds by default, LSP folding ranges when available (see LspAttach)
vim.o.foldcolumn = "0"
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = "" -- show the folded line with its syntax highlighting
vim.opt.foldlevel = 99 -- Allow folds to be created
vim.opt.foldlevelstart = 99 -- Open all folds when opening a file
vim.opt.foldenable = true

vim.diagnostic.config({ update_in_insert = false })

-- Close floating windows (like hover docs) and clear search highlight on Escape
vim.keymap.set("n", "<Esc>", function()
	-- Close floating windows
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local config = vim.api.nvim_win_get_config(win)
		if config.relative ~= "" then
			-- Skip snacks picker windows
			local buf = vim.api.nvim_win_get_buf(win)
			local ft = vim.bo[buf].filetype
			if not ft:match("^snacks_picker") then
				vim.api.nvim_win_close(win, false)
			end
		end
	end
	-- Clear search highlight
	vim.cmd("nohlsearch")
end, { desc = "Close popups and clear search" })

-- Window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Keep cursor centered
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Paragraph motions without jumplist
vim.keymap.set({ "n", "v" }, "{", "<cmd>keepjumps normal! {<CR>")
vim.keymap.set({ "n", "v" }, "}", "<cmd>keepjumps normal! }<CR>")

-- Entire-buffer text object: die, yie, vie, cie, etc.
vim.keymap.set({ "x", "o" }, "ie", ":<C-u>normal! ggVG<CR>", { silent = true, desc = "entire buffer" })
vim.keymap.set({ "x", "o" }, "ae", ":<C-u>normal! ggVG<CR>", { silent = true, desc = "entire buffer" })

vim.keymap.set("n", "<leader>e", function()
	local snacks = require("snacks.explorer")
	snacks.open()
end, { desc = "Toggle file explorer" })

vim.keymap.set("n", "-", "<cmd>Oil .<CR>", { desc = "Open Oil.nvim" })

vim.keymap.set("n", "<leader>u", "<cmd>Undotree<CR>", { desc = "Toggle undo tree" })

-- Picker keymaps (snacks.nvim)
vim.keymap.set("n", "<leader>sf", function()
	Snacks.picker.smart()
end, { desc = "Find files (smart)" })
vim.keymap.set("n", "<leader>sg", function()
	Snacks.picker.grep()
end, { desc = "Live grep" })
vim.keymap.set({ "n", "v" }, "<leader>su", function()
	Snacks.picker.grep_word()
end, { desc = "Grep word under cursor" })
vim.keymap.set("n", "<leader>sb", function()
	Snacks.picker.buffers()
end, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>sh", function()
	Snacks.picker.help()
end, { desc = "Help tags" })
vim.keymap.set("n", "<leader>so", function()
	Snacks.picker.recent()
end, { desc = "Recent files" })
vim.keymap.set("n", "<leader>sk", function()
	Snacks.picker.keymaps()
end, { desc = "Search keymaps" })
vim.keymap.set("n", "<leader>sr", function()
	Snacks.picker.resume()
end, { desc = "Resume last picker" })
vim.keymap.set("n", "<leader>sd", function()
	Snacks.picker.diagnostics()
end, { desc = "Workspace diagnostics" })

-- Diagnostic keymaps
vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "ge", vim.diagnostic.open_float, { desc = "Show diagnostic under cursor" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostic quickfix list" })

-- Go is formatted with tabs by gofmt, so don't expand them in Go buffers.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	group = vim.api.nvim_create_augroup("go-indent", { clear = true }),
	callback = function()
		vim.bo.expandtab = false
		vim.bo.tabstop = 4
		vim.bo.shiftwidth = 4
		vim.bo.softtabstop = 4
	end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- Command palette
local command_palette
do
	local commands = {
		{
			name = "Format file",
			action = function()
				require("conform").format({ lsp_format = "fallback", async = true })
			end,
		},
		{
			name = "Save without format",
			action = function()
				vim.b.disable_autoformat = true
				vim.cmd("write")
				vim.b.disable_autoformat = false
			end,
		},
		{
			name = "Toggle format-on-save (global)",
			action = function()
				vim.g.disable_autoformat = not vim.g.disable_autoformat
				vim.notify("format-on-save " .. (vim.g.disable_autoformat and "disabled" or "enabled"))
			end,
		},
		{
			name = "Copy file path (absolute)",
			action = function()
				local path = vim.fn.expand("%:p")
				vim.fn.setreg("+", path)
				vim.notify("Copied: " .. path)
			end,
		},
		{
			name = "Copy file path (relative)",
			action = function()
				local path = vim.fn.expand("%:.")
				vim.fn.setreg("+", path)
				vim.notify("Copied: " .. path)
			end,
		},
		{
			name = "Copy file name",
			action = function()
				local path = vim.fn.expand("%:t")
				vim.fn.setreg("+", path)
				vim.notify("Copied: " .. path)
			end,
		},
		{
			name = "Yank buffer to clipboard",
			action = function()
				vim.cmd("%y+")
				vim.notify("Yanked buffer to clipboard")
			end,
		},
		{
			name = "Restart TS server",
			action = function()
				vim.cmd("lsp restart ts_ls")
			end,
		},
		{
			name = "Restart all LSP servers",
			action = function()
				vim.cmd("lsp restart")
			end,
		},
		{
			name = "Split vertical",
			action = function()
				vim.cmd("vsplit")
			end,
		},
		{
			name = "Split horizontal",
			action = function()
				vim.cmd("split")
			end,
		},
		{
			name = "Close split",
			action = function()
				vim.cmd("close")
			end,
		},
		{
			name = "Close other splits",
			action = function()
				vim.cmd("only")
			end,
		},
		{
			name = "Close all other buffers",
			action = function()
				local current = vim.api.nvim_get_current_buf()
				local closed = 0
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if buf ~= current and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
						if pcall(vim.api.nvim_buf_delete, buf, {}) then
							closed = closed + 1
						end
					end
				end
				vim.notify("Closed " .. closed .. " buffer(s)")
			end,
		},
		{
			name = "New scratch buffer",
			action = function()
				vim.cmd("enew")
				vim.bo.buftype = "nofile"
				vim.bo.bufhidden = "wipe"
				vim.bo.swapfile = false
			end,
		},
		{
			name = "Toggle inlay hints",
			action = function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
			end,
		},
		{
			name = "Update plugins",
			action = function()
				vim.pack.update()
			end,
		},
		{
			name = "Toggle diagnostics",
			action = function()
				vim.diagnostic.enable(not vim.diagnostic.is_enabled())
			end,
		},
		{
			name = "Toggle word wrap",
			action = function()
				vim.wo.wrap = not vim.wo.wrap
			end,
		},
		{
			name = "Toggle markdown rendering",
			action = function()
				require("render-markdown").toggle()
			end,
		},
		{
			name = "Toggle spell check",
			action = function()
				vim.wo.spell = not vim.wo.spell
			end,
		},
		{
			name = "Toggle relative line numbers",
			action = function()
				vim.wo.relativenumber = not vim.wo.relativenumber
			end,
		},
		{
			name = "Open init.lua",
			action = function()
				vim.cmd("edit " .. vim.fn.stdpath("config") .. "/init.lua")
			end,
		},
		{
			name = "Restart Neovim (reload config)",
			action = function()
				vim.cmd("restart")
			end,
		},
		{
			name = "cd to git root",
			action = function()
				local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
				if vim.v.shell_error ~= 0 or not root or root == "" then
					vim.notify("Not in a git repo", vim.log.levels.WARN)
					return
				end
				vim.cmd("cd " .. vim.fn.fnameescape(root))
				vim.notify("cd " .. root)
			end,
		},
		{
			name = "Reveal current file in Oil",
			action = function()
				require("oil").open()
			end,
		},
		{
			name = "Reveal current file in snacks explorer",
			action = function()
				require("snacks").picker.explorer({ cwd = vim.fn.expand("%:p:h") })
			end,
		},
	}

	command_palette = function()
		local items = {}
		for _, cmd in ipairs(commands) do
			table.insert(items, { text = cmd.name, action = cmd.action })
		end

		Snacks.picker.pick({
			source = "command_palette",
			title = "Command Palette",
			items = items,
			layout = { preset = "select" },
			format = "text",
			confirm = function(picker, item)
				picker:close()
				if item and item.action then
					item.action()
				end
			end,
		})
	end
end

vim.keymap.set({ "n", "v" }, "<leader>k", command_palette, { desc = "Command palette" })

vim.api.nvim_create_user_command("TermHl", function()
	local b = vim.api.nvim_create_buf(false, true)
	local chan = vim.api.nvim_open_term(b, {})
	vim.api.nvim_chan_send(chan, table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"))
	vim.api.nvim_win_set_buf(0, b)
end, { desc = "Highlights ANSI termcodes in curbuf" })
