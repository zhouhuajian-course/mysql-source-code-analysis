# MySQL 8.x 源码分析

https://www.mysql.com/  

https://dev.mysql.com/downloads/mysql/  
https://github.com/mysql/mysql-server  

https://dev.mysql.com/doc/refman/8.0/en/  
https://dev.mysql.com/doc/dev/mysql-server/latest/  
(Related Documentation -> MySQL 8.0 Source Code Documentation)  

## 聚集索引/辅助索引

```
2.1、Clustered Indexes（聚簇索引/聚集索引）
聚簇索引的特点：

每个InnoDB表都有一个称为聚集索引的特殊索引，用于存储行数据。
当表上存在PRIMARY KEY时，InnoDB将其用作聚集索引。
当表上不存在PRIMARY KEY时，InnoDB将使用第一个NOT NULL的列的UNIQUE索引，作为聚集索引。
如果表没有PRIMARY KEY和合适的UNIQUE索引，InnoDB会自动生成一个名为GEN_CLUST_index的隐藏聚集索引（ROW_ID），6bit，自动增长。
聚簇索引的功能：

IOT，索引组织表。
针对ID（PK）的查询快速找到记录（有序）。
通过聚集索引访问行很快，因为索引搜索直接指向包含行数据的页面。

2.2、Secondary Indexes（辅助索引）

聚集索引以外的索引称为辅助索引。

辅助索引中的每个记录都包含行的主键列，以及为辅助索引指定的列，使用这个主键值来搜索聚集索引中的行。

如果主键过长，则辅助索引使用更多的空间，因此使用短主键是有利的。
索引都是有序的。
索引覆盖和回表查询：

索引覆盖(use index)：查询过程中，直接从索引中查询出了所需要的值。
回表查询(use where)：查询过程中，不能直接从索引中取到所需要的值，需要回覆盖索引再取值。
```

## MySQL 版本直接从 5.7 跳到 8.0

MySQL 从 5.7 直接升级到 8.0 是因为 MySQL 开发团队在 5.7 版本后引入了许多重要的功能和改进，这些功能包括了更好的性能、安全性和可伸缩性，例如支持窗口函数、支持更高效的索引算法、更好的数据加密和更高级的查询优化等。这些改进和功能的引入使得 MySQL 8.0 与 5.7 相比更加先进和稳定。

此外，MySQL 开发团队在过去的版本中已经表明他们计划在未来的版本中跳过 5.8 和 5.9，直接将版本号更新到 8.0，这也是 MySQL 8.0 直接从 5.7 升级而来的原因之一。这种版本号跳跃的做法不是 MySQL 开发团队所独有的，其他软件也曾经出现过类似的情况。这种做法的好处是可以向用户传递一个更强的信息，表明新版本的变化和功能非常重要和突出，需要用户尽快升级。

因此，MySQL 8.0 直接从 5.7 升级而来是一个正常的版本跳跃，是为了更好地满足用户需求，提供更先进的功能和更好的性能。

----------------------

MySQL从5.7直接升级到8.0是因为在这两个版本之间有较大的技术差距和功能改进，MySQL 8.0引入了许多新功能和重要的性能改进，包括更好的安全性、更高的性能、更好的可扩展性、JSON支持等。而且，MySQL 8.0还引入了更严格的数据类型检查和其他一些重要的改进和变化，这使得从以前的版本升级可能会更加困难和复杂。因此，直接从5.7升级到8.0也有利于推广和使用最新的数据库技术。

_From Internet_

## 名人名言

1. MySQL 采用单进程多线程架构 （ps -ef | grep mysql | grep -v grep）
2. InnoDB 数据即索引，索引即数据

## MySQL 安装目录

bin/               mysql 客户端和实用程序目录
sbin/              mysqld 服务器程序目录
share/man/         Unix 帮助手册目录
include/mysql/     头文件目录
lib/mysql/         库文件目录
share/mysql/       各种字符集、语言相关的错误提示目录

