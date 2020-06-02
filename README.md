### oracle 12C（12.1.0.2） 自动化静默安装脚本

#### 脚本使用安装前配置

> 需要使用root用户执行(尽量安装纯净的OS环境)
下载脚本：https://github.com/domdanrtsey/Oracle12c_autoinstall.git

1. 安装前请将Oracle 12C安装包（linuxamd64_12102_database_1of2.zip、 linuxamd64_12102_database_2of2.zip ）放置在 /opt/ 目录下（脚本提示是/opt,实际可随意存放）

2. 系统需要具备512MB的swap交换分区

3. OS可连通互联网(如果不通外网，可以使用如下方法，将依赖包下载下来，再上传到目标服务器安装，以解决依赖问题)

   ```shell
   安装插件
   #　yum -y install yum-plugin-downloadonly
   创建目录
   # mkdir /root/mypackages/
   下载依赖
   # yum install --downloadonly --downloaddir=/root/mypackages/ yum install -y binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33.i686 glibc glibc.i686 \
     glibc-devel glibc-devel.i686 ksh libaio libaio.i686 libaio-devel libaio-devel.i686 libX11 libX11.i686 \
     libXau libXau.i686 libXi libXi.i686 libXtst libXtst.i686 libgcc libgcc.i686 libstdc++ libstdc++.i686 \
     libstdc++-devel libstdc++-devel.i686 libxcb libxcb.i686 make nfs-utils net-tools smartmontools sysstat \
     unixODBC unixODBC-devel gcc gcc-c++ libXext libXext.i686 zlib-devel zlib-devel.i686 unzip wget vim lrzsz epel-release net-tools wget ntpdate ntp
   将mypackages文件夹下载下来，上传到目标服务器，在目标环境执行安装
   # cd /root/mypackages/
   安装依赖
   # yum -y localinstall *.rpm
   ```

   

4. OS提前配置以下信息(根据实际情况，配置如下信息)

   - 配置本机静态IP地址 `HostIP`与 `hostname`

   - 脚本中Oracle用户密码 `ORACLE_OS_PWD`默认为`Danrtsey.com` 请根据需要在脚本中修改

   - 脚本默认的`processes`与`sessions`值 如下，请根据实际直接在脚本中修改

     ```shell
     alter system set processes=500 scope=spfile;
     alter system set sessions=555 scope=spfile;
     ```

     

5. 预先将需要修改的配置信息记录下来，安装时根据脚本提示直接粘贴即可，涉及的信息如下

   **数据库的SID名称：**

   ```shell
   ORACLE_SID=orcl
   脚本执行提示如下：
   read -p 'Please input the ORACLE_SID(e.g:orcl):' S1
   Please input the ORACLE_SID(e.g:orcl):
   ```

   **ORACLE_BASE路径：**

   ```shell
   ORACLE_BASE=/u01/oracle
   脚本执行提示如下：
   read -p 'Please input the ORACLE_BASE(e.g:/u01/oracle):' S1
   Please input the ORACLE_BASE(e.g:/u01/oracle):
   ```

   **ORACLE_HOM路径：**

   ```shell
   ORACLE_HOME=/u01/oracle/product/12c/dbhome_1
   脚本执行提示如下:
   read -p 'Please input the ORACLE_HOME(e.g:/u01/oracle/product/12c/dbhome_1):' S1
   Please input the ORACLE_HOME(e.g:/u01/oracle/product/12c/dbhome_1):
   ```

   **数据库安装包1的存放路径：**

   ```shel
   脚本执行提示如下:
   read -p 'Please input the zip file location(e.g:/opt/linuxamd64_12102_database_1of2.zip):' zfileone
   Please input the zip file location(e.g:/opt/linuxamd64_12102_database_1of2.zip):
   ```

   **数据库安装包2的存放路径：**

   ```shell
   脚本执行提示如下:
   read -p 'Please input the zip file location(e.g:/opt/linuxamd64_12102_database_2of2.zip):' zfiletwo
   Please input the zip file location(e.g:/opt/linuxamd64_12102_database_2of2.zip):
   ```

   **数据库安装sys密码：**

   ```shell
   installSysPassword=orcl20200202
   脚本执行提示如下:
   read -p 'Please input the installSysPassword(e.g:orcl20200202):' S1
   Please input the installSysPassword(e.g:orcl20200202):
   ```

   **数据库sys用户密码：**

   ```shell
   SYSPASSWORD=orcl20200202
   脚本执行提示如下:
   read -p "Please input the SYSPASSWORD(e.g:orcl20200202):" S1
   Please input the SYSPASSWORD(e.g:orcl20200202):
   ```

   **数据库连接用户名：**

   ```shell
   USER_NAME=orcl
   脚本执行提示如下:
   read -p "Please input the USER_NAME(e.g:orcl):" S1
   Please input the USER_NAME(e.g:orcl):
   ```

   **数据库连接用户名密码：**

   ```shell
   USER_PASSWD=orcl2020
   脚本执行提示如下:
   read -p "Please input the USER_PASSWD(e.g:orcl2020):" S1
   Please input the USER_PASSWD(e.g:orcl2020):
   ```

   **数据库临时表空间名称：**

   ```shell
   TMP_DBF=orcl_temp
   脚本执行提示如下:
   read -p "Please input the TMP_DBF(e.g:orcl_temp):" S1
   Please input the TMP_DBF(e.g:orcl_temp):
   ```

   **数据库数据表空间名称：**

   ```shell
   DATA_DBF=orcl_data
   脚本执行提示如下:
   read -p "Please input the DATA_DBF(e.g:orcl_data):" S1
   Please input the DATA_DBF(e.g:orcl_data):
   ```

   

