-- CCS811 i2c library.
--
-- Much inspiration from: https://github.com/sxwang/nodemcu-air-quality-monitoring/blob/master/app.lua
-- (skrewz: confirmed with sxwang 20200225 to licence under MIT.)

-- CCS811 constants
STATUS_REG = 0x00
MEAS_MODE_REG = 0x01
ALG_RESULT_DATA = 0x02
ENV_DATA = 0x05
THRESHOLDS = 0x10
BASELINE = 0x11
HW_ID_REG = 0x20
ERROR_ID_REG = 0xE0
APP_START_REG = 0xF4
SW_RESET = 0xFF
CCS_811_ADDRESS = 0x5A
GPIO_WAKE = 0x5
DRIVE_MODE_IDLE = 0x0
DRIVE_MODE_1SEC = 0x10
DRIVE_MODE_10SEC = 0x20
DRIVE_MODE_60SEC = 0x30
INTERRUPT_DRIVEN = 0x8
THRESHOLDS_ENABLED = 0x4

local M
do
  local self = {
    uptime_before_iaq_sensor_trusted_s = 20*60,
    i2c_id = 0,
  }

  local callbacks = {
    datapoint = function(dp) print("datapoint: "..dp) end,
    err = function(err) print("css811 err: %x"..string.byte(err)) end,
  }

  local on = function(eventname,cb)
    callbacks[eventname] = cb
  end

  -- generic i2c read.
  function read_reg(dev_addr, reg_addr, bytes)
    i2c.start(self.i2c_id)
    i2c.address(self.i2c_id, dev_addr, i2c.TRANSMITTER)
    i2c.write(self.i2c_id, reg_addr)
    i2c.stop(self.i2c_id)
    i2c.start(self.i2c_id)
    i2c.address(self.i2c_id, dev_addr, i2c.RECEIVER)
    c = i2c.read(self.i2c_id, bytes)
    i2c.stop(self.i2c_id)
    return c
  end

  -- generic i2c write.
  function write_reg(dev_addr, reg_addr, data)
    i2c.start(self.i2c_id)
    i2c.address(self.i2c_id, dev_addr, i2c.TRANSMITTER)
    if data ~= nil then
      i2c.write(self.i2c_id, reg_addr, data)
    else
      i2c.write(self.i2c_id, reg_addr)
    end
    i2c.stop(self.i2c_id)
  end

  function assert_non_error ()
    local err = read_reg(CCS_811_ADDRESS, ERROR_ID_REG, 1)
    if 0x00 ~= string.byte(err) then
      self.callbacks.err(err)
    end
  end

  -- CCS811 setup
  function setup(sda,scl,i2c_id_for_module)
    self.i2c_id = i2c_id_for_module
    -- initialize i2c, set pin1 as sda, set pin2 as scl
    if sda ~= nil and scl ~= nil then
      print("ccs811wrap: initializing i2c")
      i2c.setup(self.i2c_id, sda, scl, i2c.SLOW)
    end

    hwid = read_reg(CCS_811_ADDRESS, HW_ID_REG, 1)

    sta = read_reg(CCS_811_ADDRESS, STATUS_REG, 1)
    err = read_reg(CCS_811_ADDRESS, ERROR_ID_REG, 1)

    write_reg(CCS_811_ADDRESS, APP_START_REG)
    tmr.delay(2000) -- wait for 2ms

    sta = read_reg(CCS_811_ADDRESS, STATUS_REG, 1)
    err = read_reg(CCS_811_ADDRESS, ERROR_ID_REG, 1)

    i2c.start(self.i2c_id)
    i2c.address(self.i2c_id, CCS_811_ADDRESS, i2c.TRANSMITTER)
    i2c.write(self.i2c_id, MEAS_MODE_REG, DRIVE_MODE_1SEC)
    i2c.stop(self.i2c_id)
  end

  -- read from CCS811
  function read_ccs811()
    sta = read_reg(CCS_811_ADDRESS, STATUS_REG, 1)

    buf = read_reg(CCS_811_ADDRESS, ALG_RESULT_DATA, 8)
    eCO2 = string.byte(buf,1) * 256 + string.byte(buf,2)
    eTVOC = string.byte(buf,3) * 256 + string.byte(buf,4)
    rawI = math.floor(string.byte(buf,7) / 4)
    rawV = (string.byte(buf,7) % 4) * 256 + string.byte(buf,8)
    buf = read_reg(CCS_811_ADDRESS, BASELINE, 2)
    baseline = string.byte(buf,1) * 256 + string.byte(buf,2)
    return eCO2, eTVOC, rawI, rawV, baseline
  end

  function push_temperature_humidity (temp,hum)
    h = math.floor(hum*512)
    h_low = h % 256
    h_high = math.floor((h - h_low)/256)

    t = math.floor((temp+25)*512)
    t_low = t % 256
    t_high = math.floor((t-t_low)/256)

    --print(string.format("have h_high,h_low,t_high,t_low = %x %x %x %x", h_high, h_low, t_high,t_low))
    write_reg(CCS_811_ADDRESS,ENV_DATA,{h_high,h_low,t_high,t_low})

    assert_non_error()
  end

  function once_ccs811 ()
    local epochtm = rtctime.get()
    eCO2, eTVOC, rawI, rawV, baseline = read_ccs811()
    local dp= {
        epochtime = epochtm,
        eCO2 = eCO2,
        eTVOC = eTVOC,
        baseline = baseline,
        rawI = rawI,
        rawV = rawV,
    }
    callbacks.datapoint(dp)
  end

  local starttimer = function(interval_ms)
    self.ccs811_timer = tmr.create()
    self.ccs811_timer:register(interval_ms,tmr.ALARM_AUTO,once_ccs811)
    self.ccs811_timer:start()
  end

  -- expose
  M = {
    setup = setup,
    once_ccs811 = once_ccs811,
    starttimer = starttimer,
    push_temperature_humidity = push_temperature_humidity,
    uptime_before_iaq_sensor_trusted_s = self.uptime_before_iaq_sensor_trusted_s,
    on = on,
  }
end
return M
