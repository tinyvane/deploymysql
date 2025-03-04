$content = Get-Content -Path "deploymysql.sh" -Raw

# Replace the problematic function with a fixed version
$reset_mysql_start = '# 添加重置MySQL密码的函数
reset_mysql_password() {'

$reset_mysql_end = '    fi
}'

$new_reset_function = @'
# 添加重置MySQL密码的函数
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
        print_warning "mysqld_safe命令不存在，尝试使用服务配置方式..."
        
        # 创建临时目录存放pid文件
        mkdir -p /var/run/mysqld
        chown mysql:mysql /var/run/mysqld 2>/dev/null || true
        
        # 尝试使用服务方式重置
        print_info "尝试使用服务管理器方式重置密码..."
        
        # 尝试创建一个临时配置文件来跳过授权表
        if [ -d "/etc/mysql/conf.d" ]; then
            echo "[mysqld]
skip-grant-tables
skip-networking" > /etc/mysql/conf.d/mysql-reset.cnf
            
            # 启动MySQL服务
            systemctl start mysql 2>/dev/null || 
            systemctl start mysqld 2>/dev/null || 
            systemctl start mariadb 2>/dev/null
            
            # 等待MySQL启动
            print_info "等待MySQL启动..."
            sleep 10
            
            # 重置root密码
            print_info "重置root密码..."
            mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
            
            if [ $? -eq 0 ]; then
                print_success "root密码重置成功"
            else
                print_error "root密码重置失败，尝试旧语法"
                
                mysql -u root <<EOF
FLUSH PRIVILEGES;
UPDATE mysql.user SET authentication_string=PASSWORD('$MYSQL_ROOT_PASS'), plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
FLUSH PRIVILEGES;
EOF
                
                if [ $? -eq 0 ]; then
                    print_success "root密码重置成功（使用旧语法）"
                else
                    print_error "root密码重置失败，请手动重置密码"
                fi
            fi
            
            # 删除临时配置并重启MySQL
            rm -f /etc/mysql/conf.d/mysql-reset.cnf
            systemctl restart mysql 2>/dev/null || 
            systemctl restart mysqld 2>/dev/null || 
            systemctl restart mariadb 2>/dev/null
        else
            print_error "无法找到MySQL配置目录，无法使用此方法重置密码"
            print_info "请尝试手动重置密码，或在有mysqld_safe命令的环境中运行此脚本"
            print_info "您可以使用以下命令手动重置密码："
            print_info "sudo mysql_secure_installation"
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
        
        # 重置root密码
        print_info "重置root密码..."
        mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
        
        if [ $? -eq 0 ]; then
            print_success "root密码重置成功"
        else
            print_error "root密码重置失败"
            
            # 尝试另一种语法（适用于较旧版本的MySQL）
            mysql -u root <<EOF
FLUSH PRIVILEGES;
UPDATE mysql.user SET authentication_string=PASSWORD('$MYSQL_ROOT_PASS'), plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
FLUSH PRIVILEGES;
EOF
            
            if [ $? -eq 0 ]; then
                print_success "root密码重置成功（使用旧语法）"
            else
                print_error "root密码重置失败，请手动重置密码"
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

# Find and replace the reset_mysql_password function with our fixed version
$startIndex = $content.IndexOf($reset_mysql_start)
$endIndex = $content.IndexOf($reset_mysql_end, $startIndex) + $reset_mysql_end.Length
$content = $content.Substring(0, $startIndex) + $new_reset_function + $content.Substring($endIndex)

# Fix any extra curly braces in the secure_mysql function
$content = $content -replace "return 0\s+}\s+}", "return 0`n}"

# Also fix the main function call at the end
$content = $content -replace "done\s+}\s+\n\s*#\s*执行主函数\s+main", "done`n}`n`n# 执行主函数`nmain"

Set-Content -Path "deploymysql.sh" -Value $content -NoNewline 