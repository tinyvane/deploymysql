# 修复MySQL密码重置函数的PowerShell脚本
# 作者：Claude
# 日期：2024-03-15

# 读取原始脚本文件
$filePath = "deploymysql.sh"
$content = Get-Content -Path $filePath -Raw

# 定义新的reset_mysql_password函数
$new_reset_mysql_password = @'
# 重置MySQL root密码函数
reset_mysql_password() {
    print_info "尝试重置MySQL root密码..."
    
    # 确认重置
    echo ""
    echo "需要重置MySQL root密码。"
    echo "请输入 'YES' 确认重置:"
    read confirm
    
    if [ "$confirm" != "YES" ]; then
        print_info "密码重置已取消"
        return 1
    fi
    
    # 停止MySQL服务
    print_info "停止MySQL服务..."
    systemctl stop mysql 2>/dev/null
    systemctl stop mysqld 2>/dev/null
    systemctl stop mariadb 2>/dev/null
    
    # 检查mysqld_safe命令是否存在
    if ! command -v mysqld_safe >/dev/null 2>&1; then
        print_warning "mysqld_safe命令不存在，尝试使用配置文件方式..."
        
        # 创建临时目录存放pid文件
        mkdir -p /var/run/mysqld
        chown mysql:mysql /var/run/mysqld 2>/dev/null || true
        
        # 尝试使用服务方式重置
        print_info "尝试使用服务管理器方式重置密码..."
        print_info "这种方式需要系统管理员权限..."
        
        # 尝试创建一个临时配置文件来跳过授权表
        MYSQL_CONF_DIR=""
        for dir in "/etc/mysql/conf.d" "/etc/my.cnf.d" "/etc/mysql"; do
            if [ -d "$dir" ]; then
                MYSQL_CONF_DIR="$dir"
                break
            fi
        done
        
        if [ -n "$MYSQL_CONF_DIR" ]; then
            echo "[mysqld]
skip-grant-tables
skip-networking" > "$MYSQL_CONF_DIR/mysql-reset.cnf"
            
            # 启动MySQL服务
            systemctl start mysql 2>/dev/null || 
            systemctl start mysqld 2>/dev/null || 
            systemctl start mariadb 2>/dev/null
            
            # 等待MySQL启动
            print_info "等待MySQL启动..."
            sleep 10
            
            # 重置root密码 - 首先尝试新语法
            print_info "重置root密码..."
            mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
            
            RESET_RESULT=$?
            if [ $RESET_RESULT -eq 0 ]; then
                print_success "root密码重置成功"
            else
                print_warning "使用新语法重置密码失败，尝试旧语法..."
                
                # 尝试使用旧语法
                mysql -u root <<EOF
FLUSH PRIVILEGES;
UPDATE mysql.user SET authentication_string=PASSWORD('$MYSQL_ROOT_PASS'), plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
FLUSH PRIVILEGES;
EOF
                
                RESET_RESULT=$?
                if [ $RESET_RESULT -eq 0 ]; then
                    print_success "root密码重置成功（使用旧语法）"
                else
                    print_error "root密码重置失败，尝试MariaDB特定语法..."
                    
                    # 尝试MariaDB特定语法
                    mysql -u root <<EOF
FLUSH PRIVILEGES;
UPDATE mysql.user SET Password=PASSWORD('$MYSQL_ROOT_PASS') WHERE User='root';
FLUSH PRIVILEGES;
EOF
                    
                    if [ $? -eq 0 ]; then
                        print_success "root密码重置成功（使用MariaDB语法）"
                    else
                        print_error "无法重置root密码，请手动重置"
                        # 删除临时配置并重启MySQL
                        rm -f "$MYSQL_CONF_DIR/mysql-reset.cnf"
                        systemctl restart mysql 2>/dev/null || 
                        systemctl restart mysqld 2>/dev/null || 
                        systemctl restart mariadb 2>/dev/null
                        return 1
                    fi
                fi
            fi
            
            # 删除临时配置并重启MySQL
            rm -f "$MYSQL_CONF_DIR/mysql-reset.cnf"
            systemctl restart mysql 2>/dev/null || 
            systemctl restart mysqld 2>/dev/null || 
            systemctl restart mariadb 2>/dev/null
        else
            print_error "无法找到MySQL配置目录，无法使用此方法重置密码"
            print_info "请尝试手动重置密码，或在有mysqld_safe命令的环境中运行此脚本"
            return 1
        fi
    else
        # 以跳过授权表的方式启动MySQL
        print_info "以安全模式启动MySQL..."
        
        # 创建临时目录存放pid文件
        mkdir -p /var/run/mysqld
        chown mysql:mysql /var/run/mysqld 2>/dev/null || true
        
        # 启动MySQL安全模式
        print_info "启动MySQL安全模式，这可能需要一些时间..."
        mysqld_safe --skip-grant-tables --skip-networking &
        
        # 等待MySQL启动
        print_info "等待MySQL启动..."
        sleep 10
        
        # 重置root密码 - 首先尝试新语法
        print_info "重置root密码..."
        mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
        
        RESET_RESULT=$?
        if [ $RESET_RESULT -eq 0 ]; then
            print_success "root密码重置成功"
        else
            print_warning "使用新语法重置密码失败，尝试旧语法..."
            
            # 尝试使用旧语法
            mysql -u root <<EOF
FLUSH PRIVILEGES;
UPDATE mysql.user SET authentication_string=PASSWORD('$MYSQL_ROOT_PASS'), plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
FLUSH PRIVILEGES;
EOF
            
            RESET_RESULT=$?
            if [ $RESET_RESULT -eq 0 ]; then
                print_success "root密码重置成功（使用旧语法）"
            else
                print_error "无法重置root密码，请手动重置密码"
            fi
        fi
        
        # 停止MySQL安全模式
        print_info "停止MySQL安全模式..."
        pkill mysqld
    fi
    
    # 重启MySQL服务
    print_info "重启MySQL服务..."
    systemctl start mysql 2>/dev/null || systemctl start mysqld 2>/dev/null || systemctl start mariadb 2>/dev/null
    
    # 等待服务启动
    sleep 5
    
    # 验证密码
    print_info "验证新密码..."
    if mysql -u root -p"$MYSQL_ROOT_PASS" -e "SELECT 'Password reset successful';" >/dev/null 2>&1; then
        print_success "密码验证成功，MySQL root密码已重置"
        return 0
    else
        print_error "密码验证失败，请手动检查MySQL状态"
        print_info "您可能需要使用以下命令手动完成密码重置:"
        print_info "sudo mysql_secure_installation"
        return 1
    fi
}
'@

