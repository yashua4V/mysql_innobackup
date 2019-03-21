#!/bin/bash
#获取本地数据库信息
source /usr/local/etc/zabbix_agentd.conf.d/zabbix_diy/script/conf_script/get_db_backXtra_info.sh
#备份保存路径 
backup_dir=`get_db_back_info backup_dir`
#增量备份保存路径 
backup_incrdir=`get_db_back_info backup_incrdir`
#当前时间日期
Now=$(date +"%Y-%m-%d_%H-%M-%S")
#mysql备份数据库内网ip
IP=`get_db_back_info IP`
#mysql端口
Port=`get_db_back_info Port`
#mysql用户名
User=`get_db_back_info User`
#mysql密码
Pass=`get_db_back_info Pass`
#mysql数据库库名
DbName=`get_db_back_info DbName`
#项目代号
PName=`get_db_back_info PName`
#FTP账号
FtpAccount=`get_db_back_info FtpAccount`
#FTP密码
FtpPass=`get_db_back_info FtpPass`
#备份是否启用
Status=`get_db_back_info Status`


if [ $Status -eq 0 ];then
     echo "当前未启用数据备份"
     exit
fi


#下面的配置无需修改
#执行备份
#检查客户端是否安装ftp，没有安装就安装
rpm -q ftp   ||  yum install -y  ftp
[ -d $backup_dir ] || mkdir -p  $backup_dir

#mysqldump -h$IP -P$Port -u$User -p$Pass --quick --routines --single-transaction --databases $DbName | gzip > $backup_dir/${PName}_bak_$Now.sql.gz
rm -rf  $backup_incrdir/* && rm -rf $backup_dir/mysql #每天第一次做完全备份时清空增量备份文件夹里的文件
innobackupex --user=$User --password=$Pass --databases=$DbName $backup_dir/mysql  --no-timestamp

tar -czf backup_dir/mysql $backup_dir/${PName}_fullbak_$Now.sql.gz
if [ $? -eq 0  ]
then
    echo "恭喜你,${PName}_fullbak_${Now}.sql.gz--数据包已经生成"
else
    curl -k "http://103.72.147.80:5000/telegram?q=%E5%B0%8Fzha%E6%B8%A9%E9%A6%A8%E6%8F%90%E7%A4%BA%0A%0A%E5%B9%B3%E5%8F%B0:%20${PName}%0A%E9%97%AE%E9%A2%98:%20%E6%95%B0%E6%8D%AE%E5%BA%93%E5%A4%87%E4%BB%BD%E5%A4%B1%E8%B4%A5,%E6%95%B0%E6%8D%AE%E5%8C%85%E7%94%9F%E6%88%90%E5%A4%B1%E8%B4%A5%EF%BC%81%EF%BC%81%0A%E6%8F%90%E7%A4%BA:%20%E5%8F%AF%E8%83%BD%E5%9B%A0%E4%B8%BA%E6%95%B0%E6%8D%AE%E5%BA%93%E4%BF%A1%E6%81%AF%E9%94%99%E8%AF%AF%E5%AF%BC%E8%87%B4%E6%97%A0%E6%B3%95%E8%8E%B7%E5%8F%96%E6%95%B0%E6%8D%AE%E5%BA%93%E6%95%B0%E6%8D%AE"
    echo "${PName}_fullbak_${Now}.sql.gz--完全备份数据包生成失败" && rm -rf $backup_dir/${PName}_fullbak_$Now.sql.gz  &&  exit
fi
echo 启动远程上传
echo 尝试开始上传
echo 连线正常
echo 正在上传...

#数据库备份节点-A区
PUTFILE=${PName}_fullbak_$Now.sql.gz
ftp -v -n 128.1.134.118 > $backup_dir/ftp.log  <<EOF
user $FtpAccount $FtpPass
binary
cd ./
lcd $backup_dir
put $PUTFILE
prompt
bye
EOF
cat $backup_dir/ftp.log | grep   'Logged on'
if [ $? -eq 0  ]
then
	echo "${PUTFILE}A区节点-上传成功"
else
	echo "${PUTFILE}A区节点-上传失败"
	curl -k "http://103.72.147.80:5000/telegram?q=%E5%B0%8Fzha%E6%B8%A9%E9%A6%A8%E6%8F%90%E7%A4%BA%0A%0A%E5%B9%B3%E5%8F%B0:%20${PName}%0A%E9%97%AE%E9%A2%98:%20%E6%95%B0%E6%8D%AE%E5%BA%93%E5%A4%87%E4%BB%BD%E5%A4%B1%E8%B4%A5,A%E5%8C%BA%E7%99%BB%E9%99%86%E5%A4%B1%E8%B4%A5%EF%BC%81%EF%BC%81%0A%E6%8F%90%E7%A4%BA:%20%E5%8F%AF%E8%83%BD%E5%9B%A0%E4%B8%BAftp%E8%B4%A6%E5%8F%B7%E6%88%96%E8%80%85%E5%AF%86%E7%A0%81%E9%94%99%E8%AF%AF%E5%AF%BC%E8%87%B4%E6%97%A0%E6%B3%95%E7%99%BB%E9%99%86ftp"
	rm -rf $backup_dir/${PName}_fullbak_$Now.sql.gz && echo "数据包删除成功"
	exit
fi

#数据库备份节点-B区
ftp -v -n 128.1.138.50 > $backup_dir/ftp1.log <<EOF
user $FtpAccount $FtpPass
binary
cd ./
lcd $backup_dir
put $PUTFILE
prompt
bye
EOF

cat $backup_dir/ftp.log | grep   'Logged on'
if [ $? -eq 0  ]
then
	echo "${PUTFILE}B区节点-上传成功"
else
	echo "${PUTFILE}B区节点-上传失败"
	curl -k "http://103.72.147.80:5000/telegram?q=%E5%B0%8Fzha%E6%B8%A9%E9%A6%A8%E6%8F%90%E7%A4%BA%0A%0A%E5%B9%B3%E5%8F%B0:%20${PName}%0A%E9%97%AE%E9%A2%98:%20%E6%95%B0%E6%8D%AE%E5%BA%93%E5%A4%87%E4%BB%BD%E5%A4%B1%E8%B4%A5,B%E5%8C%BA%E7%99%BB%E9%99%86%E5%A4%B1%E8%B4%A5%EF%BC%81%EF%BC%81%0A%E6%8F%90%E7%A4%BA:%20%E5%8F%AF%E8%83%BD%E5%9B%A0%E4%B8%BAB%E5%8C%BA%E8%8A%82%E7%82%B9ftp%E8%B4%A6%E5%8F%B7%E6%88%96%E8%80%85%E5%AF%86%E7%A0%81%E9%94%99%E8%AF%AF%E5%AF%BC%E8%87%B4%E6%97%A0%E6%B3%95%E7%99%BB%E9%99%86ftp,%E7%9B%AE%E5%89%8DA%E5%8C%BA%E6%AD%A3%E5%B8%B8"
	rm -rf $backup_dir/${PName}_fullbak_$Now.sql.gz && echo "数据包删除成功"
fi
rm -rf $backup_dir/${PName}_fullbak_$Now.sql.gz && rm -rf $backup_dir/mysql  && echo 临时文件删除成功!
echo 备份程序已完成!

