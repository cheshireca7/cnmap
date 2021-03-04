#!/bin/bash

greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"

trap ctrl_c INT

function ctrl_c(){
	echo -ne "$redColour[!]$endColour Keyboard interrupt received, exiting"
	pkill nmap 2>&1 > /dev/null 
	tput cnorm; exit 1
}

function TCP(){
	echo -e "$blueColour[$HOST]$endColour Scanning all TCP ports"

	/usr/bin/nmap -Pn -n --disable-arp-ping --open -vv -T4 --min-rate 3000 $HOST -p- -oA "$(pwd)/log/TCP-openports" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null
	
	tPORTS=$(grep -oP "\d+/tcp" "$(pwd)/log/TCP-openports.nmap" | awk -F/ '{print $1}' | xargs | sed 's/ /,/g')
	if [ ! -e $tPORTS ];then
		echo -e "$greenColour[$HOST]$endColour Scanning open TCP ports: $yellowColour$tPORTS$endColour"
	
		/usr/bin/nmap -Pn -n --disable-arp-ping --open -vv --min-rate 3000 $HOST -p$tPORTS -sCV --version-all -oA "$(pwd)/log/TCP-services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null
	else
		echo -e "$redColour[$HOST]$endColour Nmap didn't found TCP ports open"
		rm "$(pwd)/log/"TCP-openports.*
	fi
}

function UDP(){
	echo -e "$blueColour[$HOST]$endColour Scanning all UDP ports"

	/usr/bin/nmap -Pn -n --disable-arp-ping --open -vv -sU $HOST --max-scan-delay 300ms --max-retries 2 --min-rate 500 -p- -oA "$(pwd)/log/UDP-openports" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null

	uPORTS=$(grep -oP "\d+/udp" "$(pwd)/log/UDP-openports.nmap" | awk -F/ '{print $1}' | xargs | sed 's/ /,/g')
	if [ ! -e $uPORTS ];then
		echo -e "$greenColour[$HOST]$endColour Scanning open UDP ports: $yellowColour$uPORTS$endColour"
	
		/usr/bin/nmap -Pn -n --disable-arp-ping --open -vv $HOST -p$uPORTS -sUCV --version-all --version-intensity 0 -oA "$(pwd)/log/UDP-services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null
	else
		echo -e "$redColour[$HOST]$endColour Nmap didn't found UDP ports open"
		rm "$(pwd)/log/"UDP-openports.*
	fi
}

function vulns(){
	
	if [[ -e $tPORTS && -e $uPORTS ]];then
		echo -e "$redColour[$HOST]$endColour No TCP/UDP ports open, aborting vuln scan"
	else
		if [ -e $uPORTS ];then
			echo -e "$blueColour[$HOST]$endColour Scanning for known vulnerabilities on ports => $yellowColour$tPORTS$endColour"
			/usr/bin/nmap -Pn -n --disable-arp-ping -vv -T4 --min-rate 3000 $HOST -p$tPORTS --script "vuln and safe" -oA "$(pwd)/log/vulns" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null
		elif [ -e $tPORTS ];then
			echo -e "$blueColour[$HOST]$endColour Scanning for known vulnerabilities on ports => $yellowColour$uPORTS$endColour"
			/usr/bin/nmap -Pn -n --disable-arp-ping -vv -sU $HOST -p$uPORTS --script "vuln and safe" -oA "$(pwd)/log/vulns" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null
		else
			echo -e "$blueColour[$HOST]$endColour Scanning for known vulnerabilities on ports =>$yellowColour T:$tPORTS U:$uPORTS$endColour"
			/usr/bin/nmap -Pn -n --disable-arp-ping -vv $HOST -sS -sU -pT:$tPORTS,U:$uPORTS --script "vuln and safe" -oA "$(pwd)/log/vulns" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null
		fi
	fi
}

function banner(){
	echo "banner"
}

#banner

HOST=$1

if [ -e $HOST ];then echo -e "\n$redColour[!]$endColour Usage: $0 <IP> [<CIDR>]"; exit 0; fi

tput civis

echo "${HOST:(-3)}" | grep -oP "\/\d{1,2}" &>/dev/null
if [[ $? -eq 0 ]];then

	echo -e "\n$blueColour[$HOST]$endColour Discovering alive host"
	nmap -sn -n -PS20,21,22,23,25,53,80,110,143,135,139,443,445,1433,3306,3389,8080,8443 -PU53,67,68,69,111,123,161,500,4500,5353 $HOST -oN "$(pwd)/discovery.nmap" &>/dev/null
	grep "Nmap scan report" "$(pwd)/discovery.nmap" | awk '{print $NF}' > "$(pwd)/discovery.txt"
	hostname -I | sed 's/ /\n/g' | grep -v 'fd15' > "$(pwd)/current.txt"
	diff -u "$(pwd)/discovery.txt" "$(pwd)/current.txt" | grep -oP "\-.\d{1,3}\..*" | tr -d '-' > "$(pwd)/targets.txt"
	rm -f "$(pwd)/discovery.txt" "$(pwd)/current.txt"

	if [[ "$(wc -l $(pwd)/targets.txt | awk '{print $1}')" == "0" ]];then echo -e "$redColour[$HOST]$endColour No hosts alive"; exit 0; fi

	echo -e "$greenColour[$HOST]$endColour Discovered hosts: $yellowColour$(cat "$(pwd)/targets.txt" | xargs | sed 's/ /, /g')$endColour"
	while read line; do 
		if [ ! -d "$(pwd)/$line" ]; then mkdir -p "$(pwd)/$line/"{exploits,log,loot,tools}; fi
		(HOST=$line; cd $HOST; TCP; UDP; vulns) &
	done < "$(pwd)/targets.txt"
	wait

	while read line; do
		if [[ -f "$(pwd)/$line/log/TCP-services.xml" ]];then echo -e "$greenColour[$line]$endColour Nmap TCP scan stored at 'file://$(pwd)/$line/log/TCP-services.xml'"; fi
		if [[ -f "$(pwd)/$line/log/UDP-services.xml" ]];then echo -e "$greenColour[$line]$endColour Nmap UDP scan stored at 'file://$(pwd)/$line/log/UDP-services.xml'"; fi
		if [[ -f "$(pwd)/$line/log/vulns.xml" ]];then echo -e "$greenColour[$line]$endColour Nmap Vuln scan stored at 'file://$(pwd)/$line/log/vulns.xml'"; fi
	done < "$(pwd)/targets.txt"

	rm -f "$(pwd)/targets.txt"
else
	if [ ! -d "$(pwd)/log" ]; then mkdir "$(pwd)/"{exploits,log,loot,tools} 2>/dev/null; fi
	TCP; UDP; vulns
fi

tput cnorm
