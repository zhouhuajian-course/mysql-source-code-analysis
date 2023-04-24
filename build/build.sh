#!/bin/bash

##########################################
# 构建 MySQL
# 
# author zhouhuajian
##########################################

mysqlSourcePath=../mysql-8.0.33

# -DDOWNLOAD_BOOST=0 \ 不需要下载，源码已有BOOST
cmake \
-DCMAKE_INSTALL_PREFIX=${mysqlSourcePath} \
-DDOWNLOAD_BOOST=0 \
-DWITH_BOOST=${mysqlSourcePath}/boost/boost_1_77_0 \
-DWITH_DEBUG=1 \
${mysqlSourcePath}













##########################################
# cmake
# 用法
# cmake [options] <path-to-source>                        [选项] 源码路径
# cmake [options] <path-to-existing-build>                [选项] 已存在构建目录路径
# cmake [options] -S <path-to-source> -B <path-to-build>  [选项] -S 源码路径 -B 构建路径
# 默认当前工作目录是构建目录         
# -D <var>[:<type>]=<value>    = Create or update a cmake cache entry.   缓存实体 键值对
##########################################