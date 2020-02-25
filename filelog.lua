--[[
Simply log-to-file library.

Generally not all that useful, and be careful around the fact that this
library doesn't truncate its log file. Thus, use in production is discouraged.

--]]

local M
do
  local writeln = function(name,msg)
    fd = file.open("logs/"..name..".log", "a+")
    local tm = rtctime.epoch2cal(rtctime.get())
    fd:write(string.format("%04d/%02d/%02d %02d:%02d:%02dZ", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]) .. ": ".. msg.."\n")
    fd:close()
  end
  local getfd = function(name)
    fd = file.open("logs/"..name..".log", "r")
    return fd
  end
  -- expose
  M = {
    writeln = writeln,
    getfd = getfd,
  }
end
return M
