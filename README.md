# MySQL 8.x 源码分析

## SQL语句类型

1. create 创建
2. insert 插入
3. select 选择
4. show 展示
5. flush 冲走
6. explain 解释
7. describe 描述
8. alter 修改
9. update 更新
10. delete 删除
11. grant 授权
12. use 使用
13. load data 加载
14. truncate table 截断
15. 

## binary log 实际调试

binlog_format  ROW  

```
data目录下binlog.index最后的内容是
./binlog.000029
./binlog.000030
./binlog.000031 
启动mysqld，会生成新的binlog文件 binlog.000032
mysql客户端执行创建表的操作
mysql> create table t1 (c1 int, c2 double);
Query OK, 0 rows affected (0.06 sec)

binlog.000032就会记录下这个操作
... ... create table t1 (c1 int, c2 double) 然后确实是二进制内容。
有些人说可以直接看到sql，其实存储的不是二进制，这种说法不对，因为sql的二进制内容，是字符串，刚好能够显示出来，其他很多内容还是乱码不可读的二进制内容。

```

binlog_format  STATEMENT 测试  

```
启动参数增加 --binlog-format=STATEMENT

mysql> create table t2 (c1 int, c2 double);
Query OK, 0 rows affected (0.05 sec)

cat binlog.00033 内容类似，其他内容大部分都是不可读的二进制内容
... ... create table t2 (c1 int, c2 double)
```

## the binary log 二进制日志

1. 记录修改数据的语句，也用来主从复制
2. 二进制日志会被flushed，当大小达到 max_binlog_size 默认1G
3. 二进制日志包含事件"events"，这些事件描述数据库修改，例如表创建、修改表数据等
4. 也会记录潜在的可能修改数据的事件，例如DELETE没有匹配任何行，除非row-based记录方式被使用。（这里可能说，DELETE虽然没有匹配任何行，但传输到从节点，可能会删除一些能匹配的行。）
5. 二进制日志也会包含每条语句花费的时间；
6. 二进制日志有两个重要目录，第一个是，复制，提供给副本执行，达到主从数据一致。第二个是，特定数据恢复操作，当一个备份保存后，二进制日志是备份之后的events记录。 (增量恢复)
7. 二进制日志，不用来记录select show等不修改数据的事件
8. 开启二进制日志，会让性能稍微下降。但副本和恢复好处更多，相比于性能下降。
9. 语句中的密码会被特殊处理
10. mysql 8.0.14开始，二进制日志和延迟日志能够被加密，避免敏感数据泄漏，需要binlog_encryption设置为on
11. 默认开启，log_bin默认ON。例外情况，如果用mysqld加上--initialize或者--initialize-insecure去初始化数据目录，二进制日志默认关闭，但你能够使用--log-bin指定开启
12. 要关闭，可以在启动时，指定--skip-log-bin或者disable-log-bin选项，如果指定了前面说的，又指定--log-bin，那么后者生效
13.  --log-slave-updates and --slave-preserve-commit-order这两个参数跟二进制开启有关；
14. --log-bin[=base_name]可以指定基本名，默认binlog作为基本名。为了和早期版本兼容，--log-bin没带字符串或带了空字符串，基本名默认是 host_name-bin，使用了主机机器名. 推荐指定名字，因为如果主机名修改了，你还能很方便地继续用这些二进制日志。如果指定了扩展名，例如--log-bin=base_name.extension，扩展名会被移除和忽略
15. mysqld追加数字扩展名到二进制日志基本名，每次服务器创建新的日志文件，数字就会增加，为了创建有序的系列文件and ordered series of files。创建新文件，会当任意一个这些事件发生，1. 服务器启动或重启；2. 服务端flush日志；3. 当当前日志文件大小达到max_binlog_size。原话 1. The server is started or restarted; 2.The server flushes the logs; 3. The size of the current log file reaches max_binlog_size.
16. 二进制日志可能比max_binlog_size大，如果正在进行很大的事务操作，因为一个事务会被当成整体写入到日志，永远不会被拆分到多个文件。
17. 为了追踪那个二进制日志已经被用过了，mysqld会创建二进制日志索引文件，这个文件包含二进制文件的路径。默认基础名一样，后缀是.index。可以通过 --log-bin-index[=file_name] 指定索引文件。不应该运行期间手动修改，这样子可能会让mysqld confused
18. 术语 “binary log file”表示一个有数字的二进制日志文件。"binary log"表示一系列有数字的二进制文件和索引文件index file
19. 默认放在数据目录，也可以指定到其他目录
20. mysql 5.7 必须指定server_id才能有二进制日志，mysql 8.0 server_id默认是1，所以可以不需要特地指定。但是如果要进行主从复制，需要手动指定，每个server唯一的server_id
21. 二进制日志签名相关参数 binlog_checksum source_verify_checksum replica_sql_verify_checksum...
22. event记录的格式，由binary logging format决定。三种，row-based logging, statement-based logging and mixed-base logging.
23. reset master，删除所有二进制文件，或者 PURGE BINARY LOGS.
24. 如果有副本，不应该删除旧的二进制文件，直到你确保没有副本需要用到它们。
25. mysqlbinlog工具能够展示二进制文件内容。对于恢复数据非常有用，例如$> mysqlbinlog log_file | mysql -h server_name。mysqlbinlog也能展示副本relay log的内容。因为relay log的格式跟binary log格式一样。
26. 二进制日志会在一个语句或事务完成后马上记录，但在任何锁释放和任何提交完成之前。这个保证了日志记录是the log is logged in commit order。非事务表，语句执行后，马上记录。如果是未提交的事务，所有修改会被缓存知道COMMIT语句到达服务器。这种情况，mysqld会写整个事务到binary log在commit执行前。(不是太理解，多看原文)
27. binlog_cache_size 控制分配的buffer大小，如果语句比较大，线程会开启一个临时文件去存储事务。线程结束时，临时文件会被删除。
28.  Binlog_cache_use  Binlog_cache_disk_use   max_binlog_cache_size 缓存相关参数
29. 默认同步写入磁盘sync_binlog=1。如果不同步，当出现崩溃，最后的语句可能会丢失。最安全的值是sync_binlog=1，但也是最慢的。
30. In MySQL 8.0, InnoDB support for two-phase commit in XA transactions is always enabled. 两阶段提交
31. the latest binary log file 最新的二进制日志文件

**其他**

