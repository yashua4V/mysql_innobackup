function get_db_back_info(){
        conf_path="/usr/local/etc/zabbix_agentd.conf.d/zabbix_diy/localhost.conf/db_backXtra.conf"
	find_row=`sed -n "/^$1/p" $conf_path`
        echo ${find_row##*=}
}

