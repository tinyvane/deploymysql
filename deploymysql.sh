#!/bin/bash

# MySQL/MariaDB 一键部署与管理脚本
# 作者：Claude
# 日期：2024-02-26

# 脚本版本
SCRIPT_VERSION="1.0.2"
GITHUB_REPO="tinyvane/deploymysql"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 数据库配置
DB_NAME="myapp_database"
DB_USER="app_user"
# 密码变量初始化为空，将在需要时提示用户输入
DB_PASS=""
MYSQL_ROOT_PASS=""

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 获取数据库密码
get_database_passwords() {
    # 只有当密码为空时才询问
    if [ -z "$DB_PASS" ]; then
        read -sp "请输入应用数据库用户密码: " DB_PASS
        echo
    fi
    
    if [ -z "$MYSQL_ROOT_PASS" ]; then
        read -sp "请输入MySQL root密码: " MYSQL_ROOT_PASS
        echo
    fi
}

# 检查是否以root用户运行
check_root() {
    if [ "$(id -u)" != "0" ]; then
        print_error "此脚本需要以root权限运行"
        print_info "请使用 'sudo bash deploymysql.sh' 重新运行"
        exit 1
    fi
}

# 检测Linux发行版
detect_distro() {
    print_info "检测Linux发行版..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        ID=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
        ID=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
        ID=$(echo $DISTRIB_ID | tr '[:upper:]' '[:lower:]')
    else
        OS=$(uname -s)
        VER=$(uname -r)
        ID=$(echo $OS | tr '[:upper:]' '[:lower:]')
    fi
    
    # 提取主版本号
    MAJOR_VER=$(echo $VER | cut -d. -f1)
    
    print_success "检测到系统: $OS $VER (ID: $ID, 主版本: $MAJOR_VER)"
}

# 安装MySQL - Debian/Ubuntu
install_mysql_debian() {
    # 获取密码
    get_database_passwords
    
    print_info "在 Debian/Ubuntu 上安装 MySQL..."
    
    # 更新软件包列表
    apt update
    
    # 安装MySQL
    DEBIAN_FRONTEND=noninteractive apt install -y mysql-server
    
    # 启动MySQL服务
    systemctl start mysql
    
    # 设置开机自启
    systemctl enable mysql
    
    print_success "MySQL 安装完成"
}

