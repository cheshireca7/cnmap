#!/bin/bash

greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

function ctrl_c(){
	echo -ne "\n\n$redColour[!]$endColour Keyboard interrupt received, exiting ...\n"
	tput cnorm
	rm -f "$(pwd)/targets.txt" "$(pwd)"/*/log/?ports.txt "$(pwd)/discovery.txt"
	exit -1
}

function TCP(){
		echo -ne "\t$greenColour[$HOST]$endColour TCP open ports:" $(nmap -Pn -n --disable-arp-ping -vv -T4 --min-rate 3000 $HOST -p- -oA "$(pwd)/log/tcp-openports" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; tPORTS=$(grep -oP "\d+/tcp" "$(pwd)/log/tcp-openports.nmap" | awk -F/ '{print $1}' | xargs | sed 's/ /,/g' | tee "$(pwd)/log/tports.txt"); if [[ ! -e $tPORTS ]];then echo -e " $yellowColour$tPORTS$endColour"; else echo -ne "$redColour NONE$endColour"; rm "$(pwd)/log/"tcp-openports.* "$(pwd)/log/tports.txt" &>/dev/null; fi); echo
	tPORTS="$(cat "$(pwd)/log/tports.txt" 2>/dev/null)"
	IFS=',' read -r -a atPORTS <<< "$tPORTS"
	for p in "${atPORTS[@]}"; do 
		if [[ `curl -sIkm 3 "http://$HOST:$p" | grep HTTP` != "" || `curl -sIkm 3 "https://$HOST:$p" | grep HTTP` != "" ]];then 
			http_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing HTTP enumeration. Results will be stored at $grayColour'file://$(pwd)/log/http-enum-$p.xml'$endColour"
		fi
		if [[ "$p" == "445" ]];then
			smb_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing SMB enumeration. Results will be stored at $grayColour'file://$(pwd)/log/smb-enum.xml'$endColour"
		fi
		if [[ "$p" == "111" ]];then
			rpc_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing RPC enumeration. Results will be stored at $grayColour'file://$(pwd)/log/rpc-enum.xml'$endColour"
		fi
		if [[ "$p" == "25" ]];then
			smtp_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing SMTP enumeration. Results will be stored at $grayColour'file://$(pwd)/log/smtp-enum.xml'$endColour"
		fi
		if [[ "$p" == "3306" ]];then
			mysql_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing MySQL enumeration. Results will be stored at $grayColour'file://$(pwd)/log/mysql-enum.xml'$endColour"
		fi
		if [[ "$p" == "53" ]];then
			dns_enum $p &
		fi
		if [[ "$p" == "2049" ]];then
			nfs_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing NFS enumeration. Results will be stored at $grayColour'file://$(pwd)/log/nfs-enum.xml'$endColour"
		fi
		if [[ "$p" == "1433" ]];then
			mssql_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing MSSQL enumeration. Results will be stored at $grayColour'file://$(pwd)/log/mssql-enum.xml'$endColour"
		fi
		if [[ "$p" == "1521" ]];then
			oracle_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing ORACLE enumeration. Results will be stored at $grayColour'file://$(pwd)/log/oracle-enum.xml'$endColour"
		fi
		if [[ "$p" == "3389" ]];then
			rdp_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing RDP enumeration. Results will be stored at $grayColour'file://$(pwd)/log/rdp-enum.xml'$endColour"
		fi
		if [[ "$p" == "5900" ]];then
			vnc_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing VNC enumeration. Results will be stored at $grayColour'file://$(pwd)/log/vnc-enum.xml'$endColour"
		fi
	done 
	if [[ -f "$(pwd)/log/tcp-openports.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour TCP scan stored at $grayColour'file://$(pwd)/log/tcp-openports.xml'$endColour"; fi
	
}

function UDP(){
	echo -ne "\t$blueColour[$HOST]$endColour UDP open ports:" $(nmap -Pn -n --disable-arp-ping -vv -sU $HOST -oA "$(pwd)/log/udp-openports" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; uPORTS=$(grep -oP "\d+/udp" "$(pwd)/log/udp-openports.nmap" | awk -F/ '{print $1}' | xargs | sed 's/ /,/g' | tee "$(pwd)/log/uports.txt"); if [ ! -e $uPORTS ];then echo -e " $yellowColour$uPORTS$endColour"; else echo -e "$redColour NONE$endColour"; rm "$(pwd)/log/"udp-openports.* "$(pwd)/log/uports.txt" &>/dev/null; fi); echo
	snmp_enum &
	echo -e "\t$blueColour[$HOST:161]$endColour Performing SNMP enumeration. Results will be stored at $grayColour'file://$(pwd)/log/snmp-enum.xml'$endColour"
	tftp_enum &
	echo -e "\t$blueColour[$HOST:69]$endColour Performing TFTP enumeration. Results will be stored at $grayColour'file://$(pwd)/log/tftp-enum.xml'$endColour"
	if [[ -f "$(pwd)/log/udp-openports.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour UDP scan stored at $grayColour'file://$(pwd)/log/udp-openports.xml'$endColour"; fi
}

function services(){
	ports_path="$(pwd)/log"

	if [[ -f "$ports_path/tports.txt" ]];then
		tPORTS=$(cat "$(pwd)/log/tports.txt" 2>/dev/null)
		echo -ne "\t$blueColour[$HOST]$endColour Scanning TCP open ports ..." $(nmap -Pn -n --disable-arp-ping -vv -T4 --min-rate 3000 $HOST -p$tPORTS -sCV --script ssl-enum-ciphers --version-all --version-intensity 5 --script "+vuln and safe" -oA "$(pwd)/log/tcp-services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null);
		if [[ -f "$(pwd)/log/tcp-services.xml" ]];then 
			echo -e "$greenColour Done$endColour"
			echo -e "\t$greenColour[$HOST]$endColour TCP Services scan stored at $grayColour'file://$(pwd)/log/tcp-services.xml$endColour'"
		else
			echo -e "$greenColour FAILED$endColour"
		fi
		rm -f "$(pwd)/log/tports.txt" &>/dev/null
	elif [[ -f "$ports_path/uports.txt" ]];then
		uPORTS=$(cat "$(pwd)/log/uports.txt" 2>/dev/null)
		echo -ne "\t$blueColour[$HOST]$endColour Scanning UDP open ports ..." $(nmap -Pn -n --disable-arp-ping -vv -sCUV $HOST -p$uPORTS --version-all --script "+vuln and safe" -oA "$(pwd)/log/udp-services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; echo -e "$greenColour Done$endColour"); echo
		if [[ -f "$(pwd)/log/udp-services.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour UDP Services scan stored at $grayColour'file://$(pwd)/log/udp-services.xml$grayColour'"; fi
		rm -f "$(pwd)/log/uports.txt" &>/dev/null
	else	
		echo -e "\t$redColour[$HOST]$endColour No ports open, aborting service scan"
	fi

	echo
}

function rdp_enum(){
	nmap -p$1 --script 'rdp-*' $HOST -oX "$(pwd)/log/rdp-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function rpc_enum(){
	nmap -p$1 --script 'rpcinfo,rpc-grind' $HOST -oX "$(pwd)/log/rpc-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function vnc_enum(){
	nmap -p$1 --script 'vnc-info,realvnc-auth-bypass' $HOST -oX "$(pwd)/log/vnc-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function oracle_enum(){
	nmap -p$1 --script 'oracle-sid-brute,oracle-tns-version' $HOST -oX "$(pwd)/log/oracle-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function snmp_enum(){
	nmap -sU -p161 --script 'snmp-*' $HOST -oX "$(pwd)/log/snmp-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function tftp_enum(){
	nmap -sU -p69 --script 'tftp-enum' $HOST -oX "$(pwd)/log/tftp-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function nfs_enum(){
	nmap -p111,$1 --script 'nfs-*' $HOST -oX "$(pwd)/log/nfs-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function http_enum(){
	nmap -p$1 --script 'http-enum,http-config-backup,http-vhosts,http-drupal-enum,http-wordpress-enum' $HOST -oX "$(pwd)/log/http-enum-$1.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function smb_enum(){
	nmap -p$1 --script 'smb-enum-*,smb-os-discovery,smb-system-info,smb-vuln-*' $HOST -oX "$(pwd)/log/smb-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function smtp_enum(){
	nmap -p$1 --script 'smtp-enum-users,smtp-vuln-*' $HOST -oX "$(pwd)/log/smtp-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}
function dns_enum(){
	domain=$(nmap -Pn -n --disable-arp-ping -p445 $HOST --script smb-os-discovery 2>/dev/null | grep 'Domain name' | awk -F: '{print $NF}' | tr -d ' ')
	if [[ "$domain" == "" ]];then
		domain=$(nmap -Pn -n --disable-arp-ping -p445 $HOST --script smb-os-discovery 2>/dev/null | grep 'Computer name' | awk -F: '{print $NF}' | tr -d ' ')
	fi
	if [[ "$domain" != "" ]];then
		echo -e "\t$blueColour[$HOST:$1]$endColour Performing DNS enumeration. Results will be stored at $grayColour'file://$(pwd)/log/dns-enum.xml'$endColour"
		nmap -Pn -n --disable-arp-ping -p53 $HOST --script dns-zone-transfer,dns-cache-snoop --script-args server=$HOST,domain=$domain -oX "$(pwd)/log/dns-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
	fi
}

function mysql_enum(){
	nmap -Pn -n --disable-arp-ping -p$1 $HOST --script 'mysql-enum,mysql-users,mysql-databases,mysql-dump-hashes,mysql-variables' -oX "$(pwd)/log/mysql-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null
}

function mssql_enum(){
	nmap -p$1 --script 'ms-sql-empty-password,ms-sql-info' $HOST -oX "$(pwd)/log/mssql-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

HOST=$1

echo $HOST | grep -oP "^(\d{1,3}\.){3}\d{1,3}(\/\d{1,2})?$" &>/dev/null 
if [ $? -ne 0 ];then echo -e "\n$redColour[!]$endColour Usage: $0 <OPTIONS> target"; tput cnorm; exit 0; fi

tput civis

echo -ne "\n$blueColour[*]$endColour Updating NSE database ..."
nmap --script-update &>/dev/null
echo -e "$greenColour Done$endColour"
echo "${HOST:(-3)}" | grep -oP "\/\d{1,2}" &>/dev/null
if [[ $? -eq 0 ]];then
	echo -e "\n$blueColour[*]$endColour Discovery scan started\n"
	echo -ne "\t$greenColour[$HOST]$endColour Alive hosts: "

	nmap -sn -n -PS20,21,22,23,25,53,80,110,111,143,135,139,443,445,1433,1521,2049,3306,3389,5432,5900,8000,8080,8443 -PU53,67,68,69,111,123,161,500,4500,5353 $HOST -oN "$(pwd)/discovery.nmap" &>/dev/null
	grep "Nmap scan report" "$(pwd)/discovery.nmap" | awk '{print $NF}' > "$(pwd)/discovery.txt"
	hostname -I | sed 's/ /\n/g' | grep -v 'fd15' > "$(pwd)/current.txt"
	diff -u "$(pwd)/discovery.txt" "$(pwd)/current.txt" | grep -oP "\-.\d{1,3}\..*" | tr -d '-' > "$(pwd)/targets.txt"
	rm -f "$(pwd)/discovery.txt" "$(pwd)/current.txt"
	if [[ "$(wc -l "$(pwd)"'/targets.txt' | awk '{print $1}')" == "0" ]];then echo -e "$redColour NONE$endColour"; exit 0; fi
	echo -e "$yellowColour$(cat "$(pwd)/targets.txt" | xargs | sed 's/ /, /g')$endColour"
	
	echo -e "\n$blueColour[*]$endColour TCP scan started\n"
	while read line; do 
		if [ ! -d "$(pwd)/$line/log" ]; then mkdir -p "$(pwd)/$line/log"; fi
		(HOST=$line; cd $HOST; TCP; echo) &
	done < "$(pwd)/targets.txt"

	wait
	echo -e "\n$blueColour[*]$endColour TCP Service scan started\n"
	while read line; do 
		(HOST=$line; cd $HOST; services; echo) &
	done < "$(pwd)/targets.txt"

	wait
	echo -e "\n$blueColour[*]$endColour UDP scan started\n"
	while read line; do 
		(HOST=$line; cd $HOST; UDP; echo) &
	done < "$(pwd)/targets.txt"

	wait
	echo -e "$blueColour[*]$endColour UDP Service scan started\n"
	while read line; do 
		(HOST=$line; cd $HOST; services; echo) &
	done < "$(pwd)/targets.txt"

	wait
	rm -f "$(pwd)/targets.txt" &>/dev/null
else
	if [ ! -d "$(pwd)/log" ]; then mkdir "$(pwd)/log" 2>/dev/null; fi
	echo -e "\n$blueColour[*]$endColour TCP scan started\n"
	TCP
	echo -e "\n$blueColour[*]$endColour TCP Service scan started\n"
	services
	echo -e "$blueColour[*]$endColour UDP scan started\n"
	UDP
	echo -e "\n$blueColour[*]$endColour UDP Service scan started\n"
	services
fi

tput cnorm