1.  --binlog-format=ROW. row-based logging默认。受影响的表行还会记录events
2. --binlog-format=STATEMENT statement-based logging. 主从复制时比较有用。
3. --binlog-format=MIXED mixed logging。这个模式 statement-based会被默认使用，但会自动切换为 row-based模式，如果出现以下情况 
4. mysql 8.0开始 二进制日志默认开启，除非指定 --skip-log-bin or --disable-log-bin启动参数。
5. binlog format可以运行时切换，例如SET GLOBAL binlog_format = 'STATEMENT'; 'ROW'; 'MIXED'; 独立的客户都安可以控制他自己的语句格式，通过设置SET SESSION binlog_format = 'STATEMENT'; 'ROW'; 'MIXED'; 有些情况不能切换，例如1. function或trigger里面不能切换 2. NDB存储引擎开启时不能切换； 3. ... 。但是可以设置持久化only，不会修改运行时，但重启时会生效。use PERSIST_ONLY (SET @@PERSIST_ONLY.binlog_format)。不推荐运行时切换。涉及主从，最好一开始就统一使用同一个种格式。后期切换格式，需要考虑，是否会造成解析问题。
6. 设置row格式，一些修改使用row格式，但有一些修改依然会使用statement格式，例如所有DDL语句  CREATE TABLE, ALTER TABLE, or DROP TABLE.
7. --binlog-row-event-max-size 行事件最大大小
8. mixed格式，statement格式自动切换为row格式，当出现1. 一个函数包含UUID() 2. ...
9. 8.0.20开始，支持事务压缩 默认关闭 binlog_transaction_compression binlog_transaction_compression_level_zstd 压缩等级，越高压缩越好，但越占用cpu时间。有些情况不会使用压缩，即使开启。事务压缩只用在row格式，statement格式不能压缩。 
10. SHOW BINLOG EVENTS and SHOW RELAYLOG EVENTS statements

## mysqld日志 mysql server logs

1. the error log 错误日志。启动、运行、停止mysqld错误日志
2. the general query log 通用查询日志，"记录客户端连接/断开连接，记录客户端每一个SQL"。当你怀疑某个客户端可能在发错误的指令，但你想知道具体是那个客户端，这种日志就非常有用。平时不开启，影响性能。
3. the binary log 二进制日志
4. the slow query log 慢查询日志
5. the relay log 延迟日志 从一个主节点接收的数据修改 （只用在副本）
6. the DDL log(metadata log) 元数据操作日志 DDL语句

可以在运行期间控制 通用查询日志和慢查询日志，开启/关闭日志或修改日志名(路径)。可以告诉server写通用查询日志/慢查询日志到日志表或日志文件或两者都用。

## 相关链接

https://www.mysql.com/  

https://dev.mysql.com/downloads/mysql/  
https://github.com/mysql/mysql-server  

https://dev.mysql.com/doc/refman/8.0/en/  
https://dev.mysql.com/doc/dev/mysql-server/latest/  
(Related Documentation -> MySQL 8.0 Source Code Documentation)  

## innodb行格式

https://dev.mysql.com/doc/refman/8.0/en/innodb-row-format.html

innodb_default_row_format 默认行格式 dynamic

Table 15.15 InnoDB Row Format Overview

----------------------------
|Row Format|	Compact Storage Characteristics|	Enhanced Variable-Length Column Storage|	Large Index Key Prefix Support|	Compression Support|	Supported Tablespace Types|
|---|---|---|---|---|---|
|REDUNDANT	|No	  |No	  |No	  |No	  |system, file-per-table, general|
|COMPACT	  |Yes	|No	  |No	  |No	  |system, file-per-table, general|
|DYNAMIC	  |Yes	|Yes	|Yes	|No	  |system, file-per-table, general|
|COMPRESSED	|Yes	|Yes	|Yes	|Yes	|file-per-table, general|

```sql
mysql> show variables like '%innodb_%';
+------------------------------------------+------------------------+
| Variable_name                            | Value                  |
+------------------------------------------+------------------------+

| innodb_default_row_format                | dynamic                |

+------------------------------------------+------------------------+
179 rows in set (0.00 sec)
mysql> show table status\G
ERROR 1046 (3D000): No database selected
mysql> show table status from test\G
*************************** 1. row ***************************
           Name: tb1
         Engine: InnoDB
        Version: 10
     Row_format: Dynamic
           Rows: 2
 Avg_row_length: 8192
    Data_length: 16384
Max_data_length: 0
   Index_length: 0
      Data_free: 0
 Auto_increment: NULL
    Create_time: 2023-05-18 15:30:47
    Update_time: 2023-05-18 15:31:36
     Check_time: NULL
      Collation: utf8mb4_0900_ai_ci
       Checksum: NULL
 Create_options: 
        Comment: 
1 row in set (0.00 sec)
```

## innodb_page_size

默认 16k

16384 / 1024 = 16

```sql
mysql> show variables like 'innodb_page_size';
+------------------+-------+
| Variable_name    | Value |
+------------------+-------+
| innodb_page_size | 16384 |
+------------------+-------+
1 row in set (0.02 sec)
```

## mysql客户端执行命令

\! shell-command (需要有一个空格)

```shell
mysql> \?
List of all MySQL commands:
system    (\!) Execute a system shell command.
mysql> \!pwd
ERROR: 
Usage: \! shell-command
mysql> \! pwd
/mysql-source-code-analysis
```

## 数据类型 定长、变长

int char 等是定长数据类型，在innodb中，数据长度不变  
varchar text 等是变长数据类型，在innodb中，数据的头部会记录具体数据大小，数据的长度可变

## 没有SQL

如果没有SQL，就得直接调函数之类的，会很麻烦，由于比较复杂，又不能向redis那样使用简单命令，所以SQL语句是关系型数据库比较好的查询语言。

## InnoDB row_id

InnoDB 找主键作为索引键，没有，则找唯一键做索引键，没有，则使用row_id，隐藏列

## InnoDB 一行记录

一行记录 分 记录头和实际的记录（类似消息头、消息体）   
记录头、记录体，记录头作用非常大，例如变长数据类型，记录头会记录变长数据列的长度，方便读取数据 

```sql
mysql> create database test;
Query OK, 1 row affected (0.00 sec)
mysql> use test;
Database changed
mysql> create table tb1 (col1 int, col2 char(5), col3 varchar(5));
Query OK, 0 rows affected (0.04 sec)
mysql> insert into tb1 values (1, 'aaaa', 'bbbb'), (2, 'aaaaa', 'bbbbb');
Query OK, 2 rows affected (0.01 sec)
Records: 2  Duplicates: 0  Warnings: 0
```

