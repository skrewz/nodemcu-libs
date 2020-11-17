-- PMS5003 library
--
-- The PMS5003 is a PM2.5 (with extrapolations) particle counter which spews
-- out a 32 byte protocol over 3.3V UART. This library wraps that behaviour and
-- makes it callback-driven from an application perspective.
--
-- According to its datasheet, the PMS5003 needs 30 seconds of warmup after
-- being enabled before readings can be relied upon. Further, the PMS5003
-- longetivity will be greatly diminished if the laser sensor is run
-- continuously. An ideal mode of operation is thus to e.g. enable the sensor
-- every several minutes, allow it to run for 30 seconds, and then shut the
-- sensor back down once the first trustworthy reading has been obtained.
--
-- This interaction pattern is exactly what this library allows. Sample:
--
--    pms5003.setup(some_pin)
--    pms5003.on('datapoint',
--      function (pm1_ug_m3, pm25_ug_m3, pm10_ug_m3, count_003,
--                count_005, count_010, count_025, count_050, count_100)
--        -- (do something with data point)
--        pms5003.disable_sensor()
--      end
--    )
--    tmr_meas = tmr.create()
--    -- iniatiate measurement every 600s:
--    tmr_meas:register(600000, tmr.ALARM_AUTO, function ()
--        pms5003.enable_sensor()
--    end)
--    tmr_meas:start()
--
-- This assumes you use uart 0, and that you sacrifice your serial console to
-- the MCU. This happens when you call setup(set_pin). Thus, the wiring goes:
--
-- PMS5003         <-->  NodeMCU
--   VCC (pin 1)   <-->  Vin (5V, from USB, or 5V from other source)
--   GND (pin 2)   <-->  GND
--   SET (pin 3)   <-->  set_pin (unused GPIO of your choice, passed to setup())
--   RXD (pin 4)   <-->  Not connected
--   TXD (pin 5)   <-->  RXD
--
-- Other wires can remain unconnected. The set_pin business can be omitted if
-- you don't want to use enable_sensor()/disable_sensor(). Leaving the PMS5003
-- pin unconnected will cause the fan/chip to remain constantly on.

local M
do
  local self = {
    uptime_before_pms5003_trusted = 30,
    rotating_array = {},
    excessive_bytes = {},
    currently_reading_byte_no = nil,
    sensor_started_at = nil,
    last_consistent_read = nil
  }

  local callbacks = {
    datapoint = function(dp) print("datapoint: "..dp) end,
    err = function(err) print("pms5003 err: %x"..string.byte(err)) end,
  }

  local on = function(eventname,cb)
    callbacks[eventname] = cb
  end

  -- Returns:
  -- - PM1.0 μg/m³ (atmospheric conditions)
  -- - PM2.5 μg/m³ (atmospheric conditions)
  -- - PM10 μg/m³ (atmospheric conditions)
  -- - Particle count > 0.3μm / 0.1l
  -- - Particle count > 0.5μm / 0.1l
  -- - Particle count > 1.0μm / 0.1l
  -- - Particle count > 2.5μm / 0.1l
  -- - Particle count > 5.0μm / 0.1l
  -- - Particle count > 10μm / 0.1l
  local parse_last_byte_array = function()

    if not self.last_consistent_read then
      return nil
    else
      arr = self.last_consistent_read
      return
                               -- Data  1: PM1.0 μg/m³ (standard particle, factory environment)
                               -- Data  2: PM2.5 μg/m³ (standard particle, factory environment)
                               -- Data  3: PM10 μg/m³ (standard particle, factory environment)
         256*arr[10]+arr[11],  -- Data  4: PM1.0 μg/m³ (atmospheric conditions)
         256*arr[12]+arr[13],  -- Data  5: PM2.5 μg/m³ (atmospheric conditions)
         256*arr[14]+arr[15],  -- Data  6: PM10 μg/m³ (atmospheric conditions)
         256*arr[16]+arr[17],  -- Data  7: Particle count > 0.3μm / 0.1l
         256*arr[18]+arr[19],  -- Data  8: Particle count > 0.5μm / 0.1l
         256*arr[20]+arr[21],  -- Data  9: Particle count > 1.0μm / 0.1l
         256*arr[22]+arr[23],  -- Data 10: Particle count > 2.5μm / 0.1l
         256*arr[24]+arr[25],  -- Data 11: Particle count > 5.0μm / 0.1l
         256*arr[26]+arr[27]   -- Data 12: Particle count > 10μm / 0.1l
    end
  end

  local handle_bytes = function(data)
    for i = 1, #data do
      local byte = string.byte(data,i)
      -- Handle start byte, reset currently_reading_byte_no:
      if nil == self.currently_reading_byte_no and 0x42 == byte then
        self.currently_reading_byte_no = 0
      end

      if 1 == self.currently_reading_byte_no then

        if 0x4d ~= byte then -- lost track; possibly spurious 0x42
          self.currently_reading_byte_no = nil
        end
      end

      if nil ~= self.currently_reading_byte_no then
        self.rotating_array[self.currently_reading_byte_no] = byte
        self.currently_reading_byte_no = 1 + self.currently_reading_byte_no
      end

      if self.currently_reading_byte_no == 32 then
        local checksum = 0
        for i = 0, 29 do
           checksum = checksum + self.rotating_array[i]
        end
        checksum = checksum % 256

        if self.rotating_array[31] == checksum then
          -- This was a checksum-matching consistent read; store it:
          if self.sensor_started_at + self.uptime_before_pms5003_trusted < rtctime.get() then
            self.last_consistent_read = self.rotating_array
            
            node.task.post(
              node.task.MEDIUM_PRIORITY,
              function()
                callbacks.datapoint(parse_last_byte_array())
              end
            )
          end
        end
        self.currently_reading_byte_no = nil
      end
    end
  end

  local disable_sensor = function()
    self.last_consistent_read = nil
    self.currently_reading_byte_no = nil
    gpio.write(self.set_pin,gpio.LOW)
  end

  local enable_sensor = function()
    gpio.write(self.set_pin,gpio.HIGH)
    self.sensor_started_at = rtctime.get()
  end

  -- This setup method does not enable_sensor()
  local setup = function(set_pin)
    self.set_pin = set_pin
    gpio.mode(self.set_pin,gpio.OUTPUT)
    uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
    uart.on("data", 32, handle_bytes, 0)
  end

  -- expose
  M = {
    setup = setup,
    uptime_before_pms5003_trusted = self.uptime_before_pms5003_trusted,
    disable_sensor = disable_sensor,
    enable_sensor = enable_sensor,
    on = on,
  }
end
return M
