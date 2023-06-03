#!/bin/bash

# 颜色选择
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
font="\n \033[0m"
cyan='\033[0;36m'

#备份配置文件路径
config_file="$HOME/www/blog.conf"

#待备份文件夹路径
wwwroot=$HOME/www/typecho/usr/uploads

# 定义备份保存目录
backup_dir="$HOME/typecho_backup"

if [ -f "$config_file" ]; then
    #导入配置文件中的变量
    source "$config_file"
else
    echo "配置文件未找到 请先配置 Config file not found: $config_file"
fi

#配置邮箱服务器
configure_smtp() {

    config_file="$HOME/www/blog.conf"
    if [ -f "$config_file" ]; then
        source "$config_file"
    else
        echo "配置文件未找到 Config file not found: $config_file"
        read -p "是否创建新的配置文件？create a new config file? (y/n): " choice
        if [[ $choice == "y" ]]; then
            echo "Creating config file: $config_file"

            cat <<EOT > "$config_file"

#STML_CONFIG_START#
send_email_enabled="no" #是否启用发送邮件功能 可选值 yes no
custom_subject="xxx主机的Typecho数据库和usr备份"
smtp_address="smtp.gmail.com"
smtp_port="587"
smtp_user="user@gmail.com"
smtp_password="password"111
recipient_email="recipient@example.com"
smtp_tls="on"

#数据库信息
db_host="127.0.0.1"
db_user="root"
db_password="password"
db_name="typecho"

update_period="1" #时间间隔单位天
last_backup_time=""
#STML_CONFIG_END#

EOT
        fi
    fi
    
    #引入文件变量
    source "$config_file"
    
    echo "========== Backup/SMTP 配置 =========="
    echo "路径 $HOME/www/blog.conf "
    echo "请输入 SMTP 配置选项。如果未提供输入，将使用默认值"

    echo -e "${cyan}"
    
    echo "------------数据库------------"
    
    read -p "(1/12) 数据库地址（DB Host） [$db_host]: " input_db_host
    db_host=${input_db_host:-$db_host}

    read -p "(2/12) 数据库用户（DB User） [$db_user]: " input_db_user
    db_user=${input_db_user:-$db_user}

    read -p "(3/12) 数据库用户密码（DB Password）: " input_db_password
    db_password=${input_db_password:-$db_password}

    read -p "(4/12) 数据库名称（DB Name） [$db_name]: " input_db_name
    db_name=${input_db_name:-$db_name}

    echo -e "${font}"

    echo "------------备份------------"
    
    read -p "(5/12) 更新周期(天)（Update Period） [$update_period]: " input_update_period
    update_period=${input_update_period:-$update_period}
    
    echo "------------邮箱服务 ------------"

    read -p "(6/12) 发送邮件功能开关(yes开 no关)（send_email_enabled） [$send_email_enabled]: " input_send_email_enabled
    send_email_enabled=${input_send_email_enabled:-$send_email_enabled}

    read -p "(7/12) 自定义主题-用来区别邮件来源（Custom Subject） [$custom_subject]: " input_custom_subject
    custom_subject=${input_custom_subject:-$custom_subject}

    read -p "(8/12) SMTP 服务器地址（SMTP Address） [$smtp_address]: " input_smtp_address
    smtp_address=${input_smtp_address:-$smtp_address}

    read -p "(9/12) SMTP tls加密(on)（smtp_tls）[$smtp_tls]: " input_smtp_tls
    smtp_tls=${input_smtp_tls:-$smtp_tls}

    read -p "(10/12) SMTP 用户-你的邮箱（SMTP User）[$smtp_port]: " input_smtp_user
    smtp_user=${input_smtp_user:-$smtp_user}

    read -p "(11/12) SMTP 密码-谷歌邮箱服务需两步认证生成密码（SMTP Password）: " input_smtp_password
    smtp_password=${input_smtp_password:-$smtp_password}

    read -p "(12/12) 接收邮箱（Recipient Email） [$recipient_email]: " input_recipient_email
    recipient_email=${input_recipient_email:-$recipient_email}

    sed -i "/#STML_CONFIG_START#/,/#STML_CONFIG_END#/{ 
            s|db_host=.*|db_host=\"$db_host\"|;
            s|db_user=.*|db_user=\"$db_user\"|;
            s|db_password=.*|db_password=\"$db_password\"|;
            s|send_email_enabled=.*|send_email_enabled=\"$send_email_enabled\"|;
            s|db_name=.*|db_name=\"$db_name\"|;
            s|custom_subject=.*|custom_subject=\"$custom_subject\"|;
            s|smtp_address=.*|smtp_address=\"$smtp_address\"|;
            s|smtp_tls=.*|smtp_tls=\"$smtp_tls\"|;
            s|smtp_port=.*|smtp_port=\"$smtp_port\"|;
            s|smtp_user=.*|smtp_user=\"$smtp_user\"|;
            s|smtp_password=.*|smtp_password=\"$smtp_password\"|;
            s|recipient_email=.*|recipient_email=\"$recipient_email\"|;
            s|update_period=.*|update_period=\"$update_period\"|;
        }" $config_file


    echo "SMTP configuration saved to $config_file."
}