```shell
# hexdump --help
hexdump: invalid option -- '-'
Usage:
 hexdump [options] file...
Options:
 -C              canonical hex+ASCII display
# hexdump -C tb1.ibd 
00000000  50 29 33 e3 00 00 00 00  00 03 1a c0 00 00 00 01  |P)3.............|
00000010  00 00 00 00 01 43 29 2b  00 08 00 00 00 00 00 00  |.....C)+........|
00000020  00 00 00 00 00 0a 00 00  00 0a 00 00 00 00 00 00  |................|
00000030  00 07 00 00 00 40 00 00  40 21 00 00 00 05 00 00  |.....@..@!......|
00000040  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 00 00  |................|
00000050  00 01 00 00 00 00 00 9e  00 00 00 00 00 9e 00 00  |................|
00000060  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 00 00  |................|
00000070  00 00 00 00 00 05 00 00  00 00 ff ff ff ff 00 00  |................|
00000080  ff ff ff ff 00 00 00 00  00 01 00 00 00 02 00 26  |...............&|
00000090  00 00 00 02 00 26 00 00  00 00 00 00 00 00 ff ff  |.....&..........|
000000a0  ff ff 00 00 ff ff ff ff  00 00 00 00 00 02 aa fe  |................|
000000b0  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff 00 00  |................|
000000c0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00002900  00 00 00 00 00 00 00 00  00 00 00 00 01 00 00 00  |................|
00002910  03 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00002920  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00003ff0  00 00 00 00 00 00 00 00  50 29 33 e3 01 43 29 2b  |........P)3..C)+|
00004000  e3 94 67 05 00 00 00 01  00 00 00 00 00 00 00 00  |..g.............|
00004010  00 00 00 00 01 43 1b c6  00 05 00 00 00 00 00 00  |.....C..........|
00004020  00 00 00 00 00 0a 00 00  00 00 00 00 00 00 00 00  |................|
00004030  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00007ff0  00 00 00 00 00 00 00 00  e3 94 67 05 01 43 1b c6  |..........g..C..|
00008000  2b 21 ab d3 00 00 00 02  00 00 00 00 00 00 00 00  |+!..............|
00008010  00 00 00 00 01 43 29 2b  00 03 00 00 00 00 00 00  |.....C)+........|
00008020  00 00 00 00 00 0a ff ff  ff ff 00 00 ff ff ff ff  |................|
00008030  00 00 00 00 00 00 00 00  00 01 00 00 00 00 00 00  |................|
00008040  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 00 00  |................|
*
00008060  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 05 d6  |................|
00008070  69 d2 00 00 00 03 ff ff  ff ff ff ff ff ff ff ff  |i...............|
00008080  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |................|
*
000080f0  ff ff 00 00 00 00 00 00  00 02 00 00 00 00 00 00  |................|
00008100  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 00 00  |................|
*
00008120  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 05 d6  |................|
00008130  69 d2 ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |i...............|
00008140  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |................|
*
000081b0  ff ff 00 00 00 00 00 00  00 03 00 00 00 00 00 00  |................|
000081c0  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 00 00  |................|
*
000081e0  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 05 d6  |................|
000081f0  69 d2 00 00 00 04 ff ff  ff ff ff ff ff ff ff ff  |i...............|
00008200  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |................|
*
00008270  ff ff 00 00 00 00 00 00  00 04 00 00 00 00 00 00  |................|
00008280  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 00 00  |................|
*
000082a0  00 00 ff ff ff ff 00 00  ff ff ff ff 00 00 05 d6  |................|
000082b0  69 d2 ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |i...............|
000082c0  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |................|
*
00008330  ff ff 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00008340  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
0000bff0  00 00 00 00 00 00 00 00  2b 21 ab d3 01 43 29 2b  |........+!...C)+|
0000c000  2a 32 3a 1c 00 00 00 03  ff ff ff ff ff ff ff ff  |*2:.............|
0000c010  00 00 00 00 01 43 42 31  45 bd 00 00 00 00 00 00  |.....CB1E.......|
0000c020  00 00 00 00 00 0a 00 02  05 96 80 04 00 00 00 00  |................|
0000c030  01 a5 00 01 00 01 00 02  00 00 00 00 00 00 00 00  |................|
0000c040  00 00 ff ff ff ff ff ff  ff ff 00 00 00 0a 00 00  |................|
0000c050  00 02 00 f2 00 00 00 0a  00 00 00 02 00 32 01 00  |.............2..|
0000c060  02 01 42 69 6e 66 69 6d  75 6d 00 03 00 0b 00 00  |..Binfimum......|
0000c070  73 75 70 72 65 6d 75 6d  fe 80 00 00 10 ff f1 00  |supremum........|
0000c080  00 00 02 00 00 00 00 00  00 00 0f 00 00 00 00 41  |...............A|
0000c090  14 82 00 00 01 0a 02 33  00 00 01 94 00 00 00 fe  |.......3........|
0000c0a0  78 9c 6d 90 c1 4e c3 30  10 44 ff 65 cf 55 1b b7  |x.m..N.0.D.e.U..|
0000c0b0  a5 40 ac 5c 10 17 2e 9c  b8 21 64 39 f1 b6 5a 94  |.@.\.....!d9..Z.|
0000c0c0  d8 c1 bb ad 08 51 fe 1d  27 a1 11 48 1c 77 66 3c  |.....Q..'..H.wf<|
0000c0d0  7a e3 1e 9a 8e 3f 6a 67  2e 18 99 82 37 e4 20 df  |z....?jg....7. .|
0000c0e0  66 bb fd cd 61 05 6e 91  21 bf cb b2 ed 6e 05 ec  |f...a.n.!....n..|
0000c0f0  e8 8f a6 ee a7 58 28 df  b1 12 23 5d 8b 90 c3 8b  |.....X(...#]....|
0000c100  2d 6b e4 d6 56 08 bf 5c  c8 7b f0 b6 19 03 82 2c  |-k..V..\.{.....,|
0000c110  1b 29 55 b2 ab d0 34 e8  93 09 e9 08 ad a4 62 4e  |.)U...4.......bN|
0000c120  87 3d 4b c0 4f 41 ef 0c  d3 17 16 99 46 5f c5 6e  |.=K.OA......F_.n|
0000c130  f2 8b 67 9d b2 8c a6 8d  74 b1 82 c6 59 b1 e9 cd  |..g.....t...Y...|
0000c140  b1 b6 27 2e d4 61 af 6e  35 b9 42 65 9a 31 26 d8  |..'..a.n5.Be.1&.|
0000c150  2b 70 31 ef d2 13 d9 22  2a cd 92 4a 0a 1f 62 63  |+p1...."*..J..bc|
0000c160  eb b1 19 fd 89 fc 88 f9  e4 7d 78 7c 58 14 63 45  |.........}x|X.cE|
0000c170  22 95 67 c1 99 f6 48 69  25 e4 af 3d 84 e8 c8 db  |".g...Hi%..=....|
0000c180  da b4 81 49 a6 af 51 b3  fd b3 77 bd b9 2e 5e 53  |...I..Q...w...^S|
0000c190  e9 fe 85 9f 81 61 78 1b  86 6f 16 77 88 db d0 83  |.....ax..o.w....|
0000c1a0  00 00 18 fe da 00 00 00  01 00 00 00 00 00 00 01  |................|
0000c1b0  96 00 00 00 00 41 14 82  00 00 01 0a 02 4b 00 00  |.....A.......K..|
0000c1c0  18 e0 00 00 03 d0 78 9c  ed 59 5d 6f db 36 14 fd  |......x..Y]o.6..|
0000c1d0  2f 7c da 00 03 95 64 49  8e 6d f8 61 45 5e 02 74  |/|....dI.m.aE^.t|
0000c1e0  6b 61 04 e8 86 61 20 68  89 b6 d9 50 a4 46 52 6e  |ka...a h...P.FRn|
0000c1f0  dc 20 ff bd 97 94 ac af  b0 68 6b a4 68 50 f8 2d  |. .......hk.hP.-|
0000c200  3c 97 ba 5f 3c e7 1a 64  1e 50 71 d4 ff f3 1c 1f  |<.._<..d.Pq.....|
0000c210  a8 d2 4c 0a cc 72 b4 88  82 69 9c a4 13 94 b7 30  |..L..r...i.....0|
0000c220  5a 5c 05 41 34 9d 20 9d  b3 01 16 ce dd 36 b9 f9  |Z\.A4. ......6..|
0000c230  40 33 83 cd b1 a4 68 81  6e c9 86 53 d4 33 a0 c5  |@3....h.n..S.3..|
0000c240  03 12 a4 b0 36 b3 09 c1  e2 82 7a 63 66 8a 12 43  |....6.....zcf..C|
0000c250  1d 10 4d 83 24 bc 0a 66  d3 20 9e 4d 10 27 da 60  |..M.$..f. .M.'.`|
0000c260  c2 0d 55 3e eb 9e e5 39  85 94 c2 09 92 a5 01 a7  |..U>...9........|
0000c270  1a 62 91 c3 0e 2b f9 11  73 2a 76 66 bf 0a 96 54  |.b...+..s*vf...T|
0000c280  64 ea 58 d6 79 ae fe 5a  de d1 23 de 70 99 dd 61  |d.X.y..Z..#.p..a|
0000c290  cd 3e 51 b0 03 a0 71 ce  b4 cd 3f 87 75 49 c0 a6  |.>Q...q...?.uI..|
0000c2a0  68 26 55 be 0a 97 da 10  a3 31 a9 8c b4 18 e1 19  |h&U......1......|
0000c2b0  ec a8 31 4d 8a 92 53 5c  92 1d d5 00 42 81 99 e4  |..1M..S\....B...|
0000c2c0  55 61 93 f8 b7 ad 1c 20  5b 7a dd a3 78 82 98 c6  |Ua..... [z..x...|
0000c2d0  a2 e2 dc f5 6a 61 54 45  1d f4 89 2a b9 65 9c a3  |....jaTE...*.e..|
0000c2e0  c5 96 70 5d 63 95 d0 6c  27 6c d9 1d e6 d2 60 50  |..p]c..l'l....`P|
0000c2f0  0f 2d a8 30 7d cb 81 29  53 91 ce 41 bf 35 2a 67  |.-.0}..)S..A.5*g|
0000c300  82 70 5c 4a cd 8c 3b 42  00 b3 3d 51 4d 8b 60 0d  |.p\J..;B..=QM.`.|
0000c310  80 a8 0a aa 58 86 4b a8  92 d5 27 1d 06 1d ac a1  |....X.K...'.....|
0000c320  74 c8 78 8c b8 62 da a0  39 1c a2 61 05 ed 3b 09  |t.x..b..9..a..;.|
0000c330  7c 70 f3 19 84 dd 13 68  88 c4 39 dd 92 8a 77 15  ||p.....h..9...w.|
0000c340  35 6b 7c 20 bc 3a 05 a9  bb a5 95 06 ea 78 a0 3a  |5k| .:.......x.:|
0000c350  54 ff 3b 68 3f 1a bb aa  cc f6 6a f0 f1 53 f3 f0  |T.;h?.....j..S..|
0000c360  b3 9a 58 35 56 95 b6 94  01 94 c9 a2 3e 0a bb d8  |..X5V.......>...|
0000c370  51 41 15 b1 46 4c ef a1  58 ad db 7d 5e 53 2f 5c  |QA..FL..X..}^S/\|
0000c380  c7 5f 26 80 ed 90 0d ce  64 25 4c 4d 2c 6d 7b c7  |._&.....d%LM,m{.|
0000c390  0e 36 38 64 40 ac a2 2c  83 a0 ea 55 18 cc 42 bb  |.68d@..,...U..B.|
0000c3a0  05 8e 92 09 8a 89 31 8a  6d 2a d3 14 af 81 c6 22  |......1.m*....."|
0000c3b0  27 ea 88 fd f6 9a b1 18  24 50 b3 a2 5e 5a b6 9e  |'.......$P..^Z..|
0000c3c0  72 83 74 ac 77 ee 18 67  a9 fd 9f db c6 eb 5a 9c  |r.t.w..g......Z.|
0000c3d0  88 93 c4 51 10 ea e2 2c  63 06 b7 e6 e6 38 1f 27  |...Q...,c....8.'|
0000c3e0  7d 39 44 ad 1c a2 f9 0b  d1 43 34 d2 43 14 78 f5  |}9D......C4.C.x.|
0000c3f0  f0 cd 72 68 98 75 51 c3  2f a7 06 4b 93 df 92 df  |..rh.uQ./..K....|
0000c400  9f 57 11 d3 56 11 61 fa  42 14 31 bd 28 e2 a2 88  |.W..V.a.B.1.(...|
0000c410  6f 52 c4 81 a8 e7 17 c5  f5 6b bc 7e fb 1e df 5c  |oR.......k.~...\|
0000c420  77 ca 08 46 ca e8 88 fd  e3 a4 11 f9 a4 11 8f a4  |w..F............|
0000c430  91 5e 94 f1 42 94 f1 73  85 f0 15 fa a7 d3 ef 61  |.^..B..s.......a|
0000c440  ff ed fa ef 97 c9 fe e4  c2 fe 0b fb 7f 34 fb d7  |.............4..|
0000c450  6f df bc c1 ef 6e d7 2d  ff c7 17 85 9f 46 ff 74  |o....n.-.....F.t|
0000c460  44 ff d9 85 fe 17 fa 3f  03 fd e1 0b 9d ed 69 41  |D......?......iA|
0000c470  b0 a2 5b 9b 38 d5 66 58  91 75 63 ab 38 d5 00 9b  |..[.8.fX.uc.8...|
0000c480  6e 84 90 d7 af 51 f3 4a  06 9f 67 77 34 c7 5b a9  |n....Q.J..gw4.[.|
0000c490  70 55 ee 14 c9 e9 e0 ad  2d 18 75 fd 69 b7 ce ee  |pU......-.u.i...|
0000c4a0  8f 7d 6e 83 b0 05 31 4e  36 25 51 c6 e9 a5 79 1a  |.}n...1N6%Q...y.|
0000c4b0  0c fa d0 f8 84 7d 16 0f  9f da 6d 4c ec 9c 47 5d  |.....}....mL..G]|
0000c4c0  6d 3c 71 06 e8 38 d4 17  8c 9e 68 fd 9d a7 80 4c  |m<q..8....h....L|
0000c4d0  e4 f4 9e 0e 1e f7 de ad  6f fe fc 63 fd 0f ea 86  |........o..c....|
0000c4e0  46 7b 5f 6b 88 db 1b 42  fe 67 b8 fe 89 7c 85 cc  |F{_k...B.g...|..|
0000c4f0  96 c6 69 b4 54 52 9a 55  bc d4 25 c9 1a 6a 2f 87  |..i.TR.U..%..j/.|
0000c500  34 37 ea de fd 9d a6 a9  bb 1c 34 8f 2d 13 44 f8  |47........4.-.D.|
0000c510  4e 2a 66 f6 85 5b d9 a1  78 02 5a 66 0e 07 a3 66  |N*f..[..x.Zf...f|
0000c520  bd 4b e8 53 da 9d 47 96  9e 4e 1e fc 4d 39 0d d7  |.K.S..G..N..M9..|
0000c530  38 9a c7 f3 74 16 cd 13  d7 3d aa 5c de c3 56 37  |8...t....=.\..V7|
0000c540  5a 94 e5 3d 5c 5a ed af  88 f7 75 e7 5c 8f b1 df  |Z..=\Z....u.\...|
0000c550  e3 f4 7c 8f 89 df 63 7c  be c7 c0 ef 31 39 df 63  |..|...c|....19.c|
0000c560  e8 f7 98 9e ef 31 b2 03  ce b1 b4 a6 6d 37 e4 5e  |.....1......m7.^|
0000c570  d9 7f 0d 58 2b cc 0f 0a  bf da 76 c8 9e 46 a8 1d  |...X+.....v..F..|
0000c580  68 30 2a 85 36 8a b0 76  b2 b6 c2 fc d2 2d f3 f1  |h0*.6..v.....-..|
0000c590  f1 33 49 e2 b2 5c 00 00  00 00 00 00 00 00 00 00  |.3I..\..........|
0000c5a0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
0000fff0  00 00 00 00 00 70 00 63  2a 32 3a 1c 01 43 42 31  |.....p.c*2:..CB1|
00010000  2d 48 e6 86 00 00 00 04  ff ff ff ff ff ff ff ff  |-H..............|
00010010  00 00 00 00 01 43 46 ab  45 bf 00 00 00 00 00 00  |.....CF.E.......|
00010020  00 00 00 00 00 0a 00 02  00 c9 80 04 00 00 00 00  |................|
00010030  00 a8 00 02 00 01 00 02  00 00 00 00 00 00 00 00  |................|
00010040  00 00 00 00 00 00 00 00  00 a2 00 00 00 0a 00 00  |................|
00010050  00 02 02 72 00 00 00 0a  00 00 00 02 01 b2 01 00  |...r............|
00010060  02 00 1d 69 6e 66 69 6d  75 6d 00 03 00 0b 00 00  |...infimum......|
00010070  73 75 70 72 65 6d 75 6d  04 05 00 00 00 10 00 28  |supremum.......(|
00010080  00 00 00 00 03 00 00 00  00 00 41 1c 81 00 00 01  |..........A.....|
00010090  08 01 10 80 00 00 01 61  61 61 61 20 62 62 62 62  |.......aaaa bbbb|
000100a0  05 05 00 00 00 18 ff c8  00 00 00 00 03 01 00 00  |................|
000100b0  00 00 41 1c 81 00 00 01  08 01 1f 80 00 00 02 61  |..A............a|
000100c0  61 61 61 61 62 62 62 62  62 00 00 00 00 00 00 00  |aaaabbbbb.......|
000100d0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00013ff0  00 00 00 00 00 70 00 63  2d 48 e6 86 01 43 46 ab  |.....p.c-H...CF.|
00014000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
0001c000
```

