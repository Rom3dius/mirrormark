-- mirrormark/lua/md_nextcloud_sync/init.lua
-- Bi‑directional Markdown ⇄ Nextcloud sync via rclone
-- License: MIT

local M = {}
M.config = {}

-- ========================================================================= --
--  Helpers
-- ========================================================================= --

--- Classify a stderr line into a log level (or nil to skip)
---@param line string
---@return integer|nil vim_log_level
local function classify_line(line)
	-- normalize for case-insensitive matching
	local l = line:lower()
	-- completely ignore the bisync beta notice
	if l:find("bisync is in beta") or l:find("notice:.*bisync") then
		return nil
	end
	-- warnings
	if l:find("bisync critical error") or l:find("bisync aborted") or l:find("must run --resync") then
		return vim.log.levels.WARN
	end
	-- everything else is an error
	return vim.log.levels.ERROR
end

---Run an rclone command asynchronously and surface errors in :messages.
---@param args string[] full rclone command (first element must be executable)
---@param opts table|nil additional jobstart opts
local function run_rclone(args, opts)
	opts = opts or {}
	opts.stdout_buffered = true
	opts.stderr_buffered = true
	opts.on_stderr = function(_, data)
		if data then
			vim.schedule(function()
				for _, ln in ipairs(data) do
					if ln ~= "" then
						local lvl = classify_line(ln)
						if lvl then
							vim.notify(ln, lvl)
						end
					end
				end
			end)
		end
	end
	opts.on_exit = function(_, code)
		-- automatically create bisync baseline on first run
		if code == 2 and args[2] == "bisync" and not vim.tbl_contains(args, "--resync") then
			vim.schedule(function()
				vim.notify("[mirrormark] First run - creating bisync baseline", vim.log.levels.WARN)
			end)
			local retry = vim.deepcopy(args)
			table.insert(retry, 3, "--resync") -- insert after 'bisync'
			vim.fn.jobstart(retry, opts)
			return
		end
		if code ~= 0 then
			vim.schedule(function()
				vim.notify(string.format("[mirrormark] rclone exited with code %d", code), vim.log.levels.ERROR)
			end)
		end
		if opts.after_exit then
			opts.after_exit(code)
		end
	end
	vim.fn.jobstart(args, opts)
end

---Canonical absolute path with no trailing slash
local function abs_path(p)
	return vim.fn.fnamemodify(p, ":p"):gsub("/+$", "")
end

---Resolve config entry into local_root and remote_root
---@param entry string
---@return string local_root
---@return string remote_root
local function resolve_paths(entry)
	local local_root = abs_path(entry)
	local remote_root = string.format(
		"%s:%s/%s",
		M.config.rclone_remote,
		M.config.remote_root:gsub("/+$", ""), -- strip trailing slash
		vim.fn.fnamemodify(local_root, ":t")
	) -- folder basename
	return local_root, remote_root
end

-- ========================================================================= --
--  Sync operations
-- ========================================================================= --

function M.bisync_folder(entry)
	local local_root, remote_root = resolve_paths(entry)
	run_rclone({
		M.config.rclone_binary or "rclone",
		"bisync",
		remote_root,
		local_root,
		"--create-empty-src-dirs",
		"--fast-list",
	})
end

function M.bisync_all()
	for _, entry in ipairs(M.config.folders) do
		M.bisync_folder(entry)
	end
end

function M.copy_file(filepath)
	filepath = abs_path(filepath)
	for _, entry in ipairs(M.config.folders) do
		local local_root, remote_root = resolve_paths(entry)
		if filepath:sub(1, #local_root) == local_root and filepath:match("%.md$") then
			local rel = filepath:sub(#local_root + 2)
			local remote_file = remote_root .. "/" .. rel
			run_rclone({
				M.config.rclone_binary or "rclone",
				"copyto",
				filepath,
				remote_file,
				"--no-traverse",
			}, {
				after_exit = function()
					-- Pull possible remote changes for this file
					run_rclone({
						M.config.rclone_binary or "rclone",
						"copyto",
						remote_file,
						filepath,
						"--no-traverse",
					})
				end,
			})
			break
		end
	end
end

-- ========================================================================= --
--  Autocommands
-- ========================================================================= --
local function setup_autocmds()
	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			M.bisync_all()
		end,
	})
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*.md",
		callback = function(args)
			M.copy_file(args.file)
		end,
	})
end

-- ========================================================================= --
--  Public API
-- ========================================================================= --
---@param user_config table
function M.setup(user_config)
	M.config = vim.tbl_extend("force", {
		rclone_binary = "rclone", -- path to rclone executable
		rclone_remote = "nc-webdav", -- rclone remote alias
		remote_subdir = nil, -- required subfolder inside the remote
	}, user_config or {})

	if type(M.config.folders) ~= "table" then
		vim.notify('[md_nextcloud_sync] "folders" must be a list', vim.log.levels.ERROR)
		return
	end
	if not M.config.remote_root or M.config.remote_root == "" then
		vim.notify('[mirrormark] You must supply "remote_root', vim.log.levels.ERROR)
		return
	end
	setup_autocmds()
end

return M
