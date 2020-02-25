--[[

Wrapper library for the "raw" mqtt library. Mostly convenience stuff.

You'll likely want to configure different callbacks for this library. E.g. the
"disconnect" and "err" handlers.

--]]

local M
do
  local self = {
    m = nil,
    mqtt_client = nil,
    mqtt_client_connected = false,
  }

  -- Default callbacks:
  local callbacks = {
    err = function() print("mqtt error") end,
    message = function(topic,message) print("unmatched mqtt@topic "..topic.." message: "..message) end,
    disconnect = function() print("mqtt disconnect?") end,
  }

  -- To override callbacks:
  local on = function(eventname,cb)
    callbacks[eventname] = cb
  end

  local topicsubscriptions = {
  }
  local handletopic = function(topicname,cb)
    topicsubscriptions[topicname] = cb
  end
  

  -- Conditional "am I connected" publish function:
  local maybepublish = function (topic,message,qos)
    if self.mqtt_client_connected then
      self.mqtt_client:publish(topic, message, qos, 0)
    end
  end


  local subscribe = function(topic,qos)
    if not self.mqtt_client:subscribe(topic,qos) then
      print("Failed to subscribe to topic "..topic.."!")
    end
  end


  function reconnect (destaddr,destport,cb)
    print ("MQTT: attempting connect()")
    self.m = mqtt.Client("c"..node.chipid(), 120)

    -- on publish overflow receive event
    self.m:on("overflow", function(client, topic, data)
      print(topic .. " partial overflowed message: " .. data )
    end)
    self.m:on("message", function(client, topic, data)
      handled_already = false
      for topicmatch,cb in pairs(topicsubscriptions) do
        if topic == topicmatch then
          cb(topic,data)
          handled_already = true
        end
      end
      if not handled_already then
        callbacks.message(topic,data)
      end
    end)
    self.m:on("offline", function(client)
      self.mqtt_client_connected = false
      print ("MQTT: offline")
      callbacks.disconnect()
      tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, reconnect)
    end)

    local connect_success = self.m:connect(destaddr, destport, true, function(client)
      self.mqtt_client = client
      self.mqtt_client_connected = true
      print("MQTT: connected")
      cb()
    end,
    function(client, reason)
      print("MQTT: failed reason: " .. reason)
      callbacks.err()
    end)
    if not connect_success then
      print("No connect success!")
    end
  end

  -- expose
  M = {
    reconnect = reconnect,
    subscribe = subscribe,
    maybepublish = maybepublish,
    on = on,
    handletopic = handletopic,
  }
end
return M
