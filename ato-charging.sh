#!/bin/bash

#script: Automatic Battery Charging Control
#blog:linzimo.com
#environment:termux
#dependences-pkg: curl,android-tools,

#企业微信推送开关"on"开启 其他值关闭
push="off"                                                                                                                                                                                                                                                                                                                                                                                                                                  

#""内改为自己的webhook地址
webhook="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=693"

#间隔时间，单位为秒
sleep="60"

# 发送企业微信消息函数
send_wechat_notification() {
    local message="$1"
    
    if [[ "$push" == "on" ]]; then
        curl -s -k -H "Content-Type: application/json" -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"$message\"}}" "$webhook"
    fi
}

# ADB 连接函数
adb_connect() {
    # 检查设备是否已连接
    devices=$(adb devices | grep -v "List of devices attached")
    if [[ -z $devices ]]; then
        echo "未找到已连接的设备"
        return 1
    fi
    
    # IP 地址
    ip=127.0.0.1
    # 连接设备
    adb tcpip 5555
    adb connect $ip:5555
    echo "已连接设备：$ip"
}


# 自动充电函数
auto_charge() {
    # 获取电池电量百分比
    battery_level=$(adb shell dumpsys battery | grep level | awk '{print $2}')
    
    # 获取设备温度
    temperature=$(adb shell cat /sys/class/thermal/thermal_zone0/temp)
    temperature=$(($temperature/1000)) # 转换为摄氏度
    
    echo "电量：$battery_level%"
    echo "温度：$temperature°C"
    
    # 判断温度是否过高
    if [[ $temperature -gt 41 ]]; then
        echo "温度过高，停止充电"
        adb shell dumpsys battery set status discharging
        
        # 发送微信通知
        message="温度高于41度，已停止充电"
        send_wechat_notification "$message"
    elif
      # 判断电量是否低于50%
      [[ $battery_level -lt 50 ]]; then
      
          message="电量低于50%，开始充电..."
          echo "$message"
          send_wechat_notification "$message"
          adb shell dumpsys battery set status charging

    elif [[ $battery_level -gt 90 ]]; then
      
          # 判断电量是否高于90%
          message="电量高于90%，停止充电..."
          echo "$message"
          send_wechat_notification "$message"
          adb shell dumpsys battery set status discharging
    fi
}

# 主函数
main() {
    # 连接 ADB
    adb_connect
    
    # 循环执行自动充电函数
    while true; do
        auto_charge
        sleep $sleep  # 间隔时间，单位为秒
    done
}

# 执行主函数
main
