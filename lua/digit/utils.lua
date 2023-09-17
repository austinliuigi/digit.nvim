local utils = {}

--- Split a string at a delimeter into a list of strings
--
---@param str string String to split
---@param delim string Delimeter to split on
function utils.split(str, delim)
  local result = {}
  for line in (str..delim):gmatch(('([^%s]*)[%s]'):format(delim, delim)) do
    table.insert(result, line)
  end
  return result
end

return utils
