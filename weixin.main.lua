-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "sms_forwarding"
VERSION = "1.0.0"

log.info("main", PROJECT, VERSION)

sys = require("sys")
require "sysplus"
log.info("fskv", "init complete", fskv.init())
local luatsms = {}
local receive_message_key = "messages"
local send_message_key = "send_messages"
luatsms.sim_number = ""
luatsms.api_url = ""
luatsms.control_phones = { "" }
luatsms.db = {
    init = function(key)
        local msgs = fskv.get(key)
        if msgs == nil then
            fskv.set(key, {})
        end
    end,
    add = function(key, text)
        local msgs = fskv.get(key)
        table.insert(msgs,text)
        fskv.set(key, msgs)
    end,
    get = function(key)
        local msgs = fskv.get(key)
        local sms = table.remove(msgs,1)
        fskv.set(key, msgs)
        return sms
    end,
    count = function(key)
        local msgs = fskv.get(key)
        return #msgs
    end,
    is_control_phone = function(phone)
        for i=1, #(luatsms.control_phones) do      
            if phone:endsWith(luatsms.control_phones[i]) then
                return true
            end
        end
        return false
    end,
    send = function(text)
        sys.taskInit(function()
            local body = {
                msgtype = "text",
                text = {
                    content = text
                }
            }
            local json_body = string.gsub(json.encode(body), "\\b", "\\n")
            for i=1,5 do
                code, h, body = http.request(
                        "POST",
                        luatsms.api_url,
                        {["Content-Type"] = "application/json; charset=utf-8"},
                        json_body
                    ).wait()
                log.info("notify","pushed sms notify",code,h,body)
                if code == 200 then
                    break
                end
                sys.wait(3000)
            end
        end)
    end
}

--初始化消息数据库
luatsms.db.init(receive_message_key)
luatsms.db.init(send_message_key)

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 1000)--3s喂一次狗
end
mobile.ipv6(false)
-- SIM 自动恢复, 周期性获取小区信息, 网络遇到严重故障时尝试自动恢复等功能
mobile.setAuto(10000, 300000, 8, true, 120000)
--运营商给的dns经常抽风，手动指定
socket.setDNS(nil, 1, "119.29.29.29")
socket.setDNS(nil, 2, "180.184.1.1")
--定时GC一下
sys.timerLoopStart(function()
    collectgarbage("collect")
end, 3000)

-- 联网后会发一次这个消息
sys.subscribe("IP_READY", function(ip, adapter)
    log.info("mobile", "IP_READY", ip, (adapter or -1) == socket.LWIP_GP)
end)

-- 通话相关,当前仅Air780EPV支持VoLTE通话功能
local is_calling = false
local in_comingcall_message = ""
sys.subscribe("CC_IND", function(status)
    if cc == nil then return end
    if status == "INCOMINGCALL" then
        -- 来电事件, 期间会重复触发
        if is_calling then return end
        is_calling = true
        log.info("cc_status", "INCOMINGCALL", "来电事件", cc.lastNum())
        in_comingcall_message = luatsms.sim_number.."\n来电号码【"..cc.lastNum().."】\n来电时间"..os.date("%Y-%m-%d %H:%M:%S")
        return
    end

    if status == "DISCONNECTED" then
        -- 挂断事件
        is_calling = false
        log.info("cc_status", "DISCONNECTED", "挂断事件", cc.lastNum())

        -- 发送通知
        local sms = in_comingcall_message.."\n挂断时间"..os.date("%Y-%m-%d %H:%M:%S")
        luatsms.db.add(receive_message_key, sms)
        sys.publish("NOTIFY_SMS")
        return
    end

    log.info("cc_status", status)
end)
--订阅短信消息
sys.subscribe("SMS_INC",function(phone,data)
    --来新消息了
    log.info("notify","got sms",phone,data)
    local sms = luatsms.sim_number.."\n"..os.date("%Y-%m-%d %H:%M:%S").."\n来自【"..phone.."】\n内容："..data
    luatsms.db.add(receive_message_key, sms)
    if luatsms.db.is_control_phone(phone) and data:startsWith("msg") then
        local split_char = string.sub(data, 4, 4)
        local msg = string.split(data, split_char)
        log.info("add send msg", msg[2], "message", msg[3])
        luatsms.db.add(send_message_key, {msg[2], msg[3]})
        sys.publish("SEND_SMS")
    end
    sys.publish("NOTIFY_SMS")
end)


sys.taskInit(function()
    while true do
        print("ww",collectgarbage("count"))
        while luatsms.db.count(receive_message_key) > 0 do
            collectgarbage("collect")--防止内存不足
            luatsms.db.send(luatsms.db.get(receive_message_key))
        end
        log.info("notify","wait for a new sms~")
        print("zzz",collectgarbage("count"))
        sys.waitUntil("NOTIFY_SMS")
    end
end)

sys.taskInit(function()
    while true do
        print("ww",collectgarbage("count"))
        while luatsms.db.count(send_message_key) > 0 do
            collectgarbage("collect")--防止内存不足
            local msg = luatsms.db.get(send_message_key)
            log.info("send to", msg[1], "message", msg[2])
            sms.send(msg[1], msg[2])
        end
        print("zzz",collectgarbage("count"))
        sys.waitUntil("SEND_SMS")
    end
end)

-- 用户代码已结束---------------------------------------------
-- 结尾总是这一句
sys.run()
-- sys.run()之后后面不要加任何语句!!!!!
