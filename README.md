# MySQL/MariaDB 部署脚本

这是一个用于自动化部署和管理 MySQL/MariaDB 数据库的 Bash 脚本，专为咨询规划项目管理系统设计。

## 功能特点

- **多平台支持**：自动检测并适配 Debian/Ubuntu、RHEL/CentOS、Rocky Linux 等多种 Linux 发行版
- **智能安装**：根据系统环境选择最佳的安装方式，支持 MySQL 和 MariaDB
- **安全配置**：自动执行安全最佳实践，包括删除匿名用户、禁用远程 root 访问等
- **远程访问**：配置数据库允许远程连接，便于分布式应用架构
- **交互式管理**：提供友好的菜单界面，轻松管理数据库

## 主要功能

1. **安装数据库**：自动安装 MySQL 或 MariaDB
2. **升级数据库**：升级现有数据库到最新版本
3. **显示连接信息**：查看数据库连接详情
4. **检查数据库状态**：验证数据库运行状态
5. **监控数据库连接**：显示实时数据库连接
6. **查看错误日志**：访问数据库错误日志
7. **监控性能**：查看数据库性能指标
8. **卸载数据库**：完全移除数据库服务

## 使用方法

1. 下载脚本：
   ```bash
   git clone https://github.com/tinyvane/deploymysql.git
   cd deploymysql
   ```

2. 赋予执行权限：
   ```bash
   chmod +x deploymysql.sh
   ```

3. 以 root 权限运行：
   ```bash
   sudo ./deploymysql.sh
   ```

4. 按照交互式菜单提示操作

## 系统要求

- 支持的操作系统：Debian、Ubuntu、CentOS、RHEL、Rocky Linux、AlmaLinux
- 需要 root 或 sudo 权限
- 基本的网络连接以下载软件包

## 安全说明

- 脚本使用交互式方式获取数据库密码，不会在代码中硬编码敏感信息
- 建议在生产环境使用前，先在测试环境验证脚本功能
- 使用卸载功能时请谨慎，该操作将删除所有数据库数据

## 贡献

欢迎提交 Issues 和 Pull Requests 来改进此脚本。

## 许可

[MIT License](LICENSE) 