```
可以看到 (1, 'aaaa', 'bbbb'), (2, 'aaaaa', 'bbbbb') 数据在最后，  
01 61  61 61 61 20 62 62 62 62   定长char貌似使用20空格来填充
02 61  61 61 61 61 62 62 62 62 62
```

## InnoDB 逻辑存储结构

```
表空间、段、区、页 
tablespace segment extent page  

注：页在一些文档也叫块block

1. InnoDB 所有数据都被逻辑地存储在表空间，一个表空间里面有多个段，一个段里面有多个区，一个区里面有多个页，一个页里面有多条数据记录(行)。
2. 段分为数据段、索引段、回滚段等
3. 区大小为1MB，一个区由64个连续页组成，页默认值16K；页为逻辑页，磁盘物理页大小一般为4K，一个扇区大小；
4. 为了保证区中页的连续性，存储引擎一般一次从磁盘申请4~5个区；
5. B+数一个节点的大小就是一个页的大小，16K；
6. InnoDB 非叶子节点只记录索引，叶子节点记录数据；
7. 默认情况下InnoDB有一个共享表空间ibdata1，所有数据都存放在这个表空间内，innodb_file_per_table开启情况下，每张表的数据可以单独放在一个表空间内，需要注意，只是存放数据、索引和bitmap页，其他数据，如回滚undo、插入缓冲索引页、系统事务信息等还是存放在原来共享表空间内ibdata1；
    mysql> SHOW VARIABLES LIKE 'innodb_data_file_path';
    +-----------------------+------------------------+
    | Variable_name         | Value                  |
    +-----------------------+------------------------+
    | innodb_data_file_path | ibdata1:12M:autoextend |
    +-----------------------+------------------------+
    1 row in set (0.00 sec)
    mysql> SHOW VARIABLES LIKE 'innodb_file_per_table';
    +-----------------------+-------+
    | Variable_name         | Value |
    +-----------------------+-------+
    | innodb_file_per_table | ON    |
    +-----------------------+-------+
    1 row in set (0.00 sec)
8. 共享表ibdata1，会不断增加其大小，因为如果开启innodb_file_per_table，表的有些信息还是存储在这里；
9. 
```

