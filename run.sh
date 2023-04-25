#!/bin/bash

##########################################
# 构建 mysql 并运行 mysqld
# 
# author zhouhuajian
##########################################

buildPath=./build

if [[ ! -d ${buildPath} ]]; then
  mkdir ${buildPath}
fi

cd ${buildPath}

mysqlSourcePath=../mysql-8.0.33

echo -e "\n\n\n============= cmake =============\n\n\n"

# -DDOWNLOAD_BOOST=0 \ 不需要下载，源码已有BOOST
# 去掉一些存储引擎，加快编译速度
cmake \
-DCMAKE_INSTALL_PREFIX=${mysqlSourcePath} \
-DDOWNLOAD_BOOST=0 \
-DWITH_BOOST=${mysqlSourcePath}/boost/boost_1_77_0 \
-DWITH_DEBUG=1 \
-DWITHOUT_CSV_STORAGE_ENGINE=1 \
-DWITHOUT_BLACKHOLD_STORAGE_ENGINE=1 \
-DWITHOUT_FEDERATED_STORAGE_ENGINE=1 \
-DWITHOUT_ARCHIVE_STORAGE_ENGINE=1 \
-DWITHOUT_MRG_MYISAM_STORAGE_ENGINE=1 \
-DWITHOUT_NDBCLUSTER_STORAGE_ENGINE=1 \
${mysqlSourcePath}

if [[ $? -eq 0 ]]; then
  echo -e "\n\n\n============= make =============\n\n\n"
  make
fi  

echo -e "\n\n\n============= init =============\n\n\n"

# 创建 mysql 用户和用户组
if ! id mysql; then
  groupadd mysql
  useradd -g mysql -m -d /home/mysql -s /bin/bash mysql
  # 提前创建 不然 运行 mysqld 会报错
  mkdir -p /var/lib/mysql/
fi

chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql *

# 初始化
# --initialize-insecure root不需要密码
./bin/mysqld --user=mysql --basedir=$(pwd) --datadir=$(pwd)/data --initialize-insecure

echo -e "\n\n\n============= run =============\n\n\n"

# 执行mysqld
./bin/mysqld --version






















# 启动 mysqld
# ./bin/mysqld --user=mysql --datadir=/mysql-source-code-analysis/build/test/data

# 启动 客户端 调试
# ./bin/mysql -h 127.0.0.1
# mysql> select version();
# +--------------+
# | version()    |
# +--------------+
# | 8.0.33-debug |
# +--------------+
# 1 row in set (0.00 sec)


# myCnfPath=./test/etc/my.cnf

# if [[ ! -d ./test/etc ]] && [[ ! -d ./test/data ]]; then
#   mkdir -p ./test/{etc,data}
#   echo '[mysqld]' > ${myCnfPath}
#   echo '# basedir 需要是程序目录，因为 mysqld 需要 share lib 等目录' >> ${myCnfPath}
#   echo "basedir=$(pwd)" >> ${myCnfPath}
#   echo "datadir=$(pwd)/test/data" >> ${myCnfPath}
# fi

# cmake
# 用法
# cmake [options] <path-to-source>                        [选项] 源码路径
# cmake [options] <path-to-existing-build>                [选项] 已存在构建目录路径
# cmake [options] -S <path-to-source> -B <path-to-build>  [选项] -S 源码路径 -B 构建路径
# 默认当前工作目录是构建目录         
# -D <var>[:<type>]=<value>    = Create or update a cmake cache entry.   缓存实体 键值对

# 其他参考
# cmake . -DCMAKE_INSTALL_PREFIX=/home/mysql/mysql-install \
# -DMYSQL_DATADIR=/home/mysql/mysql-data \
# -DWITH_DEBUG=1 \
# -DWITH_BOOST=/home/mysql/mysql-8.0.27/boost \
# -DCMAKE_C_COMPILER=/usr/bin/gcc \
# -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
# -DFORCE_INSOURCE_BUILD=1

# sudo cmake .. \
# -DDEFAULT_CHARSET=utf8mb4 \
# -DDEFAULT_COLLATION=utf8mb4_unicode_ci \ #
# -DENABLED_LOCAL_INFILE=ON \
# -DWITH_SSL=system \
# -DCMAKE_INSTALL_PREFIX=/usr/local/mysql/server \
# -DMYSQL_DATADIR=/usr/local/mysql/data \
# -DMYSQL_TCP_PORT=3306 \
# -DDOWNLOAD_BOOST=0 \
# -DWITH_BOOST=~/Desktop/boost

# cmake . \
# -DWITH_BOOST=/opt/mysql-8.0.15/boost/ \
# -DCMAKE_INSTALL_PREFIX=/usr/local/mysql-8.0.15 \
# -DMYSQL_DATADIR=/data/mysql \
# -DWITHOUT_CSV_STORAGE_ENGINE=1 \
# -DWITHOUT_BLACKHOLD_STORAGE_ENGINE=1 \
# -DWITHOUT_FEDERATED_STORAGE_ENGINE=1 \
# -DWITHOUT_ARCHIVE_STORAGE_ENGINE=1 \
# -DWITHOUT_MRG_MYISAM_STORAGE_ENGINE=1 \
# -DWITHOUT_NDBCLUSTER_STORAGE_ENGINE=1 \
# -DFORCE_INSOURCE_BUILD=1 \
# -DCMAKE_CXX_COMPILER=/usr/local/bin/g++ \
# -DCMAKE_C_COMPILER=/usr/local/bin/gcc