# 安装MariaDB - 作为替代方案
install_mariadb() {
    # 获取密码
    get_database_passwords
    
    print_info "安装 MariaDB 作为替代方案..."
    
    if command -v dnf >/dev/null; then
        # RHEL/CentOS/Rocky 8+
        print_info "使用dnf安装MariaDB..."
        # 确保安装MariaDB服务器包
        dnf install -y mariadb-server || {
            print_error "使用dnf安装MariaDB失败，尝试使用yum..."
            yum install -y mariadb-server || {
                print_error "使用yum安装MariaDB也失败"
                return 1
            }
        }
    elif command -v yum >/dev/null; then
        # RHEL/CentOS 7
        print_info "使用yum安装MariaDB..."
        yum install -y mariadb-server || {
            print_error "使用yum安装MariaDB失败"
            return 1
        }
    elif command -v apt >/dev/null; then
        # Debian/Ubuntu
        print_info "使用apt安装MariaDB..."
        apt update
        apt install -y mariadb-server || {
            print_error "使用apt安装MariaDB失败"
            return 1
        }
    else
        print_error "无法安装MariaDB，未找到支持的包管理器"
        return 1
    fi
    
    # 启动MariaDB服务
    print_info "启动 MariaDB 服务..."
    systemctl start mariadb || {
        print_error "无法启动 MariaDB 服务"
        return 1
    }
    
    # 设置开机自启
    print_info "设置 MariaDB 开机自启..."
    systemctl enable mariadb
    
    # 等待服务完全启动
    print_info "等待 MariaDB 服务启动..."
    sleep 10
    
    # 检查服务状态
    print_info "检查 MariaDB 服务状态..."
    systemctl status mariadb --no-pager
    
    # 使用交互式方式运行安全配置
    print_info "执行安全配置..."
    print_info "请按照提示完成 MariaDB 安全配置..."
    print_info "建议设置 root 密码为: $MYSQL_ROOT_PASS"
    mysql_secure_installation
    
    # 验证安全配置是否成功
    if mysql -u root -p -e "SELECT 1;" &>/dev/null; then
        print_success "MariaDB 安全配置完成"
    else
        print_warning "无法验证 MariaDB 安全配置，请确认您设置的密码"
    fi
    
    # 创建项目数据库和用户
    print_info "创建项目数据库和用户..."
    
    print_info "使用您提供的 root 密码创建项目数据库和用户..."
    mysql -u root -p"$MYSQL_ROOT_PASS" << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_success "数据库和用户创建完成"
    else
        print_error "数据库和用户创建失败"
        return 1
    fi
    
    # 配置远程访问
    print_info "配置远程访问..."
    
    # 创建自定义配置文件
    print_info "创建自定义配置文件..."
    mkdir -p /etc/my.cnf.d/
    
    cat > /etc/my.cnf.d/mariadb-server-custom.cnf << EOF
[mysqld]
bind-address = 0.0.0.0
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[client]
default-character-set = utf8mb4
EOF

    print_success "自定义配置文件创建完成"
    
    # 查找 MariaDB 配置文件
    local MARIADB_CONF=""
    for conf_path in "/etc/my.cnf.d/mariadb-server.cnf" "/etc/my.cnf.d/server.cnf" "/etc/my.cnf"; do
        if [ -f "$conf_path" ]; then
            MARIADB_CONF="$conf_path"
            break
        fi
    done
    
    if [ -z "$MARIADB_CONF" ]; then
        print_warning "找不到 MariaDB 配置文件，但已创建自定义配置文件"
    else
        print_info "使用配置文件: $MARIADB_CONF"
        
        # 备份原配置文件
        cp "$MARIADB_CONF" "${MARIADB_CONF}.bak"
        
        # 修改 bind-address
        if grep -q "bind-address" "$MARIADB_CONF"; then
            sed -i 's/bind-address.*=.*/bind-address = 0.0.0.0/' "$MARIADB_CONF"
        else
            # 找到 [mysqld] 部分并添加 bind-address
            if grep -q "\[mysqld\]" "$MARIADB_CONF"; then
                sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' "$MARIADB_CONF"
            else
                # 如果没有 [mysqld] 部分，则添加
                echo -e "\n[mysqld]\nbind-address = 0.0.0.0" >> "$MARIADB_CONF"
            fi
        fi
    fi
    
    # 重启 MariaDB 服务
    print_info "重启 MariaDB 服务应用配置..."
    systemctl restart mariadb || {
        print_error "无法重启 MariaDB 服务"
        return 1
    }
    
    # 开放防火墙端口
    if command -v firewall-cmd >/dev/null 2>&1; then
        print_info "配置防火墙..."
        firewall-cmd --permanent --add-service=mysql
        firewall-cmd --reload
        print_success "防火墙配置完成"
    elif command -v ufw >/dev/null 2>&1; then
        print_info "配置UFW防火墙..."
        ufw allow mysql
        print_success "UFW防火墙配置完成"
    else
        print_warning "未检测到支持的防火墙，请手动开放3306端口"
    fi
    
    print_success "MariaDB 安装和配置完成"
    return 0
}

