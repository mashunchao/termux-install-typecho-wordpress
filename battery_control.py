
import argparse
import time
import subprocess
from miio import Device

#blog:linzimo.com

# 设置插座的IP地址和令牌
ip = "192.168.1.1"
token = "5735d4"

def get_battery_info():
    battery_info = subprocess.check_output(['termux-battery-status']).decode('utf-8')
    battery_data = {
        'level': int(battery_info.split('"level":')[1].split(',')[0]),
        'temperature': float(battery_info.split('"temperature":')[1].split(',')[0])
    }
    return battery_data

def toggle_gosund_plug(ip, token, state):
    device = Device(ip, token)
    device.send("set_properties", [{"siid": 2, "piid": 1, "did": "state", "value": state}])
    print(f"Gosund插座已{'打开' if state else '关闭'}")

# 解析命令行参数
parser = argparse.ArgumentParser(description='Battery Control')
parser.add_argument('-on', action='store_true', help='打开插座')
parser.add_argument('-off', action='store_true', help='关闭插座')
parser.add_argument('-start', action='store_true', help='开始自动检测触发开关服务')
args = parser.parse_args()


if args.on:
    toggle_gosund_plug(ip, token, True)  # 打开插座
elif args.off:
    toggle_gosund_plug(ip, token, False)  # 关闭插座
elif args.start:
    battery_low_threshold = 50  # 电池电量低于此阈值时，打开插座
    battery_high_threshold = 90  # 电池电量高于此阈值时，关闭插座
    temperature_threshold = 40  # 电池温度高于此阈值时，关闭插座

    # 运行自动开关逻辑
    while True:
        battery_data = get_battery_info()
        battery_level = battery_data['level']
        battery_temp = battery_data['temperature']

        if battery_level < battery_low_threshold:
            toggle_gosund_plug(ip, token, True)  # 打开插座
        elif battery_level > battery_high_threshold or battery_temp > temperature_threshold:
            toggle_gosund_plug(ip, token, False)  # 关闭插座

        time.sleep(60)  # 每隔60秒检查一次电池电量和温度
else:
    parser.print_help()
