#!/bin/bash
#script_name: oracle_software.sh
#Author: Danrtsey.Shun
#Email:mydefiniteaim@126.com
#auto_install_oracle12c version=12.1.0.2
####################  Steup 1 Install oracle software ####################
# attentions1:
# 1.上传12c软件安装包至随意路径下,脚本提示路径是 /opt
#
# linuxamd64_12102_database_1of2.zip
# linuxamd64_12102_database_2of2.zip
#
# 2.预设oracle用户的密码为 Danrtsey.com 请根据需要修改
#####################################
#ORACLE_OS_PWD=                     #
#if [ "$ORACLE_OS_PWD" = "" ]; then #
#    ORACLE_OS_PWD="Danrtsey.com"   #
#fi                                 #
#####################################
# 3.选择数据库字符集与国家字符集
# CharacterSet: ZHS16GBK or AL32UTF8
# NationalCharacterSet: AL16UTF16 or UTF8
# 4.默认有开启归档，请根据情况删除该指令
# alter database archivelog;
# 5.执行
# chmod + oracle12.1.0.2_install.sh
# sh -x oracle12.1.0.2_install.sh
#
#################### Steup 2 Install oracle listener & dbca  ####################
# attentions2:
########################################
# 1.according to the different environment to set the processes && sessions value
# alter system set processes=500 scope=spfile;
# alter system set sessions=555 scope=spfile;
########################################

export PATH=$PATH
#Source function library.
. /etc/init.d/functions

#Require root to run this script.
uid=`id | cut -d\( -f1 | cut -d= -f2`
if [ $uid -ne 0 ];then
  action "Please run this script as root." /bin/false
  exit 1
fi

##set oracle password
ORACLE_OS_PWD=
if [ "$ORACLE_OS_PWD" = "" ]; then
    ORACLE_OS_PWD="Danrtsey.com"
fi