## 机械硬盘 固态硬盘

机械硬盘 HHD 

```
1. 磁头、盘片、电动机、芯片、排线等组成；
2. 一块硬盘有多个盘片，每个盘片都有磁头，所有磁头绑在一起移动；
3. 磁头与盘片不直接接触，能感应气流，始终保持某个间隙；
4. 盘片被划分一个一个磁道，一个磁道被划分一个一个扇区，每个扇区存放的数据量相同，最内侧磁道上扇区面积最小，数据密度最大；如果硬盘，使用ZBR，不同磁道扇区数量不同，外圈较多，内圈较少，大体实现等密度，能获得更多的存储空间；
5. 以扇区为单位读取和写入数据，即使只需几个字节的数据，也必须把扇区所有数据读入内存，然后进行筛选所需数据
6. 柱面，所有盘面同一个扇区组成柱面，因为所有磁头绑在一起移动，所以读取数据按照柱面来进行读取；
7. 每个扇区里面，记录数据的bit 01数据；
8. 电机转动会有大噪音；
9. 扇区大小，以前512B，大概2010年左右，厂商开始普遍使用一个扇区4096B，也就是4K；
10. 扇区是硬盘的最小存储单元。大多数磁盘分区方案旨在使文件占据整数个扇区，而不管文件的实际大小如何。未填充完整个扇区的文件将最后一个扇区的其余部分填充零。实际上，操作系统通常使用数据块操作，数据块可跨越多个扇区；
```

