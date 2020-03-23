--
-- This is almost a direct copy from
-- https://github.com/nodemcu/nodemcu-firmware/blob/master/lua_examples/lfs/HTTP_OTA.lua
--

local host, dir, image = ...

local doRequest, firstRec, subsRec, finalise
local n, total, size = 0, 0

doRequest = function(sk,hostIP)
  if hostIP then
    local con = net.createConnection(net.TCP,0)
    con:connect(80,hostIP)
    -- Note that the current dev version can only accept uncompressed LFS images
    con:on("connection",function(sck)
      local request = table.concat( {
        "GET "..dir..image.." HTTP/1.1",
        "User-Agent: ESP8266 app (linux-gnu)",
        "Accept: application/octet-stream",
        "Accept-Encoding: identity",
        "Host: "..host,
        "Connection: close",
        "", "", }, "\r\n")
        print(request)
        sck:send(request)
        sck:on("receive",firstRec)
      end)
  end
end

firstRec = function (sck,rec)
  -- Process the headers; only interested in content length
  local i      = rec:find('\r\n\r\n',1,true) or 1
  local header = rec:sub(1,i+1):lower()
  size         = tonumber(header:match('\ncontent%-length: *(%d+)\r') or 0)
  -- e.g.: mon, 23 mar 2020 16:48:24 gmt
  last_modified = header:match('\nlast%-modified: *([%w ,:]+)') or "unmatched"
  print(rec:sub(1, i+1))
  if size > 0 then
    file.putcontents("lfs.modified",last_modified)
    sck:on("receive",subsRec)
    file.open("lfs_inc.img", 'w')
    subsRec(sck, rec:sub(i+4))
  else
    sck:on("receive", nil)
    sck:close()
    print("GET failed")
  end
end

subsRec = function(sck,rec)
  total, n = total + #rec, n + 1
  if n % 4 == 1 then
    sck:hold()
    node.task.post(0, function() sck:unhold() end)
  end
  uart.write(0,('%u of %u, '):format(total, size))
  file.write(rec)
  if total == size then finalise(sck) end
end

finalise = function(sck)
  file.close()
  sck:on("receive", nil)
  sck:close()
  local s = file.stat("lfs_inc.img")
  if (s and size == s.size) then
    print("\n\nreceived image "..image.." in good order; now restarting to re-flash from lfs_inc.img")
    node.restart()
  else
    print"Invalid save of image file"
  end
end

net.dns.resolve(host, doRequest)
