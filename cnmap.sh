#!/bin/bash

greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"

trap ctrl_c INT

function ctrl_c(){
	echo -ne "$redColour[!]$endColour Keyboard interrupt received, exiting"
	rm -f "$(pwd)/targets.txt" "$(pwd)/"{TCP,UDP,SERVICES}
	pkill nmap 2>&1 > /dev/null 
	tput cnorm
	exit 1
}

function TCP(){
	echo -ne "\t$greenColour[$HOST]$endColour TCP open ports:" $(nmap -Pn -n --disable-arp-ping --open -vv -T4 --min-rate 3000 $HOST -p- -oA "$(pwd)/log/TCP-openports" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; tPORTS=$(grep -oP "\d+/tcp" "$(pwd)/log/TCP-openports.nmap" | awk -F/ '{print $1}' | xargs | sed 's/ /,/g' | tee "$(pwd)/log/tports.txt"); if [ ! -e $tPORTS ];then echo -e " $yellowColour$tPORTS$endColour"; else echo -e "$redColour NONE$endColour"; rm "$(pwd)/log/"TCP-openports.*; fi); echo
	if [[ -f "$(pwd)/log/TCP-openports.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour TCP scan stored at 'file://$(pwd)/log/TCP-openports.xml'"; fi
}

function UDP(){
	echo -ne "\t$blueColour[$HOST]$endColour UDP open ports:" $(nmap -Pn -n --disable-arp-ping --open -vv -sU $HOST --max-scan-delay 300ms --max-retries 3 --min-rate 100 --min-parallelism 5 --max-rtt-timeout 300ms -p- -oA "$(pwd)/log/UDP-openports" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; uPORTS=$(grep -oP "\d+/udp" "$(pwd)/log/UDP-openports.nmap" | awk -F/ '{print $1}' | xargs | sed 's/ /,/g' | tee "$(pwd)/log/uports.txt"); if [ ! -e $uPORTS ];then echo -e " $yellowColour$uPORTS$endColour"; else echo -e "$redColour NONE$endColour"; rm "$(pwd)/log/"UDP-openports.*; fi); echo
	if [[ -f "$(pwd)/log/UDP-openports.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour UDP scan stored at 'file://$(pwd)/log/UDP-openports.xml'"; fi
}

function services(){
	tPORTS=$(cat "$(pwd)/log/tports.txt" 2>/dev/null)
	uPORTS=$(cat "$(pwd)/log/uports.txt" 2>/dev/null)
	if [[ "$tPORTS" == "" && "$uPORTS" == "" ]];then
		echo -e "\t$redColour[$HOST]$endColour No TCP/UDP ports open, aborting services scan"
	else
		if [ -e $uPORTS ];then
			echo -ne "\t$blueColour[$HOST]$endColour Scanning TCP open ports ..." $(nmap -Pn -n --disable-arp-ping -vv -T4 --min-rate 3000 $HOST -p$tPORTS -sCV --version-all --script "+vuln and safe" --script=vulscan/vulscan.nse --script-args "vulscanshowall=0,vulscanoutput='{title} - {link}\n'" -oA "$(pwd)/log/services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; echo -e "$greenColour Done$endColour"); echo
		elif [ -e $tPORTS ];then
			echo -ne "\t$blueColour[$HOST]$endColour Scanning UDP open ports ..." $(nmap -Pn -n --disable-arp-ping -vv -sUV $HOST -p$uPORTS -sCV --version-all --script "+vuln and safe" --script=vulscan/vulscan.nse --script-args "vulscanshowall=0,vulscanoutput='{title} - {link}\n'" -oA "$(pwd)/log/services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; echo -e "$greenColour Done$endColour"); echo
		else
			echo -ne "\t$blueColour[$HOST]$endColour Scanning TCP/UDP open ports ..." $(nmap -Pn -n --disable-arp-ping -vv $HOST -sSUCV -pT:$tPORTS,U:$uPORTS --version-all --script "+vuln and safe" --script=vulscan/vulscan.nse --script-args "vulscanshowall=0,vulscanoutput='{title} - {link}\n'" -oA "$(pwd)/log/services" --stylesheet https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl &>/dev/null; echo -e "$greenColour Done$endColour"); echo
		fi
		if [[ -f "$(pwd)/log/services.xml" ]];then echo -e "\t$greenColour[$HOST]$endColour Services scan stored at 'file://$(pwd)/log/services.xml'"; fi
	fi
	rm "$(pwd)/log/tports.txt" "$(pwd)/log/uports.txt" &>/dev/null
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
		(HOST=$line; cd $HOST; TCP) &
	done < "$(pwd)/targets.txt"

	wait
	echo -e "\n$blueColour[*]$endColour Service scan started\n"
	while read line; do 
		(HOST=$line; cd $HOST; services) &
	done < "$(pwd)/targets.txt"

	wait
	echo -e "\n$blueColour[*]$endColour UDP scan started\n"
	while read line; do 
		(HOST=$line; cd $HOST; UDP) &
	done < "$(pwd)/targets.txt"

	wait
	rm -f "$(pwd)/targets.txt" "$(pwd)/"{TCP,UDP,SERVICES}
else
	if [ ! -d "$(pwd)/log" ]; then mkdir "$(pwd)/"{exploits,log,loot,tools} 2>/dev/null; fi
	TCP; services; UDP
fi

tput cnorm