# 安装MySQL - RHEL/CentOS/Rocky
install_mysql_rhel() {
    # 获取密码
    get_database_passwords
    
    print_info "在 RHEL/CentOS/Rocky 上安装 MySQL..."
    
    # 检查是否是RHEL/CentOS 8+或Rocky Linux
    if [ "$MAJOR_VER" -ge 8 ]; then
        print_info "检测到 RHEL/CentOS 8+ 或 Rocky Linux，使用dnf安装..."
        
        # 安装MySQL仓库
        if [ ! -f /etc/yum.repos.d/mysql-community.repo ]; then
            print_info "添加MySQL仓库..."
            dnf install -y https://dev.mysql.com/get/mysql80-community-release-el${MAJOR_VER}-1.noarch.rpm || {
                print_error "无法添加MySQL仓库，尝试安装MariaDB作为替代..."
                install_mariadb
                return $?
            }
            
            # 禁用默认的AppStream仓库中的MySQL模块
            dnf module disable -y mysql
        fi
        
        # 导入MySQL GPG密钥
        print_info "导入MySQL GPG密钥..."
        rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
        
        # 安装MySQL服务器
        print_info "安装MySQL服务器..."
        dnf install -y mysql-community-server || {
            print_warning "标准安装失败，尝试禁用GPG检查安装..."
            dnf install -y --nogpgcheck mysql-community-server || {
                print_error "无法安装MySQL服务器，尝试安装MariaDB作为替代..."
                install_mariadb
                return $?
            }
        }
    else
        # RHEL/CentOS 7
        print_info "检测到 RHEL/CentOS 7，使用yum安装..."
        
        # 安装MySQL仓库
        if [ ! -f /etc/yum.repos.d/mysql-community.repo ]; then
            print_info "添加MySQL仓库..."
            yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm || {
                print_error "无法添加MySQL仓库，尝试安装MariaDB作为替代..."
                install_mariadb
                return $?
            }
        fi
        
        # 导入MySQL GPG密钥
        print_info "导入MySQL GPG密钥..."
        rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
        
        # 清理yum缓存
        print_info "清理yum缓存..."
        yum clean all
        
        # 安装MySQL服务器
        print_info "安装MySQL服务器..."
        yum install -y mysql-community-server || {
            print_warning "标准安装失败，尝试禁用GPG检查安装..."
            yum install -y --nogpgcheck mysql-community-server || {
                print_error "无法安装MySQL服务器，尝试安装MariaDB作为替代..."
                install_mariadb
                return $?
            }
        }
    fi
    
    # 启动MySQL服务
    print_info "启动MySQL服务..."
    systemctl start mysqld || {
        print_error "无法启动MySQL服务"
        return 1
    }
    
    # 设置开机自启
    print_info "设置MySQL开机自启..."
    systemctl enable mysqld
    
    # 获取临时密码
    print_info "获取MySQL临时root密码..."
    TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
    
    if [ -n "$TEMP_PASS" ]; then
        print_info "找到临时密码: $TEMP_PASS"
    else
        print_warning "MySQL日志文件不存在，无法获取临时密码"
    fi
    
    # 验证MySQL/MariaDB是否安装成功
    if command -v mysql >/dev/null 2>&1; then
        if systemctl is-active --quiet mysqld || systemctl is-active --quiet mariadb; then
            print_success "数据库服务安装完成并正在运行"
            return 0
        else
            print_error "数据库服务安装完成但未运行"
            return 1
        fi
    else
        print_error "数据库客户端命令不可用，安装可能失败"
        return 1
    fi
}

# 安装MySQL - 其他发行版
install_mysql_other() {
    # 获取密码
    get_database_passwords
    
    print_warning "未能识别的Linux发行版: $OS"
    print_info "尝试通用安装方法..."
    
    # 尝试使用通用方法安装
    if command -v apt >/dev/null; then
        install_mysql_debian
    elif command -v dnf >/dev/null; then
        install_mysql_rhel
    elif command -v yum >/dev/null; then
        install_mysql_rhel
    else
        print_error "无法安装MySQL。请手动安装后再运行此脚本的配置部分。"
        exit 1
    fi
}

# 配置MySQL安全设置
secure_mysql() {
    # 获取密码
    get_database_passwords
    
    print_info "配置数据库安全设置..."
    
    # 检查MySQL/MariaDB是否已安装
    if ! command -v mysql >/dev/null 2>&1; then
        print_error "数据库未安装或不在PATH中，无法配置安全设置"
        return 1
    fi
    
    # 检查是否是Debian/Ubuntu
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        print_info "设置root密码..."
        mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';" 2>/dev/null || {
            print_warning "无法设置root密码，尝试MariaDB方式"
            mysqladmin -u root password "$MYSQL_ROOT_PASS" 2>/dev/null || {
                print_warning "无法设置root密码，可能需要手动设置"
                return 1
            }
        }
    else
        # 对于CentOS/RHEL/Rocky，使用临时密码登录并修改
        if [ -n "$TEMP_PASS" ]; then
            mysql --connect-expired-password -u root -p"$TEMP_PASS" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;" 2>/dev/null || {
                print_warning "使用临时密码设置root密码失败，尝试MariaDB方式"
                mysqladmin -u root password "$MYSQL_ROOT_PASS" 2>/dev/null || {
                    print_warning "无法设置root密码，可能需要手动设置"
                    return 1
                }
            }
        else
            print_warning "无法获取临时密码，尝试MariaDB方式设置root密码"
            mysqladmin -u root password "$MYSQL_ROOT_PASS" 2>/dev/null || {
                print_warning "无法设置root密码，可能需要手动设置"
                return 1
            }
        fi
    fi
    
    # 使用新密码执行安全设置
    print_info "执行安全设置..."
    mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF 2>/dev/null || return 1
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
    
    print_success "数据库安全设置完成"
    return 0
}