#使用示例：send_email <附件路径>
send_email() {

    # 检查 msmtp 是否安装
    if ! command -v msmtp >/dev/null 2>&1; then
        echo "msmtp未安装，在发送邮件之前请先安装msmtp"
        exit 1
    fi

    #创建邮件消息
    email_message=$(mktemp)
    echo "From: $sender_email" >> $email_message
    echo "To: $recipient_email" >> $email_message
    echo "Subject: $email_subject" >> $email_message
    echo "" >> $email_message
    echo "$message" >> $email_message

    # 添加附件
    if [[ -n "$1" ]]; then
        echo "" >> $email_message
        echo "--boundary" >> $email_message
        echo "Content-Type: application/octet-stream" >> $email_message
        echo "Content-Disposition: attachment; filename=\"$(basename $1)\"" >> $email_message
        echo "" >> $email_message
        cat "$1" >> $email_message
        echo "" >> $email_message
        echo "--boundary--" >> $email_message
    fi

    # 定义发送邮件重试次数和最大重试次数
    retry_attempts=0
    max_retry=5

    # 循环尝试发送邮件，直到成功或达到最大重试次数
    while [ $retry_attempts -lt $max_retry ]; do
        #cat $email_message | msmtp --from=$sender_email --host=$smtp_server --tls=$smtp_tls --tls-certcheck=off --port=$smtp_port --auth=on --user=$smtp_user --passwordeval="echo $smtp_password" $recipient_email
        cat $email_message | msmtp --from=jfuugghcuc@gmail.com --host=smtp.gmail.com --port=587 --tls=on --tls-starttls=on --auth=on --user=jfuugghcuc@gmail.com --passwordeval="echo pngwujvctbeppnxp" $recipient_email
        if [ $? -eq 0 ]; then
            echo "邮件发送成功！"
            break
        fi
        
        # 休眠一段时间后重试
        retry_attempts=$((retry_attempts+1))
        sleep 60  
        echo "休眠60s后重试"
    done

    # 检查重试次数
    if [ $retry_attempts -eq $max_retry ]; then
        echo "达到最大重试次数，邮件发送失败！"
    fi
    
    # 清除临时邮件内容
    rm $email_message
}