###install require packages
echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle install dependency \033[05m...\033[0m"
yum -y install binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33*i686 compat-libstdc++-33*.devel \
  compat-libstdc++-33 compat-libstdc++-33*.devel elfutils-libelf elfutils-libelf-devel gcc gcc-c++ \
  glibc glibc*.i686 glibc-devel glibc-devel*.i686 ksh libaio libaio*.i686 libaio-devel libaio-devel*.devel \
  libgcc libgcc*.i686 libstdc++ libstdc++*.i686 libstdc++-devel libstdc++-devel*.devel libXi libXi*.i686 \
  libXtst libXtst*.i686 make sysstat unixODBC unixODBC*.i686 unixODBC-devel unixODBC-devel*.i686 zip unzip tree \
  vim lrzsz epel-release net-tools wget ntpdate ntp
if [[ $? == 0 ]];then
  echo -e "\033[34mInstallNotice >>\033[0m \033[32myum install dependency successed\033[0m"
else
  echo -e "\033[34mInstallNotice >>\033[0m \033[32myum install dependency faild, pls check your network\033[0m"
  exit
fi

sed -e 's!^metalink=!#metalink=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!//download\.fedoraproject\.org/pub!//mirrors.tuna.tsinghua.edu.cn!g' \
    -e 's!http://mirrors\.tuna!https://mirrors.tuna!g' \
    -i /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-testing.repo

yum makecache fast

###set firewalld & optimize the os system & set selinux
echo "################# Optimize system parameters  ##########################"
firewall_status=`systemctl status firewalld | grep Active |awk '{print $3}'`
if [ ${firewall_status} == "(running)" ];then
  firewall-cmd --permanent --zone=public --add-port=1521/tcp && firewall-cmd --reload
else
  systemctl start firewalld
  firewall-cmd --permanent --zone=public --add-port=1521/tcp && firewall-cmd --reload
fi

SELINUX=`cat /etc/selinux/config |grep ^SELINUX=|awk -F '=' '{print $2}'`
if [ ${SELINUX} == "enforcing" ];then
  sed -i "s@SELINUX=enforcing@SELINUX=disabled@g" /etc/selinux/config
else
  if [ ${SELINUX} == "permissive" ];then
    sed -i "s@SELINUX=permissive@SELINUX=disabled@g" /etc/selinux/config
  fi
fi
setenforce 0

echo "================更改为中文字符集================="
  \cp /etc/locale.conf  /etc/locale.conf.$(date +%F)
cat >>/etc/locale.conf<<EOF
LANG="zh_CN.UTF-8"
#LANG="en_US.UTF-8"
EOF
source /etc/locale.conf
grep LANG /etc/locale.conf
action "更改字符集zh_CN.UTF-8完成" /bin/true
echo "================================================="
echo ""

###set the ip in hosts
echo "############################   Ip&Hosts Configuration  #######################################"
hostname=`hostname`
HostIP=`ip a|grep 'inet '|grep -v '127.0.0.1'|awk '{print $2}'|awk -F '/' '{print $1}'`
for i in ${HostIP}
do
    A=`grep "${i}" /etc/hosts`
    if [ ! -n "${A}" ];then
        echo "${i} ${hostname}" >> /etc/hosts 
    else
        break
    fi
done

###create group&user
echo "############################   Create Group&User  #######################################"
ora_user=oracle
ora_group=('oinstall' 'dba' 'oper')
for i in ${ora_group[@]}
do
    B=`grep '${i}' /etc/group`
    if [ ! -n ${B} ];then
        groupdel ${i} && groupadd ${i}
    else    
        groupadd ${i}
    fi
done
C=`grep 'oracle' /etc/passwd`
if [ ! -n ${C} ];then
    userdel -r ${ora_user} && useradd -u 501 -g ${ora_group[0]} -G ${ora_group[1]},${ora_group[2]} ${ora_user}
else
    useradd -u 501 -g ${ora_group[0]} -G ${ora_group[1]},${ora_group[2]} ${ora_user}
fi
echo "${ORACLE_OS_PWD}" | passwd --stdin ${ora_user}

###create directory and grant priv
echo "############################ Create DIR & set privileges & set OracleSid ##################"
echo "############################   Create OracleBaseDi #######################################"
echo "############################   Create OracleHomeDir #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the ORACLE_SID(e.g:orcl):" S1
    read -p "Please input the ORACLE_SID again(e.g:orcl):" S2
    if [ "${S1}" == "${S2}" ];then
        export ORACLE_SID=${S1}
        break
    else
        echo "You input ORACLE_SID not same."
        count=$[${count}+1]
    fi
done
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the ORACLE_BASE(e.g:/u01/oracle):" S1
        read -p "Please input the ORACLE_BASE again(e.g:/u01/oracle):" S2
        if [ "${S1}" == "${S2}" ];then
                export ORACLE_BASE=${S1}
                break
        else    
                echo "You input ORACLE_BASE not same."
                count=$[${count}+1]
        fi 
done
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the ORACLE_HOME(e.g:/u01/oracle/product/12c/dbhome_1):" S1
        read -p "Please input the ORACLE_HOME again(e.g:/u01/oracle/product/12c/dbhome_1):" S2
        if [ "${S1}" == "${S2}" ];then
                export ORACLE_HOME=${S1}
                break
        else        
                echo "You input ORACLE_HOME not same."
                count=$[${count}+1]
        fi      
done
if [ ! -d ${ORACLE_HOME} ];then
    mkdir -p ${ORACLE_HOME}
fi
if [ ! -d ${ORACLE_BASE}/data ];then
    mkdir -p ${ORACLE_BASE}/data
fi
if [ ! -d ${ORACLE_BASE}/recovery ];then
    mkdir -p ${ORACLE_BASE}/recovery
fi
ora_dir=`echo ${ORACLE_BASE}|awk -F '/' '{print $2}'`

###set the sysctl,limits and profile
echo "############################   Configure environment variables #######################################"
D=`grep 'fs.aio-max-nr' /etc/sysctl.conf`
if [ ! -n "${D}" ];then
cat << EOF >> /etc/sysctl.conf
kernel.shmmax = 68719476736
kernel.shmmni = 4096
kernel.shmall = 16777216
kernel.sem = 1010 129280 1010 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 4194304
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
fs.file-max = 6815744
EOF
/sbin/sysctl -p
else
    tail -11f /etc/sysctl.conf
fi
E=`grep 'oracle' /etc/security/limits.conf`
if [ ! -n "${E}" ];then
cat << EOF >> /etc/security/limits.conf
oracle soft nproc 16384
oracle hard nproc 16384
oracle soft nofile 65536
oracle hard nofile 65536
oracle soft memlock 4000000
oracle hard memlock 4000000
EOF
else
    tail -5f /etc/security/limits.conf
fi
F=`grep 'ORACLE_SID' /home/${ora_user}/.bash_profile`
if [ ! -n "${F}" ];then
cat << EOF >> /home/${ora_user}/.bash_profile
export ORACLE_SID=${ORACLE_SID}
export ORACLE_BASE=${ORACLE_BASE}
export ORACLE_HOME=${ORACLE_HOME}
export PATH=\$PATH:\$ORACLE_HOME/bin
EOF
else
    tail -4f /home/${ora_user}/.bash_profile
fi
G=`grep 'oracle' /etc/profile`
if [ ! -n "${G}" ];then
cat << EOF >> /etc/profile
if [ \$USER = "oracle" ];then
    if [ \$SHELL = "/bin/ksh" ];then
        ulimit -p 16384
        ulimit -n 65536
    else
        ulimit -u 16384 -n 65536
    fi
fi
EOF
else
    tail -8f /etc/profile
fi

###unzip the install package and set response file
echo "############################   unzip the install package  #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the zip file location(e.g:/opt/linuxamd64_12102_database_1of2.zip):" zfileone
    if [ ! -f ${zfileone} ];then
        echo "You input location not found zip file."
        count=$[${count}+1]
    else
        export zfileone=${zfileone}
        break
    fi
done
unzip ${zfileone} -d /${ora_dir}

count=0
while [ $count -lt 3 ]
do
    read -p "Please input the zip file location(e.g:/opt/linuxamd64_12102_database_2of2.zip):" zfiltwo
    if [ ! -f ${zfiltwo} ];then
        echo "You input location not found zip file."
        count=$[${count}+1]
    else
        export zfiltwo=${zfiltwo}
        break
    fi
done
unzip ${zfiltwo} -d /${ora_dir} && chown -R ${ora_user}:${ora_group[0]}  /${ora_dir} && chmod -R 775 /${ora_dir}

###set Oracle characterSet
echo "############################   set characterSet  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the CharacterSet(e.g:ZHS16GBK or AL32UTF8):" C1
        read -p "Please input the CharacterSet again(ZHS16GBK or AL32UTF8):" C2
        if [ "${C1}" == "${C2}" ];then
                export CharacterSet=${C1}
                break
        else        
                echo "You input characterSet not same."
                count=$[${count}+1]
        fi      
done

###set Oracle nationalCharacterSet
echo "############################   set nationalCharacterSet  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the NationalCharacterSet(e.g:AL16UTF16 or UTF8):" N1
        read -p "Please input the NationalCharacterSet again(AL16UTF16 or UTF8):" N2
        if [ "${N1}" == "${N2}" ];then
                export NationalCharacterSet=${N1}
                break
        else        
                echo "You input nationalCharacterSet not same."
                count=$[${count}+1]
        fi      
done

###set Oracle install.db.starterdb installSysPassword
echo "############################   set installSysPassword  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the installSysPassword(e.g:orcl20200202):" S1
        read -p "Please input the installSysPassword again(orcl20200202):" S2
        if [ "${S1}" == "${S2}" ];then
                export installSysPassword=${S1}
                break
        else        
                echo "You input installSysPassword not same."
                count=$[${count}+1]
        fi      
done

###set Response File
echo "############################   set ResponseFile  #######################################"
free_m=`free -m | grep 'Mem:'|awk '{print $2}'`
db_response_file=`find /${ora_dir} -type f -name db_install.rsp`
data_dir=${ORACLE_BASE}/data
recovery_dir=${ORACLE_BASE}/recovery
cd `find / -type f -name db_install.rsp | sed -n 's:/[^/]*$::p'` && cd ../
install_dir=`pwd`
sed -i "s!oracle.install.option=!oracle.install.option=INSTALL_DB_SWONLY!g" ${db_response_file}
sed -i "s!ORACLE_HOSTNAME=!ORACLE_HOSTNAME=${hostname}!g" ${db_response_file}
sed -i "s!UNIX_GROUP_NAME=!UNIX_GROUP_NAME=${ora_group[0]}!g" ${db_response_file}
sed -i "s!INVENTORY_LOCATION=!INVENTORY_LOCATION=${ORACLE_BASE}/oraInventory!g" ${db_response_file}
sed -i "s!SELECTED_LANGUAGES=en!SELECTED_LANGUAGES=en,zh_CN!g" ${db_response_file}
sed -i "s!ORACLE_HOME=!ORACLE_HOME=${ORACLE_HOME}!g" ${db_response_file}
sed -i "s!ORACLE_BASE=!ORACLE_BASE=${ORACLE_BASE}!g" ${db_response_file}
sed -i "s!oracle.install.db.InstallEdition=!oracle.install.db.InstallEdition=EE!g" ${db_response_file}
sed -i "s!oracle.install.db.DBA_GROUP=!oracle.install.db.DBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.OPER_GROUP=!oracle.install.db.OPER_GROUP=${ora_group[2]}!g" ${db_response_file}
sed -i "s!oracle.install.db.BACKUPDBA_GROUP=!oracle.install.db.BACKUPDBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.DGDBA_GROUP=!oracle.install.db.DGDBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.KMDBA_GROUP=!oracle.install.db.KMDBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.type=!oracle.install.db.config.starterdb.type=GENERAL_PURPOSE!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.globalDBName=!oracle.install.db.config.starterdb.globalDBName=${ORACLE_SID}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.SID=!oracle.install.db.config.starterdb.SID=${ORACLE_SID}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.characterSet=!oracle.install.db.config.starterdb.characterSet=${CharacterSet}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.memoryLimit=!oracle.install.db.config.starterdb.memoryLimit=$[free_m*8/10]!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.password.ALL=!oracle.install.db.config.starterdb.password.ALL=${installSysPassword}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.storageType=!oracle.install.db.config.starterdb.storageType=FILE_SYSTEM_STORAGE!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=!oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=${data_dir}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=!oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=${recovery_dir}!g" ${db_response_file}
sed -i "s!oracle.installer.autoupdates.option=!oracle.installer.autoupdates.option=SKIP_UPDATES!g" ${db_response_file}
sed -i "s/"^SECURITY_UPDATES_VIA_MYORACLESUPPORT=.*"/SECURITY_UPDATES_VIA_MYORACLESUPPORT=false/g" ${db_response_file}
sed -i "s/"^DECLINE_SECURITY_UPDATES=.*"/DECLINE_SECURITY_UPDATES=true/g" ${db_response_file}

###starting to install oracle software
echo "############################   Oracle Installing  #######################################"
oracle_out='/tmp/oracle.out'
touch ${oracle_out}
chown ${ora_user}:${ora_group[0]} ${oracle_out}
su - oracle -c "${install_dir}/runInstaller -silent -ignoreDiskWarning -ignoreSysPrereqs -ignorePrereq -responseFile ${db_response_file}" > ${oracle_out} 2>&1
echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle install starting \033[05m...\033[0m"
sleep 60
installActionslog=`find /tmp -name installActions*`
echo "You can check the oracle install log command: tail -100f ${installActionslog}"
while true; do
  grep '[FATAL] [INS-10101]' ${oracle_out} &> /dev/null
  if [[ $? == 0 ]];then
    echo -e "\033[34mInstallNotice >>\033[0m \033[31moracle start install has [ERROR]\033[0m"
    cat ${oracle_out}
    exit
  fi
  sleep 120
  cat /tmp/oracle.out  | grep sh
  if [[ $? == 0 ]];then
    `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' | head -1`
    if [[ $? == 0 ]]; then
      echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript orainstRoot.sh run successed\033[0m"
	  `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' | tail -1`
        if [[ $? == 0 ]];then
          echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript root.sh  run successed\033[0m"
	      break
        else
          echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript root.sh  run faild\033[0m"
        fi
    else
      echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript orainstRoot.sh run faild\033[0m"
    fi
  fi
done

echo "#######################   Oracle software 安装完成      ##############################"


# install listener && dbca
echo "############################   install oracle listener && dbca  #######################################"
echo "############################   set oracle schema sysPassword  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the SYSPASSWORD(e.g:orcl20200202):" S1
        read -p "Please input the SYSPASSWORD again(e.g:orcl20200202):" S2
        if [ "${S1}" == "${S2}" ];then
                export SYSPASSWORD=${S1}
                break
        else        
                echo "You input SYSPASSWORD not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set oracle app_user  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the USER_NAME(e.g:orcl):" S1
        read -p "Please input the USER_NAME again(e.g:orcl):" S2
        if [ "${S1}" == "${S2}" ];then
                export USER_NAME=${S1}
                break
        else        
                echo "You input USER_NAME not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set oracle app_passwd  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the USER_PASSWD(e.g:orcl2020):" S1
        read -p "Please input the USER_PASSWD again(e.g:orcl202):" S2
        if [ "${S1}" == "${S2}" ];then
                export USER_PASSWD=${S1}
                break
        else        
                echo "You input USER_PASSWD not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set app_user tmp_dbf  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the TMP_DBF(e.g:orcl_temp):" S1
        read -p "Please input the TMP_DBF again(e.g:orcl_temp):" S2
        if [ "${S1}" == "${S2}" ];then
                export TMP_DBF=${S1}
                break
        else        
                echo "You input TMP_DBF not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set app_user data_dbf  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the DATA_DBF(e.g:orcl_data):" S1
        read -p "Please input the DATA_DBF again(e.g:orcl_data):" S2
        if [ "${S1}" == "${S2}" ];then
                export DATA_DBF=${S1}
                break
        else        
                echo "You input DATA_DBF not same."
                count=$[${count}+1]
        fi      
done
ORACLE_SID=`su - oracle -c 'source ~/.bash_profile && echo $ORACLE_SID'`
ORACLE_BASE=`su - oracle -c 'source ~/.bash_profile && echo $ORACLE_BASE'`
ORACLE_HOME=`su - oracle -c 'source ~/.bash_profile && echo $ORACLE_HOME'`
ora_dir=`echo ${ORACLE_BASE}|awk -F '/' '{print $2}'`
DB_SHUT=${ORACLE_HOME}/bin/dbshut
DB_START=${ORACLE_HOME}/bin/dbstart
DATA_DIR=${ORACLE_BASE}/data
BACKUP_DIR=${ORACLE_BASE}/backup

[ ! -f $BACKUP_DIR ] && mkdir $BACKUP_DIR

CDB_SQL="
sqlplus / as sysdba << EOF
create temporary tablespace $TMP_DBF tempfile '$DATA_DIR/$ORACLE_SID/${TMP_DBF}.dbf' size 64m autoextend on next 64m maxsize unlimited extent management local;
create tablespace $DATA_DBF logging datafile '$DATA_DIR/$ORACLE_SID/${DATA_DBF}.dbf' size 64m autoextend on next 64m maxsize unlimited extent management local;
create user $USER_NAME identified by $USER_PASSWD default tablespace $DATA_DBF temporary tablespace $TMP_DBF;
grant connect,resource to $USER_NAME;
grant create view to $USER_NAME;
grant create public synonym to $USER_NAME;
grant drop public synonym to $USER_NAME;
grant unlimited tablespace to $USER_NAME;
create or replace directory dir_dump as '$BACKUP_DIR';
grant read,write on directory dir_dump to $USER_NAME;
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
alter system set processes=500 scope=spfile;
alter system set sessions=572 scope=spfile;
shutdown immediate;
startup mount;
alter database archivelog;
alter database open;
exit
EOF
"

temp=`ls ${ORACLE_BASE}|grep 'data'`
if [ ! -n ${temp} ];then
        mkdir ${ORACLE_BASE}/data
        export DATAFILE=${ORACLE_BASE}/data
else
        export DATAFILE=${ORACLE_BASE}/data
fi
temp=`ls ${ORACLE_BASE}|grep 'area'`
if [ ! -n ${temp} ];then
        mkdir ${ORACLE_BASE}/flash_recovery_area
        export RECOVERY=${ORACLE_BASE}/flash_recovery_area
else
        export RECOVERY=${ORACLE_BASE}/flash_recovery_area
fi
#NETCA=`find / -type f -name netca.rsp`
NETCA=`find /${ora_dir}/database -type f -name netca.rsp`
sed -i "s!INSTALL_TYPE=""typical""!INSTALL_TYPE=""custom""!g" ${NETCA}
#MEM=$(grep -r 'MemTotal' /proc/meminfo | awk -F ' ' '{print int($2/1024/1024+1)}')
MEM=`free -m|grep 'Mem:'|awk '{print $2}'`
TOTAL=$[MEM*8/10]

###set listener&tnsnames
echo "############################   Oracle listener&dbca  #######################################"
su - oracle << EOF
source ~/.bash_profile
${ORACLE_HOME}/bin/netca -silent -responsefile ${NETCA}
dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbname ${ORACLE_SID} -sid ${ORACLE_SID} -sysPassword ${SYSPASSWORD} -systemPassword ${SYSPASSWORD} -responseFile NO_VALUE -datafileDestination ${DATAFILE} -redoLogFileSize 1000 -recoveryAreaDestination ${RECOVERY} -storageType FS -characterSet ${CharacterSet} -nationalCharacterSet ${NationalCharacterSet} -sampleSchema false -memoryPercentage 80 -totalMemory $TOTAL -databaseType OLTP -emConfiguration NONE
EOF

sed -i "s!${ORACLE_SID}:${ORACLE_HOME}:N!${ORACLE_SID}:${ORACLE_HOME}:Y!g" /etc/oratab

AUTO_START_CONFIG=`cat /etc/oratab|grep ${ORACLE_SID} |awk -F ':' '{print $NF}'`
AUTO_START_CONFIG_expected='Y'

if [ ${AUTO_START_CONFIG} = ${AUTO_START_CONFIG_expected} ];then
    echo "AUTO_START_CONFIG successed!"
else
    echo "AUTO_START_CONFIG failed!"
	exit 1
fi

#set oracle to use dbstart & dbshut to control the dbsoftware
sed -i "s/ORACLE_HOME_LISTNER=\$1/ORACLE_HOME_LISTNER=\$ORACLE_HOME/g" ${DB_SHUT}

sed -i "s/ORACLE_HOME_LISTNER=\$1/ORACLE_HOME_LISTNER=\$ORACLE_HOME/g" ${DB_START}

#set oracle start&stop sys_service
echo "############################   Oracle sys_service  #######################################"
su - oracle -c "touch /home/oracle/oracle"
cat >/etc/init.d/oracle <<EOF
#!/bin/sh
# chkconfig: 35 80 10
# description: Oracle auto start-stop script.
# Set ORACLE_HOME to be equivalent to the \$ORACLE_HOME
# Oracle database in ORACLE_HOME.
LOGFILE=/home/oracle/oracle
ORACLE_HOME=$ORACLE_HOME
ORACLE_OWNER=oracle
LOCK_FILE=/var/lock/subsys/oracle
if [ ! -f $ORACLE_HOME/bin/dbstart ]
then
    echo "Oracle startup: cannot start"
    exit
fi
case "\$1" in
'start')
# Start the Oracle databases:
echo "Starting Oracle Databases ... "
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Starting Oracle Databases as part of system up." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
su - \$ORACLE_OWNER -c "\$ORACLE_HOME/bin/dbstart" >> \${LOGFILE}
echo "Done"

# Start the Listener:
echo "Starting Oracle Listeners ... "
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Starting Oracle Listeners as part of system up." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
su - \$ORACLE_OWNER -c "\$ORACLE_HOME/bin/lsnrctl start" >> \${LOGFILE}
echo "Done."
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Finished." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
touch \$LOCK_FILE
;;

'stop')
# Stop the Oracle Listener:
echo "Stoping Oracle Listeners ... "
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Stoping Oracle Listener as part of system down." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
su - \$ORACLE_OWNER -c "\$ORACLE_HOME/bin/lsnrctl stop" >> \${LOGFILE}
echo "Done."
rm -f \$LOCK_FILE

# Stop the Oracle Database:
echo "Stoping Oracle Databases ... "
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Stoping Oracle Databases as part of system down." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
su - \$ORACLE_OWNER -c "\$ORACLE_HOME/bin/dbshut" >> \${LOGFILE}
echo "Done."
echo ""
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Finished." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
;;

'restart')
\$0 stop
\$0 start
;;
esac
EOF
#set privileges
chmod +x /etc/init.d/oracle
chkconfig oracle on
# check oracle service
service oracle start
if [ $? -ne 0 ];then
  action "oracle service start failed." /bin/false
  exit 2
fi

service oracle stop
if [ $? -ne 0 ];then
  action "oracle service stop failed." /bin/false
  exit 3
fi

service oracle restart
if [ $? -ne 0 ];then
  action "oracle service restart failed." /bin/false
  exit 4
fi

#set create app_user & app_passwd
echo "############################   Oracle sys_service  #######################################"
su - oracle -c "${CDB_SQL}"
if [ $? -eq 0 ];then
  echo -e "\e[30 CDB_SQL execute successed & restart the oracle_service \e[0m"
  service oracle restart
else
  action "oracle create app_user && app_passwd failed." /bin/false
  exit 5
fi

echo "####################### oracle listener && dbca  安装完成 请记录数据库信息      ##############################"

echo "#####   oracle用户系统登录密码:      #####"
echo -e "\e[31;47;5m $ORACLE_OS_PWD \e[0m"

echo "#####   数据库实例名:      #####"
echo -e "\e[30;47;5m $ORACLE_SID \e[0m"

echo "#####   数据库install.db.starterdb密码:      #####"
echo -e "\e[31;47;5m $installSysPassword \e[0m"

echo "#####   数据库实例的sys管理用户密码:      #####"
echo -e "\e[30;47;5m $SYSPASSWORD \e[0m"

echo "#####   数据库应用连接用户名:      #####"
echo -e "\e[31;47;5m $USER_NAME \e[0m"

echo "#####   数据库应用连接用户名对应的密码:      #####"
echo -e "\e[30;47;5m $USER_PASSWD \e[0m"

echo "#####   数据库临时表空间名:      #####"
echo -e "\e[31;47;5m $TMP_DBF \e[0m"

echo "#####   数据库数据表空间名:      #####"
echo -e "\e[30;47;5m $DATA_DBF \e[0m"
