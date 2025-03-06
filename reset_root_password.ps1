# PowerShell脚本用于生成MySQL重置密码指令
# 作者：Claude
# 日期：2024-03-15

Write-Host "MySQL/MariaDB Root密码重置指南" -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# 显示不同的重置方式
Write-Host "`n方法一：使用Windows服务管理器停止MySQL服务" -ForegroundColor Yellow
Write-Host "1. 打开服务管理器 (Win+R 然后输入 services.msc)"
Write-Host "2. 找到MySQL/MariaDB服务并停止它"
Write-Host "3. 打开管理员命令行，切换到MySQL的bin目录"
Write-Host "   (通常在C:\Program Files\MySQL\MySQL Server 8.0\bin)"
Write-Host "4. 执行以下命令启动MySQL在安全模式："
Write-Host "   mysqld --defaults-file=`"C:\ProgramData\MySQL\MySQL Server 8.0\my.ini`" --init-file=C:\mysql-init.txt --console" -ForegroundColor Cyan

# 生成初始化文件
Write-Host "`n首先，创建密码重置文件：" -ForegroundColor Yellow
Write-Host "1. 创建文件 C:\mysql-init.txt 包含以下内容："
Write-Host "ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_new_password';" -ForegroundColor Cyan

Write-Host "`n方法二：使用命令行修改MySQL配置" -ForegroundColor Yellow
Write-Host "1. 停止MySQL服务："
Write-Host "   net stop mysql" -ForegroundColor Cyan
Write-Host "2. 以跳过权限表方式启动MySQL："
Write-Host "   mysqld --skip-grant-tables --skip-networking" -ForegroundColor Cyan
Write-Host "3. 在新的终端窗口连接MySQL："
Write-Host "   mysql -u root" -ForegroundColor Cyan
Write-Host "4. 执行以下命令重置密码："
Write-Host "   FLUSH PRIVILEGES;" -ForegroundColor Cyan
Write-Host "   ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your_new_password';" -ForegroundColor Cyan
Write-Host "   FLUSH PRIVILEGES;" -ForegroundColor Cyan
Write-Host "   EXIT;" -ForegroundColor Cyan
Write-Host "5. 关闭跳过权限表的MySQL进程，然后正常启动MySQL服务："
Write-Host "   net start mysql" -ForegroundColor Cyan

Write-Host "`n验证连接" -ForegroundColor Yellow
Write-Host "重置密码后，验证连接："
Write-Host "mysql -u root -p" -ForegroundColor Cyan
Write-Host "输入您设置的新密码"

Write-Host "`n更新脚本中的密码" -ForegroundColor Yellow
Write-Host "重置密码成功后，更新deploymysql.sh脚本中的密码变量：" 
Write-Host "编辑deploymysql.sh，找到MYSQL_ROOT_PASS变量并更新它"

Write-Host "`n注意：MySQL 8.0默认使用caching_sha2_password认证插件" -ForegroundColor Red
Write-Host "如果使用旧客户端连接，可能需要将root用户认证插件改为mysql_native_password：" 
Write-Host "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your_password';" -ForegroundColor Cyan 