#执行备份 
start_backup() {

    #导入配置文件中的变量
    if [ -f "$config_file" ]; then
        source "$config_file"
    else
        echo "配置文件未找到 请先配置 Config file not found: $config_file"
    fi

    # 创建备份目录(如果不存在)
    mkdir -p "$backup_dir"

    # 检查必要的数据库配置是否为空
    if [[ -z "$db_host" || -z "$db_user" || -z "$db_password" || -z "$db_name" ]]; then
        echo "错误：请在配置文件中提供所有必需的数据库配置选项"
        exit 1
    fi

    # 定义日期格式
    date_format="%Y%m%d%H%M%S"

    # 定义过期备份时间（7 天）
    expire_time=$(date -d "7 days ago" +"$date_format")

    echo "当前系统时间."
    LANG=zh_CN.UTF-8 date +"%Y年%m月%d日 %H时%M分%S秒"

    # 备份数据库
    echo -e "备份数据库...\n"
    db_backup_file="$backup_dir/db_backup_$(date +$date_format).sql"
    if ! mysqldump -h "$db_host" -u "$db_user" -p"$db_password" "$db_name" > "$db_backup_file"; then
        echo "数据库备份失败！，别忘了开启web（数据库） 服务才可以进行备份"
        return 1
    fi

    #备份wwwroot文件夹
    echo -e "备份uploads文件夹...\n"
    uploads_backup_dir="$backup_dir/uploads_backup_$(date +$date_format)"
    if ! cp -R $wwwroot "$uploads_backup_dir"; then
        echo "usr 文件夹备份失败！"
        return 1
    fi

    # 压缩备份文件
    echo -e "压缩数据库备份和uploads文件夹...\n"
    backup_zip="$backup_dir/backup_$(date +$date_format).zip"
    if ! zip -rj "$backup_zip" "$db_backup_file" "$uploads_backup_dir"; then
        echo "备份文件压缩失败！"
        return 1
    fi

    #备份完成后更新上次备份时间
    last_backup_time=$(date +"$date_format")
    sed -i "s|last_backup_time=.*|last_backup_time=\"$last_backup_time\"|" "$config_file"
    echo "Typecho 数据库和 upload 文件夹备份完成！\n"

    echo -e "保存路径 $backup_dir\n"

    # 清理过期备份文件
    echo "查询清理过期备份文件（7 天）..."
    if ! find "$backup_dir" -name "*.sql" -mtime +"$expire_time" -type f -delete; then
        echo "清理过期数据库备份失败！"
        return 1
    fi
    if ! find "$backup_dir" -name "usr_backup_*" -mtime +"$expire_time" -type d -exec rm -r {} +; then
        echo "清理过期 uploads文件夹备份失败！"
        return 1
    fi
    if ! find "$backup_dir" -name "*.zip" -mtime +"$expire_time" -type f -delete; then
        echo "清理过期备份压缩文件失败！"
        return 1
    fi

    # 清理临时备份文件
    rm -rf "$uploads_backup_dir"
 			rm "$db_backup_file"
	
    # 判断是否启用发送邮件功能
    if [[ "$send_email_enabled" == "yes" ]]; then
        # 定义附件路径
        attachment_path="$backup_zip"
        # 调用发送函数
        echo "正在发邮件"
        send_email "$attachment_path"
    else
        echo "\n你选择不通过邮件服务，如果需要，请在配置文件选项选择(yes)"
    fi
}

show_menu() {
    clear
    echo "=== 自动备份服务菜单 ==="
    echo "1. 开启备份/发送邮件(需配置)"
    echo "2. 查看配置文件"
    echo "3. 创建、更改配置文件"
    echo "4. 退出"
    read -p "请选择一个选项: " choice
    handle_menu_choice "$choice"
}

handle_menu_choice() {
    case $1 in
        1)
													start_backup
            ;;
        2)
            echo -e "${cyan}---------------------------------"
            cat $config_file
            echo -e "---------------------------------${font}"
            ;;
        3)
            configure_smtp
            ;;
        4)
            return
            ;;
        *)
            echo "无效的选项，请重新选择"
            ;;
        esac
    read -p "ctr+c 退出 按回车键继续..."
    show_menu
}

show_menu
