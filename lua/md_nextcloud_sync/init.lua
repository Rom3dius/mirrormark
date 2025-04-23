-- md_nextcloud_sync/lua/md_nextcloud_sync/init.lua
-- Asynchronous Markdown → Nextcloud WebDAV sync with structured folders
-- License: MIT

local M = {}
M.config = {}

-- Cache of remote directories created during this Neovim session.
local created_dirs = {}

-- ========================================================================= --
--  Utility helpers
-- ========================================================================= --

---URL‑encode a string **without** touching '/' so path hierarchy is preserved.
---@param s string
---@return string
local function urlencode(s)
	if not s or s == "" then
		return ""
	end
	-- keep alphanum, dot, dash, underscore, slash and space (space → %20 later)
	s = s:gsub("([^%w%.%-%_/ ])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
	return s:gsub(" ", "%%20")
end

---Join two URL parts, guaranteeing exactly one slash in between.
local function urljoin(a, b)
	if a:sub(-1) == "/" then
		a = a:sub(1, -2)
	end
	if b:sub(1, 1) == "/" then
		b = b:sub(2)
	end
	return a .. "/" .. b
end

---Run a curl command asynchronously and pipe any stderr to vim.notify.
---@param cmd string[]
local function run_curl(cmd)
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.schedule(function()
					vim.notify(
						string.format("[md_nextcloud_sync] curl exited with code %d", code),
						vim.log.levels.ERROR
					)
				end)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				vim.schedule(function()
					vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
				end)
			end
		end,
	})
end

-- ========================================================================= --
--  Remote directory management
-- ========================================================================= --

---Ensure a (possibly nested) directory exists on the WebDAV share.
---@param dir string  relative path, no leading '/'
local function ensure_remote_dir(dir)
	if dir == "" or created_dirs[dir] then
		return
	end

	-- Build progressive paths: foo/bar → {"foo", "foo/bar"}
	local segments, accum = {}, ""
	for seg in dir:gmatch("[^/]+") do
		accum = (accum == "" and seg) or (accum .. "/" .. seg)
		table.insert(segments, accum)
	end

	for _, partial in ipairs(segments) do
		if not created_dirs[partial] then
			local mk_url = urljoin(M.config.nextcloud_url, urlencode(partial))
			local cmd = string.format(
				'curl -s -o - -w "%%{http_code}" -u "%s:%s" -X MKCOL "%s"',
				M.config.nextcloud_user,
				M.config.nextcloud_pass,
				mk_url
			)
			local handle = io.popen(cmd)
			if handle then
				local status = handle:read("*a"):match("(%d%d%d)$") or "000"
				handle:close()
				local code = tonumber(status)
				if code == 201 or code == 405 or code == 409 then -- Created | exists
					created_dirs[partial] = true
				else
					vim.notify(
						string.format("[md_nextcloud_sync] MKCOL %s failed (HTTP %s)", partial, status),
						vim.log.levels.ERROR
					)
					return
				end
			end
		end
	end
end

-- ========================================================================= --
--  File upload routines
-- ========================================================================= --

---Upload one Markdown file, preserving directory structure.
---@param filepath string absolute local path
---@param remote_name string relative remote path (rootName/…)
local function upload_file(filepath, remote_name)
	-- Ensure parent directories exist first.
	local dir_part = remote_name:match("^(.*)/[^/]+$") or ""
	ensure_remote_dir(dir_part)

	local remote_url = urljoin(M.config.nextcloud_url, urlencode(remote_name))
	local cmd = {
		"curl",
		"-sS",
		"-f",
		"-u",
		string.format("%s:%s", M.config.nextcloud_user, M.config.nextcloud_pass),
		"--upload-file",
		filepath,
		remote_url,
	}
	run_curl(cmd)
end

---Recursively upload every *.md in a local root folder preserving structure.
---@param local_root string
local function sync_folder(local_root)
	local abs_root = vim.fn.fnamemodify(local_root, ":p"):gsub("/+$", "")
	local root_name = vim.fn.fnamemodify(abs_root, ":t")
	local find_cmd = string.format('find %s -type f -name "*.md"', vim.fn.shellescape(abs_root))
	local handle = io.popen(find_cmd)
	if not handle then
		return
	end
	for filepath in handle:lines() do
		local rel = filepath:sub(#abs_root + 2) -- strip leading slash
		local remote_name = root_name .. "/" .. rel
		upload_file(filepath, remote_name)
	end
	handle:close()
end

-- ========================================================================= --
--  Public helpers
-- ========================================================================= --

function M.sync_all()
	for _, folder in ipairs(M.config.folders) do
		sync_folder(folder)
	end
end

function M.sync_file(filepath)
	filepath = vim.fn.fnamemodify(filepath, ":p")
	for _, folder in ipairs(M.config.folders) do
		local abs = vim.fn.fnamemodify(folder, ":p"):gsub("/+$", "")
		if filepath:sub(1, #abs) == abs and filepath:match("%.md$") then
			local rel = filepath:sub(#abs + 2)
			local root_name = vim.fn.fnamemodify(abs, ":t")
			local remote_name = root_name .. "/" .. rel
			upload_file(filepath, remote_name)
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
			M.sync_all()
		end,
	})
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*.md",
		callback = function(args)
			M.sync_file(args.file)
		end,
	})
end

-- ========================================================================= --
--  Public API
-- ========================================================================= --
---@param user_config table
function M.setup(user_config)
	M.config = user_config or {}
	local required = { "folders", "nextcloud_user", "nextcloud_pass", "nextcloud_url" }
	for _, key in ipairs(required) do
		if not M.config[key] or M.config[key] == "" then
			vim.notify("[md_nextcloud_sync] Missing required config: " .. key, vim.log.levels.ERROR)
			return
		end
	end
	if type(M.config.folders) ~= "table" then
		vim.notify("[md_nextcloud_sync] 'folders' must be a list of directory paths", vim.log.levels.ERROR)
		return
	end
	setup_autocmds()
end

return M
