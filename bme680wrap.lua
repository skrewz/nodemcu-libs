-- Wrapper library for the "raw" bme680 module shipped with NodeMCU-firmware.

local M
do
  local self = {
    bme680_timer = nil,
    altitude = 40,
    uptime_before_gas_sensor_trusted_s = 20*60,
  }

  local callbacks = {
    datapoint = function(dp)
      -- Default handler; you're likely to want to overrule this with the .on() method:
      print("datapoint: "..dp)
    end,
  }

  local on = function(eventname,cb)
    callbacks[eventname] = cb
  end


  local once_bme680 = function()

    local data = {}
    -- delay calculated by formula provided by Bosch: 121 ms, minimum working (empirical): 150 ms
    -- skrewz: setting 200ms; have no need for speed
    bme680.startreadout(200, function ()
      T, P, H, G, QNH = bme680.read(self.altitude)
      if T then
          local Tsgn = (T < 0 and -1 or 1); T = Tsgn*T
          local epochtm = rtctime.get()
          D = bme680.dewpoint(H, T)
          local Dsgn = (D < 0 and -1 or 1); D = Dsgn*D

          data = {
            epochtime = epochtm,
            T = (Tsgn<0 and -1 or 1)* T/100,
            QFE = P/100,
            QNH = QNH/100,
            H = H/1000,
            D = (Dsgn<0 and -1 or 1)* D/100,
            G = G,
          }

          callbacks.datapoint(data)
      end
    end)
  end

  local setup = function(sda,scl,i2c_id_for_module)
    -- If this library is called with sda or scl set to nil, we enter I2C reuse
    -- mode, and no reinitialisation is carried out:
    if sda ~= nil and scl ~= nil then
      print("bme680wrap: initializing i2c")
      i2c.setup(i2c_id_for_module, sda, scl, i2c.SLOW)
    end
    bme680.setup()
  end

  local starttimer = function(interval_ms)
    self.bme680_timer = tmr.create()
    self.bme680_timer:register(interval_ms,tmr.ALARM_AUTO,once_bme680)
    self.bme680_timer:start()
  end
  -- expose
  M = {
    setup = setup,
    once_bme680 = once_bme680,
    starttimer = starttimer,
    on = on,
    uptime_before_gas_sensor_trusted_s = self.uptime_before_gas_sensor_trusted_s,
  }
end
return M