固态硬盘 SSD

```
1. 固态电子存储芯片阵列；
2. 无机械装置，例如无磁头、无电动机，全部由电子芯片及电路板组成；
3. 主控芯片、内存颗粒、缓存单元；
4. 类似U盘，无噪音
```

## MySQL Schema vs Database

Schema 和 Database 是类似的概念，貌似是一个可相互替换的词汇

## MySQL Routine Procedure Function

https://dev.mysql.com/doc/refman/8.0/en/information-schema-routines-table.html

Stored Routines 包括 Stored Procedures 和 Stored Functions

中文名 存储例程 存储过程 存储函数

## MySQL 源码规范

1. 项目名使用小写+短横线 例如 mysql-8.0.33
2. 模块名/目录名使用小写+短横线或下划线 或者 首字母大写 例如 mysql-test doxygen_resources Docs
3. 文件名使用 小写+下划线，头文件.h C++文件.cc
4. 类名使用首字母大写+下划线 例如 Service_visitor Select_lex_visitor List_iterator
5. 函数名使用下划线命名 例如 wild_compare
6. 方法名使用下划线命名 例如 create_result_table init_json_table_col_lists
7. 变量名使用下划线命名 例如 current_nest_idx current_thd
8. 枚举值使用大写字母下划线命名 例如 JTC_ORDINALITY
9. 函数返回值 0表示成功 大于0表示出现错误 例如 if (my_init()) { 错误处理... }
10. 宏常量使用 大写字母下划线命名 例如 #define MYSQL_PORT 3306     #define MYSQL_CONFIG_NAME "my"

## 自增ID 源码分析

表自增ID

断点 sql/handler.cc - compute_next_insert_id （sql说明id是Server层计算，而不是引擎层）

mysql> insert into db1.tb1 values (null);
ERROR 1062 (23000): Duplicate entry '4294967295' for key 'tb1.PRIMARY'

```c++
// row 插入 error是DB_DUPLICATE_KEY
error = row_insert_for_mysql((byte *)record, m_prebuilt);
// 设置下一个插入ID
set_next_insert_id(compute_next_insert_id(nr, variables));

// 计算下一个插入ID 算出来的是 4294967296
compute_next_insert_id(ulonglong nr, System_variables * variables) (sql\handler.cc:3580)
handler::update_auto_increment(handler * const this) (sql\handler.cc:3840)
ha_innobase::write_row(ha_innobase * const this, uchar * record) (storage\innobase\handler\ha_innodb.cc:9023)
handler::ha_write_row(handler * const this, uchar * buf) (sql\handler.cc:7953)
write_record(THD * thd, TABLE * table, COPY_INFO * info, COPY_INFO * update) (sql\sql_insert.cc:2160)
Sql_cmd_insert_values::execute_inner(Sql_cmd_insert_values * const this, THD * thd) (sql\sql_insert.cc:629)
Sql_cmd_dml::execute(Sql_cmd_dml * const this, THD * thd) (sql\sql_select.cc:578)
mysql_execute_command(THD * thd, bool first_level) (sql\sql_parse.cc:3683)
dispatch_sql_command(THD * thd, Parser_state * parser_state) (sql\sql_parse.cc:5363)
dispatch_command(THD * thd, const COM_DATA * com_data, enum_server_command command) (sql\sql_parse.cc:2050)
do_command(THD * thd) (sql\sql_parse.cc:1439)
handle_connection(void * arg) (sql\conn_handler\connection_handler_per_thread.cc:302)
pfs_spawn_thread(void * arg) (storage\perfschema\pfs.cc:3042)
libpthread.so.0!start_thread (Unknown Source:0)
libc.so.6!clone (Unknown Source:0)
```

mysql 有很多自增ID 

