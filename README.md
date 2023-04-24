# MySQL 8.x 源码分析

https://www.mysql.com/  

https://dev.mysql.com/downloads/mysql/  
https://github.com/mysql/mysql-server  

https://dev.mysql.com/doc/refman/8.0/en/  
https://dev.mysql.com/doc/dev/mysql-server/latest/  
(Related Documentation -> MySQL 8.0 Source Code Documentation)  

## CMake 命令

```text
$ cmake --help
Usage                                                     用法
  cmake [options] <path-to-source>                        [选项] 源码路径
  cmake [options] <path-to-existing-build>                [选项] 已存在构建目录路径
  cmake [options] -S <path-to-source> -B <path-to-build>  [选项] -S 源码路径 -B 构建路径
                                                            
Specify a source directory to (re-)generate a build system for it in the
current working directory.  Specify an existing build directory to
re-generate its build system.                             默认当前工作目录是构建目录

Options
  ...
  -D <var>[:<type>]=<value>    = Create or update a cmake cache entry.   缓存实体 键值对
  ...
```

## MySQL 8.0.33 源码目录

```
mysql-8.0.33

  boost                  boost C++库
  client                 客户端 mysql mysqladmin mysqldump ...
  cmake                  CMake
  CMakeLists.txt         CMakeLists
  components             组件
  config.h.cmake
  configure.cmake
  Docs                   文档
  Doxyfile-ignored
  Doxyfile.in
  doxygen_resources      Doxygen 文档生成工具 资源
  extra                  额外
  include                包含 头部文件
  INSTALL                安装
  libbinlogevents        binlog事件库
  libbinlogstandalone    binlog standalone 库
  libchangestreams       changestreams 库
  libmysql               mysql 库
  libservices            services 库
  LICENSE                许可证
  man                    手册
  mysql-test             mysql 测试
  MYSQL_VERSION          MYSQL 版本
  mysys                  mysql 系统
  packaging              打包
  plugin                 插件
  README                 README
  router                 路由器
  run_doxygen.cmake
  scripts                脚本
  share                  share
  sql                    sql
  sql-common
  storage                存储引擎 InnoDB MyISAM ...
  strings                字符串
  support-files          支持文件
  testclients            测试客户端
  unittest               单元测试
  utilities              工具
  vio                    虚拟I/O Virtual I/O
```

## MySQL 8.0 官网文档

```
Documentation Home                       文档主页
      
MySQL 8.0 Reference Manual               MySQL 8.0 参考手册
      
  Preface and Legal Notices              前言 和 法律上的注意点
  General Information                    通用信息
  Installing and Upgrading MySQL         安装和更新 MySQL
  Tutorial                               教程
  MySQL Programs                         MySQL 程序
  MySQL Server Administration            MySQL 服务器管理
  Security                               安全
  Backup and Recovery                    备份和恢复
  Optimization                           优化
  Language Structure                     语言结构
  Character Sets, Collations, Unicode    字符集 Collations Unicode
  Data Types                             数据类型     
  Functions and Operators                函数 和 操作符
  SQL Statements                         SQL 语句
  MySQL Data Dictionary                  MySQL 数据 字典
  The InnoDB Storage Engine              InnoDB 存储引擎
  Alternative Storage Engines            可替换的存储引擎
  Replication                            副本
  Group Replication                      Group 副本
  MySQL Shell                            MySQL Shell
  Using MySQL as a Document Store        使用 MySQL 作为一个文档存储
  InnoDB Cluster                         InnoDB Cluster
  InnoDB ReplicaSet                      InnoDB 副本集
  MySQL NDB Cluster 8.0                  MySQL NDB Cluster 8.0
  Partitioning                           分区
  Stored Objects                         存储对象
  INFORMATION_SCHEMA Tables              INFORMATION_SCHEMA 表
  MySQL Performance Schema               MySQL 性能 Schema
  MySQL sys Schema                       MySQL 系统 Schema
  Connectors and APIs                    连接器 和 API
  MySQL Enterprise Edition               MySQL 商业版本
  MySQL Workbench                        MySQL Workbench
  MySQL on the OCI Marketplace           MySQL 在 Oracle 市场
  MySQL 8.0 Frequently Asked Questions   MySQL 8.0 常问问题
  Error Messages and Common Problems     错误消息和常见错误
  Indexes                                索引
  MySQL Glossary                         MySQL 术语表

Related Documentation                    相关文档

  MySQL 8.0 Release Notes                MySQL 8.0 软件发布说明
  MySQL 8.0 Source Code Documentation    MySQL 8.0 源码文档
 
Download this Manual                     下载这个手册

  PDF (US Ltr) - 42.7Mb                
  PDF (A4) - 42.8Mb
  Man Pages (TGZ) - 272.8Kb
  Man Pages (Zip) - 384.2Kb
  Info (Gzip) - 4.2Mb
  Info (Zip) - 4.2Mb

Excerpts from this Manual                来自这个手册的摘录             
```

