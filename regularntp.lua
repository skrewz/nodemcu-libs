--[[

Wrapper library to handle regular NTP operations.

--]]

local M
do
  local self = {
    last_ntp_sync = 0,
    ntp_sync_interval_s = 86400,
    ntp_server = "au.pool.ntp.org",
    ntp_timer = tmr.create()
  }
  local callbacks = {
    sync = function () end
  }

  local once_ntp = function()
    sntp.sync(self.ntp_server,
      function(sec, usec, server, info)
        rtctime.set(sec, usec)
        self.last_ntp_sync, usec, r = rtctime.get()
        print ("synced NTP")
        if time_boot == nil then
          time_boot = self.last_ntp_sync
        end
        callbacks.sync()
      end,
      function()
        print('NTP sync failed!')
        node.restart()
      end
    )
  end
  local once_ntp_maybe = function()
    local cur_time, usec, r = rtctime.get()
    if 0 == self.last_ntp_sync or self.last_ntp_sync + self.ntp_sync_interval_s < cur_time then
      once_ntp()
    end
  end

  local start_timer = function()
    self.ntp_timer:register(10*1000,tmr.ALARM_AUTO,once_ntp_maybe)
    self.ntp_timer:start()
  end
  local on = function(eventname,cb)
    callbacks[eventname] = cb
  end

  -- expose
  M = {
    on = on,
    once_ntp = once_ntp,
    once_ntp_maybe = once_ntp_maybe,
    start_timer = start_timer
  }
end
return M
