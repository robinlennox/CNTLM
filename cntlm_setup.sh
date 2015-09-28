#!/bin/sh

# Function
HIGHLIGHT(){
	exec >/dev/tty
	echo "`tput bold``tput setf 1 `#############################################################` tput sgr0`"
	exec 1>/dev/null 2>/dev/null
}

SPACE(){
	exec >/dev/tty
	echo ""
	exec 1>/dev/null 2>/dev/null
}

PRINT_MESSAGE(){
	exec >/dev/tty
	echo "`tput bold``tput setf 1`[*]`tput sgr0` $1"
	exec 1>/dev/null 2>/dev/null
}

PRINT_GOOD(){
	exec >/dev/tty
	echo "`tput bold``tput setf 2`[*]`tput sgr0` $1"
	exec 1>/dev/null 2>/dev/null
}

PRINT_ERROR(){
	exec >/dev/tty
	echo "`tput bold``tput setf 4`[*]`tput sgr0` $1"
	exec 1>/dev/null 2>/dev/null
}

PRINT_QUESTION(){
	exec >/dev/tty
	echo -n "`tput bold``tput setf 6`[*]`tput sgr0` $1"
	exec 1>/dev/null 2>/dev/null
}

DISABLE_LOGGING () {
	echo "# Suppress CNTLM info messages \nif \$programname == 'cntlm' then stop" | sudo tee -a /etc/rsyslog.d/00-cntlm.conf
	sudo service rsyslog restart
}

# Clear Screen
clear

# Disable output
exec 1>/dev/null 2>/dev/null

# Check CNTLM is Installed
dpkg -s cntlm 2>&1 | grep -o Installed-Size
if [ $? != 0 ] ; then
	PRINT_ERROR "CNTLM not Installed"
	PRINT_ERROR "Try - sudo apt-get install cntlm"
	exit 0
fi

# Kill Process using that port
sudo fuser -k 3128/tcp

# Info
PRINT_GOOD "Setting up NTLM to Proxy"
HIGHLIGHT
SPACE

# read domain details
PRINT_QUESTION "Enter Username [ENTER]: "
read USERNAME
PRINT_QUESTION "Enter Domain Name [ENTER]: "
read DOMAIN
PRINT_QUESTION "Enter Domain Password [ENTER]: "
NTLMV2_HASH=$(/usr/sbin/cntlm -u $USERNAME -d $DOMAIN -f -H | tail -1 |  awk '{print $2}' )
SPACE
HIGHLIGHT
PRINT_MESSAGE "Proxy Details"
PRINT_QUESTION "Enter Proxy Hostname/IP [ENTER]: "
read PROXY_IP
PRINT_QUESTION "Enter Proxy Port [ENTER]: "
read PROXY_PORT
SPACE

# Display back Domain Creds
HIGHLIGHT
PRINT_GOOD "Username - $USERNAME"
PRINT_GOOD "Domain - $DOMAIN"
PRINT_GOOD "Hash - $NTLMV2_HASH"
SPACE
PRINT_GOOD "Proxy IP - $PROXY_IP"
PRINT_GOOD "Proxy Port - $PROXY_PORT"

#Backup CNTLM Config
sudo cp /etc/cntlm.conf_orig /etc/cntlm.conf
sudo cp /etc/cntlm.conf /etc/cntlm.conf_orig

#Update CNTLM Config file
sudo sed -i 's/Username\stestuser/Username        '$USERNAME'/g' /etc/cntlm.conf
sudo sed -i 's/Domain\s\scorp-uk/Domain          '$DOMAIN'/g' /etc/cntlm.conf
sudo sed -i 's/Password\spassword/# Password       password/g' /etc/cntlm.conf
sudo sed -i 's/# PassNTLMv2/PassNTLMv2/g' /etc/cntlm.conf
sudo sed -i 's/D5826E9C665C37C80B53397D5C07BBCB/'$NTLMV2_HASH'/g' /etc/cntlm.conf
sudo sed -i 's/Proxy\s\s10.0.0.41:8080/# Proxy           10.0.0.41:8080/g' /etc/cntlm.conf
sudo sed -i 's/Proxy\s\s10.0.0.42:8080/# Proxy           10.0.0.42:8080/g' /etc/cntlm.conf
sudo sed -i "/# List addresses you do not want to pass to parent proxies/ { s/# List addresses you do not want to pass to parent proxies/Proxy         $PROXY_IP:$PROXY_PORT\n\n&/ }" /etc/cntlm.conf

# Try Creds
# http://www.leg.uct.ac.za/howtos/use-isa-proxies
HIGHLIGHT
PRINT_MESSAGE "Checking Proxy Settings"
PRINT_MESSAGE "Checking may take upto 1 minute"

# Check Proxy
PRINT_QUESTION "Enter Domain Password [ENTER]: "
PROXY_CHECK=$(sudo cntlm -M http://google.com/ | grep 'Wrong\|failed')

if ! [ -z "$PROXY_CHECK" ]; then
	sudo cp /etc/cntlm.conf_orig /etc/cntlm.conf
	PRINT_ERROR "Config Failed"
	exit 0
else
	PRINT_GOOD "Proxy Working!"
fi

#Add to .bashrc
echo "export http_proxy=http://localhost:3128
export ftp_proxy=http://localhost:3128
export https_proxy=http://localhost:3128" >> ~/.bashrc

#Add to /etc/environment
#http://askubuntu.com/questions/150210/how-do-i-set-systemwide-proxy-servers-in-xubuntu-lubuntu-or-ubuntu-studio
echo "http_proxy=http://localhost:3128
ftp_proxy=http://localhost:3128
https_proxy=http://localhost:3128
no_proxy="127.0.0.0/8,localhost"" | sudo tee -a /etc/environment

# Restart service
sudo service cntlm restart

#Add proxy for sudoers
sudo sed -i "/Defaults\senv_reset/ { s/Defaults\senv_reset/\nDefaults        env_keep = \"http_proxy ftp_proxy https_proxy no_proxy\"\n&/ }" /etc/sudoers

# Add Proxy for SVN
dpkg -s svn 2>&1 | grep -o Installed-Size
if [ $? != 0 ] ; then
	echo "Setting up Proxy for SVN"
	sudo echo "http-proxy-host=localhost
http-proxy-port=3128" >> /etc/subversion/servers

fi

# Disable logging all websites visited in syslog
while true; do
	PRINT_QUESTION "Do you want to disable CNTLM logging for all sites visited?"
	read -p "" yn
	case $yn in
		[Yy]* ) DISABLE_LOGGING; break;;
		[Nn]* ) PRINT_MESSAGE  "Logging not disabled";break;;
		* ) PRINT_ERROR  "Please answer yes or no.";;
	esac
done

PRINT_MESSAGE "Logout to take affect"