# 检查是否已经包含reset_mysql_password函数
if ($content -match "reset_mysql_password\(\)") {
    Write-Host "找到现有的reset_mysql_password函数，准备替换..."
    
    # 使用正则表达式替换整个函数定义
    $pattern = "(?ms)# .*?添加重置MySQL密码的函数\s*reset_mysql_password\(\)\s*\{.*?\}"
    $content = [regex]::Replace($content, $pattern, $new_reset_mysql_password)
} else {
    Write-Host "未找到reset_mysql_password函数，准备添加..."
    
    # 在secure_mysql函数前添加
    $insertPoint = $content.IndexOf("# 配置MySQL安全设置")
    if ($insertPoint -ne -1) {
        $content = $content.Substring(0, $insertPoint) + $new_reset_mysql_password + "`n`n" + $content.Substring($insertPoint)
    } else {
        Write-Host "无法找到插入点，尝试在脚本末尾添加..."
        # 在main函数调用前添加
        $mainCallPoint = $content.LastIndexOf("# 执行主函数")
        if ($mainCallPoint -ne -1) {
            $content = $content.Substring(0, $mainCallPoint) + $new_reset_mysql_password + "`n`n" + $content.Substring($mainCallPoint)
        } else {
            # 直接添加到文件末尾
            $content += "`n`n" + $new_reset_mysql_password
        }
    }
}

# 保存修改后的文件
Set-Content -Path $filePath -Value $content -NoNewline

Write-Host "完成! reset_mysql_password函数已更新。" 