1. 表自增ID (如果超过，会回退到最大，如果最大已有，报Duplicate entry错误)
2. 没有提供表自增ID时，mysql额外加上的自增ID row_id、 
3. trx_id 事务ID (如果超过，从0开始)
4. Xid
5. 线程的ID
6. 表的编号ID
7. binlog日志文件的ID

如果超过最大怎么办？一般两种解决思路，不再增长，报错，或者继续从0开始增长

```sql
create database db1;
use db1;
create table tb1 (a int unsigned not null auto_increment, primary key (a)) auto_increment=4294967295;
-- auto_increment=4294967295 表示第一次或新插入的ID是4294967295，然后在自增...
-- 无符号整数 最大 4294967296 - 1 = 4294967296
insert into tb1 values (null);
-- Query OK, 1 row affected (0.02 sec)
insert into tb1 values (null);
-- ERROR 1062 (23000): Duplicate entry '4294967295' for key 'tb1.PRIMARY'
```


表无自增ID，被mysql加上的隐藏的自增ID row_id 

(貌似innodb引擎才会，其他引擎待验证是否会加上row_id)

断点打在 storage/innobase/row/row0ins.cc - row_ins_alloc_row_id_step

```sql
use db1;
create table tb2 (a int);
insert into tb2 values (1);
insert into tb2 values (2);
-- 证明多张表共用row_id
create table tb3 (a int);
insert into tb3 values (1);
```

```c++
// 行插入分配行ID 分配的row_id是513 多张表共用row_id 例如
// tb2插入时的row_id时513
// tb3插入时的row_id是514
// 获取新的row_id
row_id = dict_sys_get_new_row_id();

row_ins_alloc_row_id_step(ins_node_t * node) (storage\innobase\row\row0ins.cc:3465)
row_ins(ins_node_t * node, que_thr_t * thr) (storage\innobase\row\row0ins.cc:3538)
row_ins_step(que_thr_t * thr) (storage\innobase\row\row0ins.cc:3681)
row_insert_for_mysql_using_ins_graph(const byte * mysql_rec, row_prebuilt_t * prebuilt) (storage\innobase\row\row0mysql.cc:1585)
row_insert_for_mysql(const byte * mysql_rec, row_prebuilt_t * prebuilt) (storage\innobase\row\row0mysql.cc:1715)
ha_innobase::write_row(ha_innobase * const this, uchar * record) (storage\innobase\handler\ha_innodb.cc:9063)
handler::ha_write_row(handler * const this, uchar * buf) (sql\handler.cc:7953)
write_record(THD * thd, TABLE * table, COPY_INFO * info, COPY_INFO * update) (sql\sql_insert.cc:2160)
Sql_cmd_insert_values::execute_inner(Sql_cmd_insert_values * const this, THD * thd) (sql\sql_insert.cc:629)
Sql_cmd_dml::execute(Sql_cmd_dml * const this, THD * thd) (sql\sql_select.cc:578)
mysql_execute_command(THD * thd, bool first_level) (sql\sql_parse.cc:3683)
dispatch_sql_command(THD * thd, Parser_state * parser_state) (sql\sql_parse.cc:5363)
dispatch_command(THD * thd, const COM_DATA * com_data, enum_server_command command) (sql\sql_parse.cc:2050)
do_command(THD * thd) (sql\sql_parse.cc:1439)
handle_connection(void * arg) (sql\conn_handler\connection_handler_per_thread.cc:302)
pfs_spawn_thread(void * arg) (storage\perfschema\pfs.cc:3042)
libpthread.so.0!start_thread (Unknown Source:0)
libc.so.6!clone (Unknown Source:0)
```

## 源码目录补充

最重要的两个目录  
1. sql Server层的代码主要在这
2. storage 引擎层的代码主要在这

storage/innobase  
storage/myisam  
storage/csv  

增删改查...

sql/sql_insert.cc
sql/sql_delete.cc
sql/sql_update.cc
sql/sql_select.cc
...  

## 表存储引擎分析

```

```

## 监听端口 客户端连接源码分析

```c++
进程 mysqld
  线程 main
    sql/main.cc - main
    sql/mysqld.cc - mysqld_main 7237   
    sql/mysqld.cc - network_init 
    sql/conn_handler/socket_connection.cc - Mysqld_socket_listener::Mysqld_socket_listener  创建 Mysqld_socket_listener 提供 绑定地址 TCP端口 admin绑定地址 adminTCP端口 backlog等 例如 3306 33062 151  
    sql/conn_handler/connection_acceptor.h - Connection_acceptor::Connection_acceptor 创建连接Acceptor
    mysqld_socket_acceptor->init_connection_acceptor() 初始化
    Mysqld_socket_listener::setup_listener() 设置listener 创建服务端socket
      mysql_socket.fd = socket(domain, type, protocol);  创建socket
    mysqld_socket_acceptor->connection_event_loop(); 连接 事件循环 处理客户端连接

     /**
    Connection acceptor loop to accept connections from clients.
  */
  void connection_event_loop() {
    Connection_handler_manager *mgr =
        Connection_handler_manager::get_instance();
    while (!connection_events_loop_aborted()) {
      Channel_info *channel_info = m_listener->listen_for_connection_event();
      if (channel_info != nullptr) mgr->process_new_connection(channel_info);
    }
  }

  Channel_info *Mysqld_socket_listener::listen_for_connection_event() {
#ifdef HAVE_POLL
  int retval = poll(&m_poll_info.m_fds[0], m_socket_vector.size(), -1);
#else
  m_select_info.m_read_fds = m_select_info.m_client_fds;
  // select 等待事件发生
  int retval = select((int)m_select_info.m_max_used_connection,
                      &m_select_info.m_read_fds, 0, 0, 0);  


  // 客户端连接 mysql -h 127.0.0.1
  
  // 有新客户端连接后 处理新连接
  if (channel_info != nullptr) mgr->process_new_connection(channel_info);
  // 如果不是admin，是普通用户，检查是否超过最大连接数
  bool Connection_handler_manager::check_and_incr_conn_count
  // 添加新连接
  m_connection_handler->add_connection(channel_info)
  // 397行
  Per_thread_connection_handler::add_connection(Channel_info *channel_info)
  // 检查空闲线程，如果有空闲线程用空闲线程
  check_idle_thread_and_enqueue_connection(channel_info)
  // 创建线程或使用空闲线程 处理客户端，每个客户端一个线程
  mysql_thread_create(key_thread_one_connection, &id, &connection_attrib,
                          handle_connection, (void *)channel_info);
  // 在专门处理这个客户端的线程，执行handle_connection
  static void *handle_connection(void *arg)                        
  // 生成一个thd对象
  THD *thd = init_new_thd(channel_info);       
  // 设置线程拥有者
  mysql_socket_set_thread_owner(socket);
  // 把thd加入到thd_manager
  thd_manager->add_thd(thd);
  // do command 执行命令 当线程连接活跃时 
  // 命令执行循环
  while (thd_connection_alive(thd)) {
    if (do_command(thd)) break;
  }                 
  // 分发命令
  return_value = dispatch_command(thd, &com_data, command);

  // 在do_command里面
  // 如果没命令了，会一直等待命令到来，不会让CPU空转，事件驱动
  // 有新命令来，则执行命令
  thd->m_server_idle = true;
  // 这个get_command会阻塞
  rc = thd->get_protocol()->get_command(&com_data, &command);
  thd->m_server_idle = false;

  // 如果因为某些原因，要断开连接了 end_connection close_connection
   if (thd_prepare_connection(thd))
      handler_manager->inc_aborted_connects();
    else {
      while (thd_connection_alive(thd)) {
        if (do_command(thd)) break;
      }
      end_connection(thd);
    }
    close_connection(thd, 0, false, false);
```    