## MySQL 8.0 源码文档

```
MySQL
  Welcome                      欢迎
  Getting Started              快速开始
  Infrastructure               基础设施 the basic systems and services
  Client/Server Protocol       客户端/服务端协议
  X Protocol                   X 协议
  SQL Query Execution          SQL 查询执行
  Data Storage                 数据存储引擎
  Replication                  副本
  Security                     安全
  Monitoring                   监控
  Extending MySQL              扩展 MySQL
  Available services           可用的服务
  Server tools                 服务器工具
  Client tools                 客户端工具
  Testing Tools                测试工具
  Development Tools            开发工具
  Code paths                   代码路径
  Deprecated List              已废弃列表
  Modules                      模块
  Namespaces                   命名空间
  Classes                      类
  Files                        文件
```

## 源码代码风格

主要使用 Google C++ Style Guide

https://google.github.io/styleguide/cppguide.html

## Doxygen API文档生成工具

Doxygen是API文档生成工具，可以根据代码注释生成文档的工具。支持HTML、CHM、PDF等格式。主要支持C语言、Python语言，其它C语系语言也支持（如C++、Java、C#等）。

## 升级 CMake

```shell
# 删除已安装的cmake
$ yum remove cmake -y && rm -f /usr/bin/cmake
# 或者先下载到 Windows 再上传到 linux
# -c 断续下载
$ wget -c https://github.com/Kitware/CMake/releases/download/v3.26.3/cmake-3.26.3-linux-x86_64.tar.gz
$ tar -zxvf cmake-3.26.3-linux-x86_64.tar.gz
$ vim /etc/profile
export PATH=$PATH:/opt/cmake-3.26.3-linux-x86_64/bin
$ source /etc/profile
$ cmake --version
```

## 升级 GCC

```shell
# devtoolset    对应 gcc       版本
# devtoolset-3  对应 gcc4.x.x  版本
# devtoolset-4  对应 gcc5.x.x  版本
# devtoolset-6  对应 gcc6.x.x  版本
# devtoolset-7  对应 gcc7.x.x  版本
# devtoolset-8  对应 gcc8.x.x  版本
# devtoolset-9  对应 gcc9.x.x  版本
# devtoolset-10 对应 gcc10.x.x 版本
$ yum remove gcc -y
$ yum install centos-release-scl -y
$ yum install devtoolset-10 -y
$ vim /etc/profile
export PATH=$PATH:/opt/cmake-3.26.3-linux-x86_64/bin:/opt/rh/devtoolset-10/root/bin
$ source /etc/profile
```

## 调试方式

1. gdb
2. VSCode + gdb
3. CLion + gdb

## 编译工具

CMake + Make

## Boost

https://www.boost.org/

Boost C++ Libraries

Boost是一个功能强大、构造精巧、跨平台、开源并且完全免费的C++程序库，在1998年由Beman G.Dawes发起倡议并建立。使用了许多现代C++编程技术，内容涵盖字符串处理、正则表达式、容器与数据结构、并发编程、函数式编程、泛型编程、设计模式实现等许多领域，极大地丰富了C++的功能和表现力，能够使C++软件开发更加简洁、优雅、灵活和高效。

Boost库可以与C++标准库完美共同工作，并且为其提供扩展功能。大部分Boost库功能的使用之需要包括相应的头文件即可，少数需要连接库。

## 源码下载

mysql.com -> downloads -> MySQL Community (GPL) Downloads -> MySQL Community Server

Source Code -> All Operating Systems (Generic) (Architecture Independent)

Compressed TAR Archive, Includes Boost Headers	

(使用有 Boost 的源码，可以省去自己下载 Boost。)

Download -> No thanks, just start my download.

mysql-boost-8.0.33.tar.gz