## MySQL 数据目录

一个库一个目录 例如 school 

  表结构、表数据、表索引

  MySQL8.0 以后没有 表结构 表名.frm，元数据都在系统表。 系统表空间 ibdata 和 mysql.ibd

  MyISAM 表数据和表索引分开，索引全部都是二级索引 表名.MYD 表名.MDI   例如 student.MYD student.MDI 
  InnoDB 表数据和表索引放一起，数据即索引，索引即数据 表名.ibd        例如 student.ibd

表结构存放在 ibdata1, ibdata2, ...

https://dev.mysql.com/doc/refman/8.0/en/glossary.html#glos_ibdata_file

```
ibdata file

  A set of files with names such as ibdata1, ibdata2, and so on, that make up the InnoDB system tablespace. For information about the structures and data that reside in the system tablespace ibdata files, see Section 15.6.3.1, “The System Tablespace”. (系统 表空间)

  Growth of the ibdata files is influenced by the innodb_autoextend_increment configuration option.

  See Also change buffer, data dictionary, doublewrite buffer, file-per-table, .ibd file, innodb_file_per_table, system tablespace, undo log.
```

```
1、默认情况下ibdata存放InnoDB表（InnoDB数据字典）元数据、undo logs、the change buffer, and the doublewrite buffer
2、如果innodb_file_per_table=off，则ibdata也存放InnoDB表的实际数据，也就是InnoDB表建立后，不会再有单独的tablename.ibd文件
3、虽然InnoDB表元数据通过information_schema.tables来读取，但是实际上information_schema是一个虚拟数据库，并不物理存在，这些数据真正存放的地方就是ibdata
备注：元数据(meta data)--"data about data" 关于数据的数据，一般是结构化数据（如存储在数据库里的数据，规定了字段的长度、类型等）
```

_From Internet_

## SELECT COUNT(*) FROM `table` 源码分析

断点位置 

storage\innobase\row\row0mysql.cc row_mysql_parallel_select_count_star

执行SQL 

SELECT COUNT(*) FROM student;

调用栈

```c++
// 并行 select count *
row_mysql_parallel_select_count_star(trx_t * trx, std::vector<dict_index_t*, std::allocator<dict_index_t*> > & indexes, size_t n_threads, ulint * n_rows) (storage\innobase\row\row0mysql.cc:4360)
// 为 mysql 扫描索引
row_scan_index_for_mysql(row_prebuilt_t * prebuilt, dict_index_t * index, size_t max_threads, bool check_keys, ulint * n_rows) (storage\innobase\row\row0mysql.cc:4588)
ha_innobase::records(ha_innobase * const this, ha_rows * num_rows) (storage\innobase\handler\ha_innodb.cc:16617)
// 从这里开始进入引擎层
handler::ha_records(handler * const this, ha_rows * num_rows) (sql\handler.h:5237)
get_exact_record_count(QEP_TAB * qep_tab, uint table_count, int * error) (sql\iterators\ref_row_iterators.cc:858)
// 使用UnqualifiedCount迭代器
UnqualifiedCountIterator::Read(UnqualifiedCountIterator * const this) (sql\iterators\ref_row_iterators.cc:880)
Query_expression::ExecuteIteratorQuery(Query_expression * const this, THD * thd) (sql\sql_union.cc:1770)
Query_expression::execute(Query_expression * const this, THD * thd) (sql\sql_union.cc:1823)
Sql_cmd_dml::execute_inner(Sql_cmd_dml * const this, THD * thd) (sql\sql_select.cc:799)
Sql_cmd_dml::execute(Sql_cmd_dml * const this, THD * thd) (sql\sql_select.cc:578)
mysql_execute_command(THD * thd, bool first_level) (sql\sql_parse.cc:4714)
dispatch_sql_command(THD * thd, Parser_state * parser_state) (sql\sql_parse.cc:5363)
dispatch_command(THD * thd, const COM_DATA * com_data, enum_server_command command) (sql\sql_parse.cc:2050)
do_command(THD * thd) (sql\sql_parse.cc:1439)
handle_connection(void * arg) (sql\conn_handler\connection_handler_per_thread.cc:302)
pfs_spawn_thread(void * arg) (storage\perfschema\pfs.cc:3042)
libpthread.so.0!start_thread (Unknown Source:0)
libc.so.6!clone (Unknown Source:0)
```