# 创建数据库和用户
setup_database() {
    # 获取密码
    get_database_passwords
    
    print_info "创建数据库和用户..."
    
    # 检查MySQL是否已安装
    if ! command -v mysql >/dev/null 2>&1; then
        print_error "MySQL未安装或不在PATH中，无法创建数据库"
        return 1
    fi
    
    mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF 2>/dev/null || return 1
CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
    
    print_success "数据库 '$DB_NAME' 和用户 '$DB_USER' 创建完成"
    return 0
}

# 配置MySQL远程访问
configure_remote_access() {
    print_info "配置MySQL远程访问..."
    
    # 找到MySQL配置文件
    MYSQL_CONF=""
    for conf_path in "/etc/mysql/mysql.conf.d/mysqld.cnf" "/etc/my.cnf" "/etc/mysql/my.cnf"; do
        if [ -f "$conf_path" ]; then
            MYSQL_CONF="$conf_path"
            break
        fi
    done
    
    if [ -z "$MYSQL_CONF" ]; then
        print_error "找不到MySQL配置文件"
        return 1
    fi
    
    print_info "使用配置文件: $MYSQL_CONF"
    
    # 备份原配置文件
    cp "$MYSQL_CONF" "${MYSQL_CONF}.bak"
    
    # 修改bind-address
    if grep -q "bind-address" "$MYSQL_CONF"; then
        sed -i 's/bind-address.*=.*/bind-address = 0.0.0.0/' "$MYSQL_CONF"
    else
        echo "bind-address = 0.0.0.0" >> "$MYSQL_CONF"
    fi
    
    # 确保添加了以下内容，允许远程访问
    # 确保 MySQL 监听所有网络接口
    if grep -q "mysqlx-bind-address" "$MYSQL_CONF"; then
        sed -i 's/mysqlx-bind-address.*=.*/mysqlx-bind-address = 0.0.0.0/' "$MYSQL_CONF"
    fi
    
    # 重启MySQL服务
    if systemctl is-active --quiet mysql; then
        systemctl restart mysql
    elif systemctl is-active --quiet mysqld; then
        systemctl restart mysqld
    else
        print_warning "无法重启MySQL服务，请手动重启"
        return 1
    fi
    
    print_success "MySQL远程访问配置完成"
    return 0
}

# 导入初始数据
import_initial_data() {
    # 获取密码
    get_database_passwords
    
    print_info "检查是否存在初始数据文件..."
    
    # 检查MySQL是否已安装
    if ! command -v mysql >/dev/null 2>&1; then
        print_error "MySQL未安装或不在PATH中，无法导入数据"
        return 1
    fi
    
    if [ -f "backend/init.sql" ]; then
        print_info "导入初始数据..."
        mysql -u root -p"$MYSQL_ROOT_PASS" $DB_NAME < backend/init.sql 2>/dev/null && {
            print_success "初始数据导入完成"
            return 0
        } || {
            print_error "初始数据导入失败"
            return 1
        }
    else
        print_warning "未找到初始数据文件 (backend/init.sql)"
        return 1
    fi
}

# 显示连接信息
show_connection_info() {
    # 如果密码为空，尝试从配置文件获取
    if [ -z "$DB_PASS" ] || [ -z "$MYSQL_ROOT_PASS" ]; then
        print_info "尝试获取数据库配置信息..."
        # 这里可以添加从配置文件读取密码的逻辑
        # 如果无法获取，可以提示用户手动输入
        get_database_passwords
    fi
    
    print_info "MySQL连接信息:"
    echo ""
    echo "==================================================="
    echo "  数据库连接信息:"
    echo "---------------------------------------------------"
    echo "  主机: $(hostname -I | awk '{print $1}')"
    echo "  端口: 3306"
    echo "  数据库名: $DB_NAME"
    echo "  用户名: $DB_USER"
    echo "  密码: $DB_PASS"
    echo "==================================================="
    echo ""
    print_info "请确保在防火墙/安全组中开放3306端口"
    print_info "在应用程序中使用以上信息连接数据库"
}

