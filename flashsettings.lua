--[[

Simple persist setting to filesystem library. Can be useful for e.g. letting a
particular device know which location it occupies.

--]]



local M
do
  local set = function(name,value)
    --print ("set("..name..","..value..")...")
    local fd = file.open("settings/"..name, "w")
    fd:write(value)
    fd:close()
  end
  local get = function(name,default)
    --print ("get("..name..","..default..")...")
    if file.exists("settings/"..name) then
      local fd = file.open("settings/"..name, "r")
      if fd ~= nil then
        local justread = fd:read()
        fd:close()
        return justread
      end
    end
    return default
  end
  -- expose
  M = {
    set = set,
    get = get,
  }
end
return M