https://dev.mysql.com/doc/extending-mysql/8.0/en/mysql-threads.html

Connection manager threads associate each client connection with a thread dedicated to it that handles authentication and request processing for that connection. Manager threads create a new thread when necessary but try to avoid doing so by consulting the thread cache first to see whether it contains a thread that can be used for the connection. When a connection ends, its thread is returned to the thread cache if the cache is not full.

One-Thread-Per-Connection 模型与 Pool-Threads模型

MySQL每个连接使用一个线程，另外还有内部处理线程、特殊用途的线程、以及所有存储引擎创建的线程。-- 《高性能MySQL》

默认的线程处理模型是对每个客户端连接都创建一个线程，  
一个客户端对应一个线程，一个线程与一个客户端绑定，  
也可以选择使用其他线程处理模型，Pool-Threads 处理模型  
线程池默认是关闭的，要开启这个功能，需要启动实例时指定参数  --thread-handling=pool-of-threads。  

## ORDER BY 源码分析

```sql
SELECT * FROM student ORDER BY name ASC;
```

```c++
filesort(THD * thd, Filesort * filesort, RowIterator * source_iterator, table_map tables_to_get_rowid_for, ha_rows num_rows_estimate, Filesort_info * fs_info, Sort_result * sort_result, ha_rows * found_rows) (sql\filesort.cc:382)
SortingIterator::DoSort(SortingIterator * const this) (sql\iterators\sorting_iterator.cc:531)
SortingIterator::Init(SortingIterator * const this) (sql\iterators\sorting_iterator.cc:444)
Query_expression::ExecuteIteratorQuery(Query_expression * const this, THD * thd) (sql\sql_union.cc:1763)
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

会预测成本/开销，选择最优，会根据阈值，选择内存临时表，还是磁盘临时表等...

## 改完用户权限、用户设置等 为什么要 FLUSH PRIVILEGES

TODO

## MySQL 启动 初始化 停止 源码分析

```c++
进程 mysqld
  线程 main
    sql/main.cc - main
    sql/mysqld.cc - mysqld_main 7237
    sql/mysqld.cc - substitute_progpath 替换程序路径 为 绝对路径
    sql/mysqld.cc - calculate_mysql_home_from_my_progname 根据绝对路径计算家目录
    mysys/my_init.cc - my_init
    mysys/my_default.cc - load_defaults 加载配置文件 加载命令行配置 等
    sql/set_var.cc - sys_var_init 系统变量初始化 
    sql/log.cc - init_error_log 初始化错误日志
    sql/mysqld.cc - adjust_related_options 调整相关选项 例如打开文件数限制、最大连接数 
    sql/mysqld.cc - my_init_signals 初始化信号处理 例如 SIGTERM SIGHUP SIGQUIT 等
    sql/mysqld.cc - network_init 网络初始化 绑定端口 监听 接受客户端连接 ...
    sql/tztime.cc - my_tz_init 时区初始化
    sql/auth/sql_auth_cache.cc - grant_init 权限初始化
    sql/mysqld.cc - start_signal_handler 启动信号处理器 使用单独线程处理信号
    mysqld_socket_acceptor->connection_event_loop(); 连接 事件循环 处理客户端连接
    ...
```

## SQL

执行一条 SQL 其实就是执行一条命令，这样更能理解底层，  
避免使用 SQL 查询，推荐使用 执行 SQL 命令

## 优化器

一条 SQL 可以使用多种方案得到相同的结果，  
MySQL 会为 SQL 分析出多种执行方案，选择成本最少的执行方案执行

Cost-Based Optimizer 基于成本的优化器

这里的成本有 CPU预测 内存预测 硬盘预测 外部库预测等

要计算成本需要有相关的统计数据，如果没有统计数据，可能要靠已有的信息进行猜测，当然可能会猜错

## 查询缓存

哈希表，SQL 大小写、注释等任意字符不一样，缓存就无法击中，  
表数据和表结构的增删改都会让这个表的缓存全部失效，  
所以会被频繁操作的表，例如频繁写入，缓存意义不是很大   
读多写少的表，缓存作用就比较大，省去分析、优化、执行等繁琐操作

SELECT 语句可指定是否使用缓存

mysql 8.0 去掉了 查询缓存

## 可插拔式的表存储引擎

Server层 存储引擎层

每个存储引擎都有统一的一套接口，需要实现每个接口，如果个别接口该存储引擎没这功能，留空即可。

Server层也是有大量相关的接口，直接调用具体存储引擎的实现。

**InnoDB**

按照页的方式管理硬盘，默认16K

mysql 5.5 开始，默认 InnoDB 

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
// 获取精确的记录计数
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

```c++

```

性能

COUNT(*) = COUNT(1) > COUNT(`主键`) > COUNT(`某非主键字段`)

COUNT(*) COUNT(1)    不需要具体取值，效率最高
COUNT(`主键`)        不需要具体取值，默认认为主键里面的值不为NULL，但会有一些额外过程
COUNT(`某非主键字段`) 需要判断 值是否为 NULL，不为NULL才加+，所以需要具体取值，性能最低

InnoDB引擎 默认4个线程 并行 统计 有参数可调

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
3. 连接非常昂贵，尽量使用长连接，长期不用尽快断开

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
yum install -y openssl openssl-devel  
yum install -y  ncurses-devel  
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