# 检查MySQL状态
check_mysql_status() {
    print_info "检查MySQL状态..."
    
    if command -v mysql >/dev/null 2>&1; then
        if systemctl is-active --quiet mysql || systemctl is-active --quiet mysqld; then
            print_success "MySQL 服务正在运行"
            
            # 尝试连接数据库
            if mysql -u root -p"$MYSQL_ROOT_PASS" -e "SELECT VERSION();" >/dev/null 2>&1; then
                print_success "可以使用root用户连接到MySQL"
                
                # 检查项目数据库
                if mysql -u root -p"$MYSQL_ROOT_PASS" -e "USE $DB_NAME;" >/dev/null 2>&1; then
                    print_success "项目数据库 '$DB_NAME' 存在"
                else
                    print_warning "项目数据库 '$DB_NAME' 不存在"
                fi
            else
                print_warning "无法使用root用户连接到MySQL，密码可能不正确"
            fi
        else
            print_error "MySQL 服务未运行"
        fi
    else
        print_error "MySQL 未安装"
    fi
}

# 添加卸载MySQL/MariaDB的函数
uninstall_database() {
    print_info "卸载数据库服务..."
    
    # 确认卸载
    echo ""
    echo "警告: 此操作将删除所有数据库数据和配置!"
    echo "请输入 'YES' 确认卸载:"
    read confirm
    
    if [ "$confirm" != "YES" ]; then
        print_info "卸载已取消"
        return 0
    fi
    
    # 停止服务
    print_info "停止数据库服务..."
    systemctl stop mysql 2>/dev/null
    systemctl stop mysqld 2>/dev/null
    systemctl stop mariadb 2>/dev/null
    
    # 根据不同发行版卸载
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        print_info "在Debian/Ubuntu上卸载数据库..."
        apt purge -y mysql-server mysql-client mysql-common mariadb-server
        apt autoremove -y
        apt autoclean
    elif [[ "$ID" == "centos" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "rocky" ]] || [[ "$ID" == "almalinux" ]]; then
        print_info "在RHEL/CentOS/Rocky上卸载数据库..."
        if [ "$MAJOR_VER" -ge 8 ]; then
            dnf remove -y mysql-server mysql mysql-community-* mariadb mariadb-server
            dnf module reset -y mysql
        else
            yum remove -y mysql-server mysql mysql-community-* mariadb mariadb-server
        fi
    else
        print_warning "未能识别的Linux发行版，尝试通用方法..."
        if command -v apt >/dev/null; then
            apt purge -y mysql-server mysql-client mysql-common mariadb-server
            apt autoremove -y
        elif command -v dnf >/dev/null; then
            dnf remove -y mysql-server mysql mysql-community-* mariadb mariadb-server
        elif command -v yum >/dev/null; then
            yum remove -y mysql-server mysql mysql-community-* mariadb mariadb-server
        else
            print_error "无法确定如何卸载数据库，请手动卸载"
            return 1
        fi
    fi
    
    # 删除数据目录
    print_info "删除数据目录..."
    rm -rf /var/lib/mysql
    rm -rf /var/lib/mariadb
    rm -rf /etc/mysql
    rm -rf /etc/my.cnf
    rm -rf /etc/my.cnf.d
    
    print_success "数据库卸载完成"
    return 0
}

# 修改备份函数，使用交互方式输入密码
backup_database() {
    print_info "备份所有数据库..."
    BACKUP_FILE="/tmp/mysql_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    print_info "请输入数据库root密码:"
    mysqldump --all-databases -u root -p > "$BACKUP_FILE" && {
        print_success "数据库备份完成: $BACKUP_FILE"
        return 0
    } || {
        print_error "数据库备份失败"
        return 1
    }
}

