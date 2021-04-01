#!/bin/bash

greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

function ctrl_c(){
	echo -ne "\n$redColour[!]$endColour Keyboard interrupt received, exiting ...\n"
	tput cnorm
	rm -f "$(pwd)/targets.txt" "$(pwd)/*/log/?ports.txt" "$(pwd)/discovery.txt"
	pkill cnmap &>/dev/null
}

function TCP(){
	echo -ne "\t$greenColour[$HOST]$endColour TCP open ports:" $(nmap -Pn -n --disable-arp-ping --open -vv -T4 --min-rate 3000 $HOST -p- -oA "$(pwd)/log/TCP-openports" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; tPORTS=$(grep -oP "\d+/tcp" "$(pwd)/log/TCP-openports.nmap" | awk -F/ '{print $1}' | xargs | sed 's/ /,/g' | tee "$(pwd)/log/tports.txt"); if [ ! -e $tPORTS ];then echo -e " $yellowColour$tPORTS$endColour"; else echo -ne "$redColour NONE$endColour"; rm "$(pwd)/log/"TCP-openports.*; fi); echo
	tPORTS="$(cat "$(pwd)/log/tports.txt")"
	IFS=',' read -r -a atPORTS <<< "$tPORTS"
	for p in "${atPORTS[@]}"; do 
		if [[ `curl -sIkm 1 "http://$HOST:$p" | grep HTTP` != "" || `curl -sIkm 1 "https://$HOST:$p" | grep HTTP` != "" ]];then 
			http_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing HTTP enumeration. Results will be stored at $grayColour'file://$(pwd)/log/http-enum-$p.xml'$endColour"
		fi
		if [[ "$p" == "445" ]];then
			smb_enum $p &
			echo -e "\t$blueColour[$HOST:$p]$endColour Performing SMB enumeration. Results will be stored at $grayColour'file://$(pwd)/log/smb-enum.xml'$endColour"
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
	done 
	if [[ -f "$(pwd)/log/TCP-openports.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour TCP scan stored at $grayColour'file://$(pwd)/log/TCP-openports.xml'$endColour"; fi
	
}

function UDP(){
	echo -ne "\t$blueColour[$HOST]$endColour UDP open ports:" $(nmap -Pn -n --disable-arp-ping --open -vv -sU $HOST --max-scan-delay 500ms --max-rtt-timeout 300ms --max-retries 1 -oA "$(pwd)/log/udp-openports" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; uPORTS=$(grep -oP "\d+/udp" "$(pwd)/log/udp-openports.nmap" | awk -F/ '{print $1}' | xargs | sed 's/ /,/g' | tee "$(pwd)/log/uports.txt"); if [ ! -e $uPORTS ];then echo -e " $yellowColour$uPORTS$endColour"; else echo -e "$redColour NONE$endColour"; rm "$(pwd)/log/"udp-openports.*; fi); echo
	if [[ -f "$(pwd)/log/udp-openports.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour UDP scan stored at $grayColour'file://$(pwd)/log/udp-openports.xml'$endColour"; fi
}

function services(){
	ports_path="$(pwd)/log"

	if [[ -f "$ports_path/tports.txt" && ! -z "$(cat $ports_path/tports.txt)" ]];then
		tPORTS=$(cat "$(pwd)/log/tports.txt" 2>/dev/null)
		echo -ne "\t$blueColour[$HOST]$endColour Scanning TCP open ports ..." $(nmap -Pn -n --disable-arp-ping -vv -T4 --min-rate 3000 $HOST -p$tPORTS -sCV --version-all --script "+vuln and safe" --script=vulscan/vulscan.nse --script-args "vulscanshowall=0,vulscanoutput='{title} - {link}\n'" -oA "$(pwd)/log/tcp-services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null);
		if [[ -f "$(pwd)/log/tcp-services.xml" ]];then 
			echo -e "$greenColour DONE$endColour"
			echo -e "\t$greenColour[$HOST]$endColour TCP Services scan stored at $grayColour'file://$(pwd)/log/tcp-services.xml$endColour'"
		else
			echo -e "$greenColour FAILED$endColour"
		fi
		rm -f "$(pwd)/log/tports.txt" &>/dev/null
	elif [[ -f "$ports_path/uports.txt" && ! -z "$(cat $ports_path/uports.txt)" ]];then
		uPORTS=$(cat "$(pwd)/log/uports.txt" 2>/dev/null)
		echo -ne "\t$blueColour[$HOST]$endColour Scanning UDP open ports ..." $(nmap -Pn -n --disable-arp-ping -vv -sCUV $HOST -p$uPORTS --version-all --script "+vuln and safe" -oA "$(pwd)/log/udp-services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; echo -e "$greenColour Done$endColour"); echo
		if [[ -f "$(pwd)/log/udp-services.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour UDP Services scan stored at $grayColour'file://$(pwd)/log/udp-services.xml$grayColour'"; fi
		rm -f "$(pwd)/log/uports.txt" &>/dev/null
	else	
		echo -e "\t$redColour[$HOST]$endColour No ports open, aborting service scan"
	fi

	echo
}

function http_enum(){
	nmap -p$1 --script http-enum $HOST -oX "$(pwd)/log/http-enum-$1.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function smb_enum(){
	nmap -p$1 --script 'smb-enum-*' $HOST -oX "$(pwd)/log/smb-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}

function smtp_enum(){
	nmap -p$1 --script 'smtp-enum-users' $HOST -oX "$(pwd)/log/smtp-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
}
function dns_enum(){
	domain=$(nmap -Pn -n --disable-arp-ping -p445 $HOST -script smb-os-discovery 2>/dev/null | grep 'Domain name' | awk -F: '{print $NF}' | tr -d ' ')
	if [[ "$domain" == "" ]];then
		domain=$(nmap -Pn -n --disable-arp-ping -p445 $HOST -script smb-os-discovery 2>/dev/null | grep 'Computer name' | awk -F: '{print $NF}' | tr -d ' ')
	fi
	if [[ "$domain" != "" ]];then
		echo -e "\t$blueColour[$HOST:$1]$endColour Performing DNS enumeration. Results will be stored at $grayColour'file://$(pwd)/log/dns-enum.xml'$endColour"
		nmap -Pn -n --disable-arp-ping -p53 $HOST --script dns-zone-transfer --script-args server=$HOST,domain=$domain -oX "$(pwd)/log/dns-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
	fi
}

function mysql_enum(){
	for pass in ['' 'root' 'toor']; do
		mysql -h $HOST -u 'root' --password="$pass" -e "SELECT user()" &>/dev/null
		if [ $? -eq 0 ]; then 
			nmap -Pn -n --disable-arp-ping -p3306 192.168.0.57 --script mysql-users,mysql-databases,mysql-dump-hashes,mysql-variables --script-args 'mysqluser=root,mysqlpass='$pass',username=root,password='$pass -oX "$(pwd)/log/mysql-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
&>/dev/null
		else
			nmap -p$1 --script 'mysql-enum' $HOST -oX "$(pwd)/log/mysql-enum.xml" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null 
		fi
	done
}

function banner(){
	echo "banner"
}

#banner

HOST=$1

echo $HOST | grep -oP "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\/\d{1,2})?$" &>/dev/null 
if [ $? -ne 0 ];then echo -e "\n$redColour[!]$endColour Usage: $0 <OPTIONS> target"; tput cnorm; exit 0; fi

tput civis

echo -ne "\n$blueColour[*]$endColour Updating Vulscan database ..."
rm /usr/share/nmap/scripts/vulscan/exploitdb.csv &>/dev/null
wget -q https://www.computec.ch/projekte/vulscan/download/exploitdb.csv -O /usr/share/nmap/scripts/vulscan/exploitdb.csv &>/dev/null
nmap --script-update &>/dev/null
echo -e "$greenColour Done$endColour"
echo "${HOST:(-3)}" | grep -oP "\/\d{1,2}" &>/dev/null
if [[ $? -eq 0 ]];then

	echo -e "\n$blueColour[*]$endColour Discovery scan started\n"
	echo -ne "\t$greenColour[$HOST]$endColour Alive hosts: "

	nmap -sn -n -PS20,21,22,23,25,53,80,110,143,135,139,443,445,1433,3306,3389,8080,8443 -PU53,67,68,69,111,123,161,500,4500,5353 $HOST -oN "$(pwd)/discovery.nmap" &>/dev/null
	grep "Nmap scan report" "$(pwd)/discovery.nmap" | awk '{print $NF}' > "$(pwd)/discovery.txt"
	hostname -I | sed 's/ /\n/g' | grep -v 'fd15' > "$(pwd)/current.txt"
	diff -u "$(pwd)/discovery.txt" "$(pwd)/current.txt" | grep -oP "\-.\d{1,3}\..*" | tr -d '-' > "$(pwd)/targets.txt"
	rm -f "$(pwd)/discovery.txt" "$(pwd)/current.txt"
	if [[ "$(wc -l "$(pwd)"'/targets.txt' | awk '{print $1}')" == "0" ]];then echo -e "$redColour NONE$endColour"; exit 0; fi
	echo -e "$yellowColour$(cat "$(pwd)/targets.txt" | xargs | sed 's/ /, /g')$endColour"
	
	echo -e "\n$blueColour[*]$endColour TCP scan started\n"
	while read line; do 
		if [ ! -d "$(pwd)/$line" ]; then mkdir -p "$(pwd)/$line/"{exploits,log,loot,tools}; fi
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
	echo -e "\n$blueColour[*]$endColour UDP Service scan started\n"
	while read line; do 
		(HOST=$line; cd $HOST; services; echo) &
	done < "$(pwd)/targets.txt"

	wait
	rm -f "$(pwd)/targets.txt" &>/dev/null
else
	if [ ! -d "$(pwd)/log" ]; then mkdir "$(pwd)/"{exploits,log,loot,tools} 2>/dev/null; fi
	echo -e "\n$blueColour[*]$endColour TCP scan started\n"
	TCP
	echo -e "\n$blueColour[*]$endColour TCP Service scan started\n"
	services
	echo -e "\n$blueColour[*]$endColour UDP scan started\n"
	UDP
	echo -e "\n$blueColour[*]$endColour UDP Service scan started\n"
	services
fi

tput cnorm