```c++
继续往后走，可以调试出

n_rows
  0x7fffac6f5ec8
    *n_rows: 6

student表的总数为 6
```

性能

COUNT(*) = COUNT(1) > COUNT(`主键`) > COUNT(`某非主键字段`)

COUNT(*) COUNT(1)    不需要具体取值，效率最高
COUNT(`主键`)        不需要具体取值，默认认为主键里面的值不为NULL，但会有一些额外过程
COUNT(`某非主键字段`) 需要判断 值是否为 NULL，不为NULL才加+，所以需要具体取值，性能最低

InnoDB引擎 默认4个线程 并行 统计 有参数可调

## SELECT UNIX_TIMESTAMP(); 源码分析

函数源码表

```c++
item_create.cc

static const std::pair<const char *, Create_func *> func_array[] = {
    {"ABS", SQL_FN(Item_func_abs, 1)},
    // ...
    {"MD5", SQL_FN(Item_func_md5, 1)},
    // ...
    {"PI", SQL_FN(Item_func_pi, 0)},
    {"POW", SQL_FN(Item_func_pow, 2)},
    {"POWER", SQL_FN(Item_func_pow, 2)},
    {"PS_CURRENT_THREAD_ID", SQL_FN(Item_func_pfs_current_thread_id, 0)},
    {"PS_THREAD_ID", SQL_FN(Item_func_pfs_thread_id, 1)},
    {"QUOTE", SQL_FN(Item_func_quote, 1)},
    {"RADIANS", SQL_FN(Item_func_radians, 1)},
    {"RAND", SQL_FN_V(Item_func_rand, 0, 1)},
    {"RANDOM_BYTES", SQL_FN(Item_func_random_bytes, 1)},
    {"REGEXP_INSTR", SQL_FN_V_LIST(Item_func_regexp_instr, 2, 6)},
    {"REGEXP_LIKE", SQL_FN_V_LIST(Item_func_regexp_like, 2, 3)},
    {"REGEXP_REPLACE", SQL_FN_V_LIST(Item_func_regexp_replace, 3, 6)},
    {"REGEXP_SUBSTR", SQL_FN_V_LIST(Item_func_regexp_substr, 2, 5)},
    {"RELEASE_ALL_LOCKS", SQL_FN(Item_func_release_all_locks, 0)},
    {"RELEASE_LOCK", SQL_FN(Item_func_release_lock, 1)},
    {"REVERSE", SQL_FN(Item_func_reverse, 1)},
    {"ROLES_GRAPHML", SQL_FN(Item_func_roles_graphml, 0)},
    {"ROUND", SQL_FACTORY(Round_instantiator)},
    {"RPAD", SQL_FN(Item_func_rpad, 3)},
    {"RTRIM", SQL_FN(Item_func_rtrim, 1)},
    {"SEC_TO_TIME", SQL_FN(Item_func_sec_to_time, 1)},
    {"SHA", SQL_FN(Item_func_sha, 1)},
    {"SHA1", SQL_FN(Item_func_sha, 1)},
    {"SHA2", SQL_FN(Item_func_sha2, 2)},
    {"SIGN", SQL_FN(Item_func_sign, 1)},
    {"SIN", SQL_FN(Item_func_sin, 1)},
    {"SLEEP", SQL_FN(Item_func_sleep, 1)},
    {"SOUNDEX", SQL_FN(Item_func_soundex, 1)},
    {"SOURCE_POS_WAIT", SQL_FN_V(Item_source_pos_wait, 2, 4)},
    {"SPACE", SQL_FN(Item_func_space, 1)},
    // ...
    {"SQRT", SQL_FN(Item_func_sqrt, 1)},
    {"STRCMP", SQL_FN(Item_func_strcmp, 2)},
    {"STR_TO_DATE", SQL_FN(Item_func_str_to_date, 2)},
    // ...
    {"TIMEDIFF", SQL_FN(Item_func_timediff, 2)},
    {"TIME_FORMAT", SQL_FACTORY(Time_format_instantiator)},
    {"TIME_TO_SEC", SQL_FN(Item_func_time_to_sec, 1)},
    {"TO_BASE64", SQL_FN(Item_func_to_base64, 1)},
    {"TO_DAYS", SQL_FN(Item_func_to_days, 1)},
    {"TO_SECONDS", SQL_FN(Item_func_to_seconds, 1)},
    {"UCASE", SQL_FN(Item_func_upper, 1)},
    {"UNCOMPRESS", SQL_FN(Item_func_uncompress, 1)},
    {"UNCOMPRESSED_LENGTH", SQL_FN(Item_func_uncompressed_length, 1)},
    {"UNHEX", SQL_FN(Item_func_unhex, 1)},
    {"UNIX_TIMESTAMP", SQL_FN_V(Item_func_unix_timestamp, 0, 1)},
    {"UPDATEXML", SQL_FN(Item_func_xml_update, 3)},
    {"UPPER", SQL_FN(Item_func_upper, 1)},
    {"UUID", SQL_FN(Item_func_uuid, 0)},
    {"UUID_SHORT", SQL_FN(Item_func_uuid_short, 0)},
    {"UUID_TO_BIN", SQL_FN_V(Item_func_uuid_to_bin, 1, 2)},
    {"VALIDATE_PASSWORD_STRENGTH",
     SQL_FN(Item_func_validate_password_strength, 1)},
    {"VERSION", SQL_FN(Item_func_version, 0)},
    {"WEEKDAY", SQL_FACTORY(Weekday_instantiator)},
    {"WEEKOFYEAR", SQL_FACTORY(Weekofyear_instantiator)},
    {"YEARWEEK", SQL_FACTORY(Yearweek_instantiator)},
    // ...
```