# 修改升级MySQL函数，使用交互方式输入密码
upgrade_mysql() {
    print_info "开始升级MySQL..."
    
    # 检查MySQL是否已安装
    if ! command -v mysql >/dev/null 2>&1; then
        print_error "MySQL未安装，无法升级"
        return 1
    fi
    
    # 获取当前版本
    CURRENT_VERSION=$(mysql -V | awk '{print $3}')
    print_info "当前MySQL版本: $CURRENT_VERSION"
    
    # 备份数据库
    backup_database || {
        print_error "数据库备份失败，中止升级"
        return 1
    }
    
    # 根据不同发行版执行升级
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        print_info "在Debian/Ubuntu上升级MySQL..."
        apt update
        apt upgrade -y mysql-server
    elif [[ "$ID" == "centos" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "rocky" ]] || [[ "$ID" == "almalinux" ]]; then
        print_info "在RHEL/CentOS/Rocky上升级MySQL..."
        if [ "$MAJOR_VER" -ge 8 ]; then
            dnf upgrade -y mysql-community-server
        else
            yum upgrade -y mysql-community-server
        fi
    else
        print_warning "未能识别的Linux发行版，尝试通用方法..."
        if command -v apt >/dev/null; then
            apt update
            apt upgrade -y mysql-server
        elif command -v dnf >/dev/null; then
            dnf upgrade -y mysql-community-server
        elif command -v yum >/dev/null; then
            yum upgrade -y mysql-community-server
        else
            print_error "无法确定如何升级MySQL，请手动升级"
            return 1
        fi
    fi
    
    # 重启MySQL服务
    if systemctl is-active --quiet mysql; then
        systemctl restart mysql
    elif systemctl is-active --quiet mysqld; then
        systemctl restart mysqld
    else
        print_warning "无法重启MySQL服务，请手动重启"
    fi
    
    # 获取新版本
    NEW_VERSION=$(mysql -V | awk '{print $3}')
    print_success "MySQL升级完成: $CURRENT_VERSION -> $NEW_VERSION"
    return 0
}

# 修改显示实时数据库连接的函数，使用交互方式输入密码
show_active_connections() {
    print_info "显示实时数据库连接..."
    
    if ! command -v mysql >/dev/null 2>&1; then
        print_error "数据库未安装或不在PATH中"
        return 1
    fi
    
    echo ""
    echo "==================================================="
    echo "  当前活跃的数据库连接:"
    echo "---------------------------------------------------"
    
    print_info "请输入数据库root密码:"
    mysql -u root -p -e "
    SELECT 
        id, 
        user, 
        host, 
        db, 
        command, 
        time, 
        state, 
        info 
    FROM information_schema.processlist 
    ORDER BY time DESC;" || {
        print_error "无法获取数据库连接信息"
        return 1
    }
    
    echo "==================================================="
    echo ""
    
    # 显示连接统计
    echo "连接统计:"
    print_info "请输入数据库root密码:"
    mysql -u root -p -e "
    SELECT 
        user, 
        count(*) as connections, 
        GROUP_CONCAT(DISTINCT host) as hosts
    FROM information_schema.processlist 
    GROUP BY user;" || {
        print_error "无法获取连接统计信息"
    }
    
    return 0
}

# 修改查看数据库错误日志的函数，使用交互方式输入密码
show_error_log() {
    print_info "查看数据库错误日志..."
    
    # 查找错误日志位置
    local ERROR_LOG=""
    
    print_info "请输入数据库root密码以查询错误日志位置:"
    if systemctl is-active --quiet mysql; then
        # MySQL服务
        ERROR_LOG=$(mysql -u root -p -e "SHOW VARIABLES LIKE 'log_error';" | grep log_error | awk '{print $2}')
    elif systemctl is-active --quiet mysqld; then
        # mysqld服务
        ERROR_LOG=$(mysql -u root -p -e "SHOW VARIABLES LIKE 'log_error';" | grep log_error | awk '{print $2}')
    elif systemctl is-active --quiet mariadb; then
        # MariaDB服务
        ERROR_LOG=$(mysql -u root -p -e "SHOW VARIABLES LIKE 'log_error';" | grep log_error | awk '{print $2}')
    fi
    
    if [ -z "$ERROR_LOG" ]; then
        # 尝试常见的错误日志位置
        for log_path in "/var/log/mysql/error.log" "/var/log/mysqld.log" "/var/log/mariadb/mariadb.log"; do
            if [ -f "$log_path" ]; then
                ERROR_LOG="$log_path"
                break
            fi
        done
    fi
    
    if [ -z "$ERROR_LOG" ] || [ ! -f "$ERROR_LOG" ]; then
        print_error "找不到数据库错误日志文件"
        return 1
    fi
    
    print_info "错误日志位置: $ERROR_LOG"
    echo ""
    echo "==================================================="
    echo "  最近的错误日志 (最后50行):"
    echo "---------------------------------------------------"
    tail -n 50 "$ERROR_LOG"
    echo "==================================================="
    
    return 0
}

