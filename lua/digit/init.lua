---@alias view_t "replace"|"split"|"vsplit"|"tab"


-- ( ) expand commit hash in uri



local digit = {}
local config = require("digit.config")
local utils = require("digit.utils")



--- Write standard output of a command to a file
--
---@param cmd string[] Command to run, as is passed to vim.system()
---@param out string Path to output file
---@param shell_dir? string Directory to run command in
function digit:_stdout_to_file(cmd, out, shell_dir)
  local res = vim.system(cmd, { cwd = shell_dir, text = true }):wait()
  if res.code ~= 0 then
    vim.notify(res.stderr, vim.log.levels.ERROR)
  else
    vim.fn.writefile(utils.split(res.stdout, "\n"), out, 'b')
  end
end



--- Get type of specified git revision
--
---@param rev string
---@param repo_dir string
---@return string Type of git object specified by rev
function digit:_get_type(rev, repo_dir)
  repo_dir = repo_dir or vim.fn.getcwd()
  local res = vim.system({"git", "cat-file", "-t", rev}, { cwd = repo_dir }):wait()

  if res.code ~= 0 then
    return ""
  end

  local type, _ = string.gsub(res.stdout, "\n", "")
  return type
end



--- Get the root directory of a repo containing a given file
--
---@param filepath string Path to file in a git repo
---@return string Absolute path to repo directory (empty string if does not exist)
function digit:_get_root(filepath)
  local dir = (vim.fn.isdirectory(filepath) == 1) and filepath or vim.fn.fnamemodify(filepath, ":h")

  local res = vim.system({"git", "rev-parse", "--show-toplevel"}, { cwd = dir, text = true }):wait()
  if res.code ~= 0 then
    vim.notify(res.stderr, vim.log.levels.ERROR)
    return ""
  end

  local root, _ = string.gsub(res.stdout, "\n", "")
  return root
end



--- Get path of file relative to the root of the conatining repo
--
---@param filepath string Path to file in a git repo
---@return string Path of file relative to root of repo (empty string if not in repo)
function digit:_path_from_root(filepath)
  local root = self:_get_root(filepath)
  if root == "" then
    return ""
  end

  -- make path relative to root of repo
  local rel_path, _ = string.gsub(vim.fn.fnamemodify(filepath, ":p"), root .. "/", "")
  return rel_path
end



--- Add filepath to current buffer if revision doesn't specify a file
--
---@param rev string
---@return string Interpolated rev
---@return boolean True if rev was interpolated, else false
function digit:_interpolate_rev(rev)
  -- if revision already specifies a file
  if string.find(rev, ":") then
    return rev, false
  end
  local filepath = self:_path_from_root(vim.api.nvim_buf_get_name(0))
  return string.format("%s:%s", rev, filepath), true
end



--- Convert a revision to a digit uri
--
---@param rev string
---@param repo_dir string
---@return string Digit uri for given revision
function digit:_rev_to_uri(rev, repo_dir)
  local commit, file = string.match(rev, "(.+):(.+)")

  -- expand commit hash
  local HASH_LEN = 7
  local res = vim.system({"git", "rev-parse", commit}, { cwd = repo_dir, text = true }):wait()
  commit = string.gsub(res.stdout, "\n", ""):sub(1, HASH_LEN)

  return string.format("digit://%s/%s/%s", self:_get_root(repo_dir), commit, file)
end



--- Create a buffer with the contents of file given by the specified git rev
--
---@param rev string Git revision
---@param repo_dir string Path to a directory in the repo
---@return integer Buffer handle of created buffer
function digit:_create_buf(rev, repo_dir)
  local uri = self:_rev_to_uri(rev, repo_dir)

  -- check if rev is already open
  -- HACK: would be better if vim.api had a function to get buffer handle based on filename
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == uri then
      vim.notify("Revision already open. Skipping buffer creation.")
      return buf
    end
  end

  local tempfile = vim.fn.tempname()
  self:_stdout_to_file({"git", "cat-file", "-p", rev}, tempfile, repo_dir)

  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("edit "..uri)
    vim.cmd(string.format("silent read %s", tempfile))
    vim.cmd("0d _")  -- delete empty line that file was inserted below
    vim.bo.buftype = "nowrite"
  end)
  return buf
end



--- Open a new window with buffer using the given view
--
---@param buf integer Buffer handle
---@param view view_t
function digit:_open_buf(buf, view)
  local view_cmds = {
    replace = "edit",
    split = "split",
    vsplit = "vsplit",
    tab = "tabedit",
  }

  local cmd = view_cmds[view]
  if cmd == nil then
    vim.notify("Invalid view", vim.log.levels.ERROR)
    return
  end
  vim.cmd(string.format("%s %s", cmd, vim.api.nvim_buf_get_name(buf)))
end



--- Open a digit buffer containing the specified rev
--
---@param rev string
---@param view view_t
function digit:open(rev, view)
  local rev, interpolated = self:_interpolate_rev(rev)
  local dir = interpolated and vim.fn.expand("%:h:p") or vim.fn.getcwd()

  -- check if valid rev
  local type = self:_get_type(rev, dir)
  if type == "" then
    vim.notify("Invalid rev. Object specified by rev does not exist.", vim.log.levels.ERROR)
    return
  elseif type ~= "blob" then
    vim.notify(string.format("Invalid git object type. Expected blob but got %s.", type), vim.log.levels.ERROR)
    return
  end

  local buf = self:_create_buf(rev, dir)
  self:_open_buf(buf, view)
end



vim.api.nvim_create_user_command("DigitOpen", function(opts)
  local num_args = #opts.fargs
  if num_args == 1 then
    digit:open(opts.fargs[1], config.default_view)
  elseif num_args == 2 then
    digit:open(opts.fargs[1], opts.fargs[2])
  else
    vim.notify("Invalid number of arguments. Expected 1 but got " .. num_args, vim.log.levels.ERROR)
    return
  end
end, {nargs = "+"})

return digit