调用栈 CALL STACK

```c++
// 再回到 val_int，最后取的是 tm.m_tv_sec

// Item_函数_unix_时间戳::值_时间值
Item_func_unix_timestamp::val_timeval(Item_func_unix_timestamp * const this, my_timeval * tm) (sql\item_timefunc.cc:1670)
// Item_时间值_函数::值_整数
Item_timeval_func::val_int(Item_timeval_func * const this) (sql\item_timefunc.cc:1630)
// Item::发送
Item::send(Item * const this, Protocol * protocol, String * buffer) (sql\item.cc:7318)
// THD::发送_结果_设置_行
THD::send_result_set_row(THD * const this, const mem_root_deque<Item*> & row_items) (sql\sql_class.cc:2866)
// 查询结果发送::发送数据
Query_result_send::send_data(Query_result_send * const this, THD * thd, const mem_root_deque<Item*> & items) (sql\query_result.cc:100)
// Query 表达式::执行迭代器查询
Query_expression::ExecuteIteratorQuery(Query_expression * const this, THD * thd) (sql\sql_union.cc:1785)
// Query 表达式::执行
Query_expression::execute(Query_expression * const this, THD * thd) (sql\sql_union.cc:1823)
// Sql_命令_dml::执行 内部
Sql_cmd_dml::execute_inner(Sql_cmd_dml * const this, THD * thd) (sql\sql_select.cc:799)
Sql_cmd_dml::execute(Sql_cmd_dml * const this, THD * thd) (sql\sql_select.cc:578)
// mysql 执行命令
mysql_execute_command(THD * thd, bool first_level) (sql\sql_parse.cc:4714)
dispatch_sql_command(THD * thd, Parser_state * parser_state) (sql\sql_parse.cc:5363)
dispatch_command(THD * thd, const COM_DATA * com_data, enum_server_command command) (sql\sql_parse.cc:2050)
do_command(THD * thd) (sql\sql_parse.cc:1439)
handle_connection(void * arg) (sql\conn_handler\connection_handler_per_thread.cc:302)
pfs_spawn_thread(void * arg) (storage\perfschema\pfs.cc:3042)
libpthread.so.0!start_thread (Unknown Source:0)
libc.so.6!clone (Unknown Source:0)
```

