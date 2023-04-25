#!/bin/bash

##########################################
# 构建 MySQL
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
cmake \
-DCMAKE_INSTALL_PREFIX=${mysqlSourcePath} \
-DDOWNLOAD_BOOST=0 \
-DWITH_BOOST=${mysqlSourcePath}/boost/boost_1_77_0 \
-DWITH_DEBUG=1 \
${mysqlSourcePath}

if [[ $? -eq 0 ]]; then
  echo -e "\n\n\n============= make =============\n\n\n"
  # make -j 3
  make
fi  

myCnfPath=./test/etc/my.cnf

if [[ ! -d ./test/etc ]] && [[ ! -d ./test/data ]]; then
  mkdir -p ./test/{etc,data}
  echo '[mysqld]' > ${myCnfPath}
  echo '# basedir 需要是程序目录，因为 mysqld 需要 share lib 等目录' >> ${myCnfPath}
  echo "basedir=$(pwd)" >> ${myCnfPath}
  echo "datadir=$(pwd)/test/data" >> ${myCnfPath}
fi

# 创建 mysql 用户和用户组
id mysql
if [[ ! $? -eq 0 ]]; then
  groupadd mysql
  useradd -g mysql -m -d /home/mysql -s /bin/bash mysql
  # 提前创建 不然 运行mysqld会报错
  mkdir -p /var/lib/mysql/
  chown -R mysql:mysql /var/lib/mysql
fi

# 递归将 build 归 mysql 所有
chown -R mysql:mysql *



# 初始化
# --initialize-insecure root不需要密码
# ./bin/mysqld --defaults-file=./test/etc/my.cnf --initialize-insecure

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