# 修改监控数据库性能的函数，使用交互方式输入密码
monitor_database_performance() {
    print_info "监控数据库性能..."
    
    if ! command -v mysql >/dev/null 2>&1; then
        print_error "数据库未安装或不在PATH中"
        return 1
    fi
    
    echo ""
    echo "==================================================="
    echo "  数据库性能状态:"
    echo "---------------------------------------------------"
    
    # 显示全局状态变量
    echo "● 连接统计:"
    print_info "请输入数据库root密码:"
    mysql -u root -p -e "
    SHOW GLOBAL STATUS LIKE 'Connections';
    SHOW GLOBAL STATUS LIKE 'Threads_connected';
    SHOW GLOBAL STATUS LIKE 'Threads_running';
    SHOW GLOBAL STATUS LIKE 'Aborted_connects';
    SHOW GLOBAL STATUS LIKE 'Max_used_connections';" || {
        print_error "无法获取连接统计"
    }
    
    echo ""
    echo "● 查询统计:"
    print_info "请输入数据库root密码:"
    mysql -u root -p -e "
    SHOW GLOBAL STATUS LIKE 'Questions';
    SHOW GLOBAL STATUS LIKE 'Queries';
    SHOW GLOBAL STATUS LIKE 'Slow_queries';
    SHOW GLOBAL STATUS LIKE 'Com_select';
    SHOW GLOBAL STATUS LIKE 'Com_insert';
    SHOW GLOBAL STATUS LIKE 'Com_update';
    SHOW GLOBAL STATUS LIKE 'Com_delete';" || {
        print_error "无法获取查询统计"
    }
    
    echo ""
    echo "● 缓存统计:"
    print_info "请输入数据库root密码:"
    mysql -u root -p -e "
    SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read_requests';
    SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';
    SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages_total';
    SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages_free';" || {
        print_error "无法获取缓存统计"
    }
    
    echo ""
    echo "● 表锁统计:"
    print_info "请输入数据库root密码:"
    mysql -u root -p -e "
    SHOW GLOBAL STATUS LIKE 'Table_locks_immediate';
    SHOW GLOBAL STATUS LIKE 'Table_locks_waited';" || {
        print_error "无法获取表锁统计"
    }
    
    echo "==================================================="
    
    return 0
}