调试过程

```c++
mysql -h 127.0.0.1 -e "SELECT UNIX_TIMESTAMP();"

断点打在 bool Item_func_unix_timestamp::val_timeval(my_timeval *tm)

bool Item_func_unix_timestamp::val_timeval(my_timeval *tm) {
  assert(fixed == 1);
  // 如果参数数量为0 没有参数 SELECT UNIT_TIMESTAMP();
  if (arg_count == 0) {
    // tm->m_tv_sec 设置为 当前线程 查询 开始时间 最后取的是这个值
    tm->m_tv_sec = current_thd->query_start_in_secs();
    // tm->m_tv_usec 设置为 0
    tm->m_tv_usec = 0;
    return false;  // no args: null_value is set in constructor and is always 0.
  }
  int warnings = 0;
  return (null_value = args[0]->get_timeval(tm, &warnings));
}

回到 longlong Item_timeval_func::val_int()

longlong Item_timeval_func::val_int() {
  my_timeval tm;
  return val_timeval(&tm) ? 0 : tm.m_tv_sec;
}

tm
  m_tv_sec: 1682503475
  m_tv_usec: 0

取 tm 的 m_tv_sec

$ mysql -h 127.0.0.1 -e "SELECT UNIX_TIMESTAMP();"
+------------------+
| UNIX_TIMESTAMP() |
+------------------+
|       1682503475 |
+------------------+

其他信息

// 时间值结构体
struct my_timeval {
  // 8字节整数
  int64_t m_tv_sec;
  int64_t m_tv_usec;
};
```

## 相关术语

聚簇索引 clustered index 

二级索引 secondary index

Server 层、存储层

MVCC

## SQL 执行三个阶段

准备阶段 prepare 优化阶段 optimize 执行阶段 execute

## MySQL 命令执行调试断点

sql_parse.cc 中的 mysql_execute_command 函数加上断点，大部分SQL查询都会经过这个函数

调用栈 call stack 使用 

```c++
// mysql 执行命令
mysql_execute_command(THD * thd, bool first_level) (sql\sql_parse.cc:2953)
// 分发 sql 命令
dispatch_sql_command(THD * thd, Parser_state * parser_state) (sql\sql_parse.cc:5363)
// 分发命令
dispatch_command(THD * thd, const COM_DATA * com_data, enum_server_command command) (sql\sql_parse.cc:2050)
// 做命令
do_command(THD * thd) (sql\sql_parse.cc:1439)
// 处理连接
handle_connection(void * arg) (sql\conn_handler\connection_handler_per_thread.cc:302)
// pfs_spawn_thread
pfs_spawn_thread(void * arg) (storage\perfschema\pfs.cc:3042)
// 启动线程
libpthread.so.0!start_thread (Unknown Source:0)
// 克隆
libc.so.6!clone (Unknown Source:0)
```

```c++
// 第一个参数 thd 是当前线程对象

// thd->query() 可以看到当前正在处理的 SQL
thd->query()
{...}
str: 0x7fff641806e0 "SELECT VERSION()"
length: 16

// thd->variables 可以看到相关变量
thd->variables
// ...
net_read_timeout: 30
net_retry_count: 10
net_wait_timeout: 28800
net_write_timeout: 60
// ...
```

## 入口函数

sql/main.cc:main