6. 脚本执行忽略如下错误提示

   ```shell
   /u01/database/response/netca.rsp:行30: [GENERAL]: 未找到命令
   /u01/database/response/netca.rsp:行62: [oracle.net.ca]: 未找到命令
   或是
   /u01/database/response/netca.rsp:LINE30: [GENERAL]: command not found
   /u01/database/response/netca.rsp:LINE62: [oracle.net.ca]: command not found
   ```

   

7. 

8. 

### 

#### 支持系统

- CentOS 7.X 64

> 注意: 在初始化cdb过程中如果出现 `No options to container mapping specified, no options will be installed in any containers` 信息不是报错，因为cdb初始化时间比较长，可以通过查看以上提示下给出的日志路径查看初始化情况
>
> 熟知以上说明之后，开始操作安装部署

```shell
# tree
|--conf
   |--db_install.rsp
   |--dbca_single.rsp
   |--initcdb.ora
|--oracle12201_install.sh

# chmod +x oracle12201_install.sh
# sh -x oracle12201_install.sh
```

问题1：

```shell
$ dbca -silent -createDatabase -responseFile /ora01/database/response/dbca.rsp
[FATAL] [DBT-11211] The Automatic Memory Management option is not allowed when the total physical memory is greater than 4GB.
   CAUSE: The current total physical memory is 15GB.
解决： automaticMemoryManagement=FALSE
```

问题2：

```shell
[FATAL] [DBT-06103] The port (5,500) is already in use.
ACTION: Specify a free port.
解决：hosts解析问题，eg：oracleip yb-oracle yb-oracle.example.com
```

问题3:

```shell
ORA-28040: 没有匹配的验证协议
解决：在 $ORACLE_HOME/network/admin/sqlnet.ora
  加入如下: 
  SQLNET.ALLOWED_LOGON_VERSION=8
```

疑问：

```shell
initParams=undo_tablespace=UNDOTBS1,memory_target=726MB,processes=300,nls_language=AMERICAN,dispatchers=(PROTOCOL=TCP) 
(SERVICE=orclXDB),db_block_size=8192BYTES,diagnostic_dest={ORACLE_BASE},audit_file_dest={ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/adump,nls_territory=AMERICA,local_listener=LISTENER_ORCL,compatible=12.2.0,control_files=("{ORACLE_BASE}/oradata/{DB_UNIQUE_NAME}/control01.ctl", 
"{ORACLE_BASE}/oradata/{DB_UNIQUE_NAME}/control02.ctl"),db_name=orcl,audit_trail=db,remote_login_passwordfile=EXCLUSIVE,open_cursors=300
```