# 检查并更新脚本
check_for_updates() {
    print_info "检查脚本更新..."
    
    # 确保 curl 已安装
    if ! command -v curl &> /dev/null; then
        print_info "安装 curl..."
        if command -v apt &> /dev/null; then
            apt update && apt install -y curl
        elif command -v dnf &> /dev/null; then
            dnf install -y curl
        elif command -v yum &> /dev/null; then
            yum install -y curl
        else
            print_error "无法安装 curl，跳过更新检查"
            return 1
        fi
    fi
    
    # 获取脚本路径
    SCRIPT_PATH=$(readlink -f "$0")
    
    # 从当前运行的脚本文件中读取实际版本号
    CURRENT_VERSION=$(grep -m 1 "SCRIPT_VERSION=" "$SCRIPT_PATH" | cut -d'"' -f2)
    
    # 如果无法从文件中读取版本号，则使用变量中的版本号作为后备
    if [ -z "$CURRENT_VERSION" ]; then
        CURRENT_VERSION="$SCRIPT_VERSION"
        print_warning "无法从脚本文件读取版本号，使用内存中的版本号: $CURRENT_VERSION"
    fi
    
    # 从 GitHub 获取最新版本
    print_info "从 GitHub 获取最新版本..."
    
    # 尝试从 GitHub 获取最新版本
    LATEST_VERSION=$(curl -s "https://raw.githubusercontent.com/$GITHUB_REPO/main/deploymysql.sh" | grep -m 1 "SCRIPT_VERSION=" | cut -d'"' -f2)
    
    if [ -z "$LATEST_VERSION" ]; then
        print_warning "无法获取最新版本信息，跳过更新"
        return 1
    fi
    
    print_info "当前版本: $CURRENT_VERSION"
    print_info "最新版本: $LATEST_VERSION"
    
    # 比较版本
    if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
        print_info "发现新版本，准备更新..."
        
        # 备份当前脚本
        cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak"
        print_info "已备份当前脚本到 ${SCRIPT_PATH}.bak"
        
        # 下载最新版本
        if curl -s "https://raw.githubusercontent.com/$GITHUB_REPO/main/deploymysql.sh" -o "$SCRIPT_PATH"; then
            print_success "脚本已更新到版本 $LATEST_VERSION"
            print_info "请重新运行脚本以应用更新"
            chmod +x "$SCRIPT_PATH"
            exit 0
        else
            print_error "更新失败，恢复备份..."
            mv "${SCRIPT_PATH}.bak" "$SCRIPT_PATH"
            return 1
        fi
    else
        print_success "脚本已是最新版本"
        return 0
    fi
}

# 手动更新脚本
update_script() {
    print_info "手动更新脚本..."
    
    # 确认更新
    echo ""
    echo "此操作将更新脚本到最新版本。"
    echo "请输入 'YES' 确认更新:"
    read confirm
    
    if [ "$confirm" != "YES" ]; then
        print_info "更新已取消"
        return 0
    fi
    
    check_for_updates
}

# 修改显示菜单，添加卸载选项
show_menu() {
    clear
    echo "=================================================="
    echo "  MySQL/MariaDB 部署与管理工具 v${SCRIPT_VERSION}"
    echo "=================================================="
    echo "  1. 安装 MySQL/MariaDB"
    echo "  2. 配置数据库安全设置"
    echo "  3. 创建项目数据库和用户"
    echo "  4. 配置远程访问"
    echo "  5. 导入初始数据"
    echo "  6. 显示连接信息"
    echo "  7. 检查数据库状态"
    echo "  8. 更新部署脚本"
    echo "  9. 卸载数据库"
    echo "  0. 退出"
    echo "=================================================="
    echo ""
    echo -n "请选择操作 [0-9]: "
}

# 修改主函数，添加卸载选项
main() {
    check_root
    detect_distro
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                print_info "开始数据库安装..."
                
                # 根据发行版安装MySQL或MariaDB
                if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
                    install_mysql_debian
                elif [[ "$ID" == "rocky" ]] && [[ "$MAJOR_VER" -ge 9 ]]; then
                    # 对于Rocky Linux 9，直接安装MariaDB
                    install_rocky9_mariadb
                elif [[ "$ID" == "centos" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "rocky" ]] || [[ "$ID" == "almalinux" ]]; then
                    install_mysql_rhel
                else
                    install_mysql_other
                fi
                
                # 配置数据库
                secure_mysql
                setup_database
                configure_remote_access
                import_initial_data
                show_connection_info
                
                print_success "数据库部署完成!"
                read -p "按Enter键继续..."
                ;;
            2)
                secure_mysql
                read -p "按Enter键继续..."
                ;;
            3)
                setup_database
                read -p "按Enter键继续..."
                ;;
            4)
                configure_remote_access
                read -p "按Enter键继续..."
                ;;
            5)
                import_initial_data
                read -p "按Enter键继续..."
                ;;
            6)
                show_connection_info
                read -p "按Enter键继续..."
                ;;
            7)
                check_mysql_status
                read -p "按Enter键继续..."
                ;;
            8)
                update_script
                read -p "按Enter键继续..."
                ;;
            9)
                uninstall_database
                read -p "按Enter键继续..."
                ;;
            0)
                print_info "感谢使用，再见!"
                exit 0
                ;;
            *)
                print_error "无效选择，请重新输入"
                read -p "按Enter键继续..."
                ;;
        esac
    done
}

# 执行主函数
main 