## 源码修改 MySQL 版本

```text
修改 MYSQL_VERSION

MYSQL_VERSION_PATCH=123456  （原来是 33）

cmake/mysql_version.cmake 使用一个宏定义MYSQL_GET_CONFIG_VALUE解析MySQL_VERSION文件里面的键值对
```

```shell
$ ./run.sh
$ cd build
$ ./bin/mysql --version
./bin/mysql  Ver 8.0.123456 for Linux on x86_64 (Source distribution)
$ ./bin/mysql -h 127.0.0.1 -e "SELECT version();"
+------------------+
| version()        |
+------------------+
| 8.0.123456-debug |
+------------------+
```

## 源码调试环境搭建

1. 源码安装

机器配置 CentOS 7 4G 40G (硬盘不能20G，编译一半会空间不足。)

`mkdir /mysql-source-code-analysis && cd /mysql-source-code-analysis`

```
1. rz mysql-boost-8.0.33.tar.gz
2. tar -zxvf mysql-boost-8.0.33.tar.gz
3. 安装 cmake 3.7.1+，确保cmake gcc gcc-c++ 版本，卸载或备份原来的 gcc gcc-c++ 相关命令
4. 运行 build.sh，第一次编译时，建议一个一个地运行 build.sh 里面的命令
根据报错提示 安装对应依赖 并在需要时，修改环境变量PATH (/etc/profile)
yum install devtoolset-11-gcc devtoolset-11-gcc-c++ devtoolset-11-binutils   (留意/opt/rh/devtoolset-11)
yum install openssl openssl-devel  
yum install ncurses-devel  
5. 参考 build.sh 做后续初始化操作
6. ./bin/mysqld --defaults-file=./test/etc/my.cnf --initialize-insecure
2023-04-25T03:38:57.422401Z 0 [System] [MY-013169] [Server] /mysql-source-code-analysis/build/runtime_output_directory/mysqld (mysqld 8.0.33-debug) initializing of server in progress as process 71824
2023-04-25T03:38:57.431721Z 1 [System] [MY-013576] [InnoDB] InnoDB initialization has started.
2023-04-25T03:38:58.054746Z 1 [System] [MY-013577] [InnoDB] InnoDB initialization has ended.
2023-04-25T03:39:02.870266Z 6 [Warning] [MY-010453] [Server] root@localhost is created with an empty password ! Please consider switching off the --initialize-insecure option.
7. ll test/data/
8. 使用 VSCODE 启动 mysqld
```

二. 使用 VSCODE 启动 mysqld，并调试 mysqld

Windows

```
1. 扩展 安装 
   Remote - SSH
   C/C++ (可以不需要 CMake、CMake Tools，在机器上直接 cmake，也可以配置在VSCODE使用cmake)
2. Remote - SSH 打开 /etc/mysql-source-code/analysis 目录
3. Create .vscode/launch.json
4. Run -> Debug
```

## 文件后缀

C语言 头文件 .h 源文件 .c

C++语言 

头文件最开始使用 .h .c 但和C语言无法区分，于是使用.H .C .h++ .c++进行区分，  
但个别系统文件名不区分大小写，个别系统则文件不能出现+， 
于是大家开发C++程序普通使用以下文件后缀

头文件 .h  .hpp .hxx (.h 仍然被普遍使用在c++ 可能是解析原理一样 都是简单地引入和替换)  
源文件 .cc .cpp .cxx 

## 编译报错解决

1. collect2: fatal error: ld terminated with signal 9 [Killed]
   内存增大到4GB
2. /opt/rh/devtoolset-11/root/usr/bin/ld: final link failed: No space left on device
   删掉不需要的大文件或增大磁盘容量到40GB

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
$ yum install devtoolset-11 -y
$ vim /etc/profile
export PATH=$PATH:/opt/cmake-3.26.3-linux-x86_64/bin:/opt/rh/devtoolset-11/root/bin
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