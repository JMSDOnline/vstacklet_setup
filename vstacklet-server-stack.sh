#!/bin/bash
#
# [VStacklet Varnish LEMP Stack Installation Script]
#
# GitHub:   https://github.com/JMSDOnline/vstacklet
# Author:   Jason Matthews
# URL:      https://jmsolodesigns.com/code-projects/vstacklet/varnish-lemp-stack
#
# shellcheck disable=2068,1091,2312
# find server IP and server hostname for nginx configuration
#################################################################################
server_ip=$(ip addr show | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1 | head -n 1)
hostname1=$(hostname -s)
#################################################################################
#Script Console Colors
black=$(tput setaf 0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
on_red=$(tput setab 1)
on_green=$(tput setab 2)
bold=$(tput bold)
standout=$(tput smso)
reset_standout=$(tput rmso)
normal=$(tput sgr0)
alert=${white}${on_red}
title=${standout}
repo_title=${black}${on_green}
#################################################################################
if [[ -f /usr/bin/lsb_release ]]; then
	DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
elif [[ -f "/etc/redhat-release" ]]; then
	DISTRO=$(grep -oE 'Fedora|CentOS|Red.Hat' /etc/redhat-release)
elif [[ -f "/etc/debian_version" ]]; then
	DISTRO='Debian'
fi
#################################################################################
function _string() { perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 15; }
#################################################################################

# intro function (1)
function _intro() {
	DISTRO=$(lsb_release -is)
	CODENAME=$(lsb_release -cs)
	SETNAME=$(lsb_release -rc)
	echo
	echo
	echo "[${repo_title}VStacklet${normal}] ${title} VStacklet Webserver Installation ${normal}  "
	echo
	echo "   ${title}              Heads Up!               ${normal} "
	echo "   ${message_title}  VStacklet works with the following  ${normal} "
	echo "   ${message_title}  Ubuntu 18.04/20.04 & Debian 9/10/11     ${normal} "
	echo
	echo
	echo "${green}Checking distribution ...${normal}"
	if [[ ! -x /usr/bin/lsb_release ]]; then
		echo "It looks like you are running ${DISTRO}, which is not supported by vstacklet."
		echo "Exiting..."
		exit 1
	fi
	"$(lsb_release -a)"
	echo
	if [[ ! ${DISTRO} =~ ("Ubuntu"|"Debian") ]]; then
		echo "${DISTRO}: ${alert} It looks like you are running ${DISTRO}, which is not supported by vstacklet ${normal} "
		echo 'Exiting...'
		exit 1
	elif [[ ! ${CODENAME} =~ ("bionic"|"focal"|"jessie"|"buster"|"bullseye") ]]; then
		echo "Oh drats! You do not appear to be running a supported ${DISTRO} release."
		echo "${bold}${SETNAME}${normal}"
		echo 'Exiting...'
		exit 1
	fi
}

# check if root function (2)
function _checkroot() {
	if [[ ${EUID} != 0 ]]; then
		echo 'This script must be run with root privileges.'
		echo 'Exiting...'
		exit 1
	fi
	echo "${green}Congrats! You're running as root. Let's continue${normal} ... "
	echo
}

# check if create log function (3)
function _logcheck() {
	echo -ne "${bold}${yellow}Do you wish to write to a log file?${normal} (Default: ${green}${bold}Y${normal}) "
	read -r input
	case ${input} in
	[yY] | [yY][Ee][Ss] | "")
		OUTTO="/root/vstacklet.${PPID}.log"
		echo "${bold}Output is being sent to /root/vstacklet.${magenta}${PPID}${normal}${bold}.log${normal}"
		;;
	[nN] | [nN][Oo])
		OUTTO="/dev/null 2>&1"
		echo "${cyan}NO output will be logged${normal}"
		;;
	*)
		OUTTO="/root/vstacklet.${PPID}.log"
		echo "${bold}Output is being sent to /root/vstacklet.${magenta}${PPID}${normal}${bold}.log${normal}"
		;;
	esac
	if [[ ! -d /root/tmp ]]; then
		sed -i 's/noexec,//g' /etc/fstab
		mount -o remount /tmp >>"${OUTTO}" 2>&1
	fi
}

# setting system hostname function (7)
function _hostname() {
	echo -ne "Please enter a hostname for this server (${bold}Hit ${standout}${green}ENTER${normal} to make no changes${normal}): "
	read -r input
	if [[ -z ${input} ]]; then
		echo "No hostname supplied, no changes made!!"
	else
		hostname "${input}"
		echo "${input}" >/etc/hostname
		echo "Hostname set to ${input}"
	fi
	echo
}

# setting main web root directory function (7)
function _asksitename() {
	#################################################################
	# You may now optionally name your main web root directory.
	# If you choose to not name your main websites root directory,
	# then your servers hostname will be used as a default.
	#################################################################
	echo "  You may now optionally name your main web root directory."
	echo "  If you choose to not name your main websites root directory,"
	echo "  then your servers hostname will be used as a default."
	echo "  Default: /srv/www/${green}${hostname1}${normal}/public/"
	echo
	echo -n "${bold}${yellow}Would you like to name your main web root directory?${normal} [${bold}${green}Y${normal}]es [n]o): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") sitename=yes ;;
	[nN] | [nN][Oo]) sitename=no ;;
	*)
		echo "Invalid input, defaulting to yes"
		_asksitename
		;;
	esac
}

function _sitename() {
	if [[ ${sitename} == yes ]]; then
		read -rp "${bold}Name for your main websites root directory ${normal} : " site_path
		echo
		echo "Your website directory has been set to /srv/www/${green}${bold}${site_path}${normal}/public/"
		echo
	fi
}

function _nositename() {
	if [[ ${sitename} == "no" ]]; then
		echo
		echo "Your website directory has been set to /srv/www/${green}${bold}${hostname1}${normal}/public/"
		echo
	fi
}

function _bashrc() {
	cp "${local_setup}templates/bashrc.template" /root/.bashrc
	if [[ ${sitename} == "yes" ]]; then
		sed -i "s/HOSTNAME/${site_path}/g" /root/.bashrc
	else
		sed -i "s/HOSTNAME/${hostname1}/g" /root/.bashrc
	fi
	profile="/root/.profile"
	if [[ ! -f ${profile} ]]; then
		cp "${local_setup}templates/profile.template" /root/.profile
	fi
}

function _askcontinue() {
	echo
	echo "Press ${standout}${green}ENTER${normal} when you're ready to begin or ${standout}${red}Ctrl+Z${normal} to cancel"
	read -r input
	echo
}

# This function blocks an insecure port 1900 that may lead to
# DDoS masked attacks. Only remove this function if you absolutely
# need port 1900. In most cases, this is a junk port.
function _ssdpblock() {
	iptables -I INPUT 1 -p udp -m udp --dport 1900 -j DROP
}

# package and repo addition (4) _update and upgrade_
function _updates() {
	if lsb_release >>"${OUTTO}" 2>&1; then
		echo "lsb_release is installed, continuing..."
	else
		apt-get -y -q install lsb-release >>"${OUTTO}" 2>&1
		if [[ -e /usr/bin/lsb_release ]]; then
			echo "lsb_release installed"
		else
			echo "failed to install lsb-release from apt-get, please install manually and re-run script"
			exit
		fi
	fi
	if [[ ${DISTRO} == Debian ]]; then
		cat >/etc/apt/sources.list <<EOF
#------------------------------------------------------------------------------#
#                            OFFICIAL DEBIAN REPOS                             #
#------------------------------------------------------------------------------#

###### Debian Main Repos
deb http://ftp.nl.debian.org/debian testing main contrib non-free
deb-src http://ftp.nl.debian.org/debian testing main contrib non-free

###### Debian Update Repos
deb http://ftp.debian.org/debian/ ${CODENAME}-updates main contrib non-free
deb-src http://ftp.debian.org/debian/ ${CODENAME}-updates main contrib non-free
deb http://security.debian.org/ ${CODENAME}/updates main contrib non-free
deb-src http://security.debian.org/ ${CODENAME}/updates main contrib non-free

#Debian Backports Repos
#http://backports.debian.org/debian-backports squeeze-backports main
EOF

	elif [[ ${DISTRO} == Ubuntu ]]; then
		cat >/etc/apt/sources.list <<EOF
#------------------------------------------------------------------------------#
#                            OFFICIAL UBUNTU REPOS                             #
#------------------------------------------------------------------------------#

###### Ubuntu Main Repos
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe multiverse

###### Ubuntu Update Repos
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse

###### Ubuntu Partner Repo
deb http://archive.canonical.com/ubuntu ${CODENAME} partner
deb-src http://archive.canonical.com/ubuntu ${CODENAME} partner
EOF

	elif [[ ${DISTRO} == Ubuntu && ${CODENAME} == bionic ]]; then
		cat >/etc/apt/sources.list <<ABR
#------------------------------------------------------------------------------#
#                            OFFICIAL UBUNTU REPOS                             #
#------------------------------------------------------------------------------#

###### Ubuntu Main Repos
deb http://us.archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe
deb-src http://us.archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe

###### Ubuntu Update Repos
deb http://us.archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe
deb http://us.archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe
deb-src http://us.archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe
deb-src http://us.archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe
ABR
	fi
	echo -n "Updating system ... "
	if [[ ${DISTRO} == Debian ]]; then
		export DEBIAN_FRONTEND=noninteractive
		{
			yes '' | apt-get -y update
			apt-get -u purge samba samba-common
			yes '' | apt-get -y upgrade
		} >>"${OUTTO}" 2>&1
	else
		export DEBIAN_FRONTEND=noninteractive
		{
			apt-get -y update
			apt-get -y purge samba samba-common
			apt-get -y upgrade
		} >>"${OUTTO}" 2>&1
	fi
	#if [[ -e /etc/ssh/sshd_config ]]; then
	#  echo "Port 2222" /etc/ssh/sshd_config
	#  sed -i 's/Port 22/Port 2222/g' /etc/ssh/sshd_config
	#  service ssh restart >>"${OUTTO}" 2>&1
	#fi
	#echo "${OK}"
	clear
}

# setting locale function (5)
function _locale() {
	apt-get -y install language-pack-en-base >>"${OUTTO}" 2>&1
	echo "en_US.UTF-8 UTF-8" >/etc/locale.gen
	echo "LANG=en_US.UTF-8" >/etc/default/locale
	echo "LANGUAGE=en_US.UTF-8" >>/etc/default/locale
	echo "LC_ALL=en_US.UTF-8" >>/etc/default/locale
	if [[ -e /usr/sbin/locale-gen ]]; then
		locale-gen >>"${OUTTO}" 2>&1
	else
		{
			apt-get -y update
			apt-get -y install locales locale-gen
			locale-gen
		} >>"${OUTTO}" 2>&1
		export LANG="en_US.UTF-8"
		export LC_ALL="en_US.UTF-8"
		export LANGUAGE="en_US.UTF-8"
	fi
}

# system packages and repos function (6)
# Update packages and add MariaDB, Varnish, and Nginx repositories
function _softcommon() {
	# package and repo addition (a) _install common properties_
	apt-get -y install software-properties-common python-software-properties apt-transport-https >>"${OUTTO}" 2>&1
	echo "${OK}"
}

# package and repo addition (b) _install softwares and packages_
function _depends() {
	apt-get -y install nano unzip git dos2unix htop iotop bc libwww-perl dnsutils curl sudo >>"${OUTTO}" 2>&1
	echo "${OK}"
}

# package and repo addition (c) _add signed keys_
function _keys() {
	# MariaDB Signed Keys
	{
		apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
		apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
	} >>"${OUTTO}" 2>&1
	# PHP7 Signed Keys - via ondrej_ubuntu_php
	apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0x5a16e7281be7a449 >>"${OUTTO}" 2>&1
	# Varnish Signed Keys
	#curl -s https://repo.varnish-cache.org/GPG-key.txt | apt-key add - > /dev/null 2>&1;
	# Nginx Signed Keys
	#curl -s http://nginx.org/keys/nginx_signing.key | apt-key add - > /dev/null 2>&1;
	# HHVM Signed Keys
	curl -s http://dl.hhvm.com/conf/hhvm.gpg.key | apt-key add - >/dev/null 2>&1
	echo "${OK}"
}

# package and repo addition (d) _add respo sources_
function _repos() {
	if [[ ${DISTRO} == Ubuntu ]]; then
		# add php8.1 repo via ppa:ondrej
		LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y >>"${OUTTO}" 2>&1
		# use mariadb 10.7 repo
		cat >/etc/apt/sources.list.d/mariadb.list <<EOF
		wget -qO- https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/mariadb.gpg
deb [arch=amd64,i386,arm64,ppc64el] http://mirrors.syringanetworks.net/mariadb/repo/10.7/ubuntu $(lsb_release -sc) main
deb-src http://mirrors.syringanetworks.net/mariadb/repo/10.7/ubuntu/ $(lsb_release -sc) main
EOF
		# use the trusty branch to install varnish
		#    cat >/etc/apt/sources.list.d/varnish-cache.list<<EOF
		#deb https://repo.varnish-cache.org/ubuntu/ trusty varnish-4.1
		#EOF
		# include hhvm sources
		cat >/etc/apt/sources.list.d/hhvm.list <<EOF
deb http://dl.hhvm.com/ubuntu $(lsb_release -sc) main
EOF
		# use nginx development
		#    cat >/etc/apt/sources.list.d/nginx-mainline-$(lsb_release -sc).list<<EOF
		#deb http://nginx.org/packages/mainline/ubuntu/ $(lsb_release -sc) nginx
		#deb-src http://nginx.org/packages/mainline/ubuntu/ $(lsb_release -sc) nginx
		#EOF
	fi
	if [[ ${DISTRO} == Debian ]]; then
		# add php8.1 repo via sury
		curl -sSLo "/usr/share/keyrings/deb.sury.org-php.gpg" "https://packages.sury.org/php/apt.gpg"
		sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
		[[ -f "/etc/apt/sources.list.d/proposed.list" ]] && mv -f /etc/apt/sources.list.d/proposed.list /etc/apt/sources.list.d/proposed.list.BAK
		# use mariadb 10.7 repo
		wget -qO- https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor >/etc/apt/trusted.gpg.d/mariadb.gpg
		cat >/etc/apt/sources.list.d/mariadb.list <<EOF
deb [arch=amd64,i386,arm64,ppc64el] http://mirrors.syringanetworks.net/mariadb/repo/10.7/debian $(lsb_release -sc) main
deb-src http://mirrors.syringanetworks.net/mariadb/repo/10.7/debian/ $(lsb_release -sc) main
EOF
		# use the jessie branch to install varnish 4.1
		#    cat >/etc/apt/sources.list.d/varnish-cache.list<<EOF
		#deb https://repo.varnish-cache.org/debian/ jessie varnish-4.1
		#EOF
		# include hhvm sources
		cat >/etc/apt/sources.list.d/hhvm.list <<EOF
deb http://dl.hhvm.com/debian $(lsb_release -sc) main
EOF
		# use nginx mainline
		#    cat >/etc/apt/sources.list.d/nginx-mainline-"${CODENAME}".list<<EOF
		#deb http://nginx.org/packages/mainline/debian/ "${CODENAME}" nginx
		#deb-src http://nginx.org/packages/mainline/debian/ "${CODENAME}" nginx
		#EOF
	fi
	echo "${OK}"
}

# package and repo addition (e) _update and upgrade_
function _updates() {
	echo -n "Updating system ... "
	export DEBIAN_FRONTEND=noninteractive &&
		apt-get -y update >>"${OUTTO}" 2>&1
	apt-get -y upgrade >>"${OUTTO}" 2>&1
	apt-get -y autoremove >>"${OUTTO}" 2>&1
	echo "${OK}"
}

# ask php version function (12)
function _askphpversion() {
	echo -e "1) php${green}8.1${normal}"
	echo -e "2) php${green}5.6${normal}"
	echo -e "3) ${green}HHVM${normal}"
	echo -ne "${yellow}What version of php do you want?${normal} (Default php${green}8.1${normal}): "
	read -r version
	case ${version} in
	1 | "") PHPVERSION=8.1 ;;
	2) PHPVERSION=5.6 ;;
	3) PHPVERSION=HHVM ;;
	*) PHPVERSION=8.1 ;;
	esac
	echo "Using ${PHPVERSION} for php"
}

# install php function (11)
function _php8() {
	echo -ne "Installing and Adjusting php${green}${PHPVERSION}${normal}-fpm w/ OPCode Cache ... "
	apt-get -y install php8.1-fpm php8.1-zip php8.1-cgi php8.1-cli php8.1-common php8.1-curl php8.1-dev php8.1-gd php8.1-gmp php8.1-imap php8.1-intl php8.1-ldap php8.1-mbstring php8.1-mysql php8.1-opcache php8.1-pspell php8.1-readline php8.1-soap php8.1-xml libmcrypt-dev mcrypt >>"${OUTTO}" 2>&1
	pconfig=$(php --ini | grep "Loaded Configuration" | sed -e "s|.*:\s*||")
	ismcrypt=$(php --ini | grep "extension=mcrypt.so" "${pconfig}")
	#if [[ ${ismcrypt} != 'extension=mcrypt.so' ]]; then
	#	printf "\n" | pecl uninstall channel://pecl.php.net/mcrypt-1.0.3 >/dev/null 2>&1
	#	sleep 3
	#	printf "\n" | pecl install channel://pecl.php.net/mcrypt-1.0.3 >/dev/null 2>&1
	#	bash -c "echo 'extension=mcrypt.so' >> /etc/php/8.1/cli/php.ini"
	#	bash -c "echo 'extension=mcrypt.so' >> /etc/php/8.1/fpm/php.ini"
	#else
	#	_info "mcrypt.so extension already exist in php.ini ... [skipping]"
	#fi
	if [[ ${memcached} == yes ]]; then
		#ln -nsf /etc/php/8.1/mods-available/memcached.ini /etc/php/8.1/fpm/conf.d/20-memcached.ini
		#ln -nsf /etc/php/8.1/mods-available/memcached.ini /etc/php/8.1/cli/conf.d/20-memcached.ini
		php81memcahced=$(dpkg --get-selections | grep -Eo php8.1-memcached)
		if [[ ${php81memcahced} != *php8.1-memcached* ]]; then
			apt-get -y install --force-reinstall true php8.1-memcached >/dev/null 2>&1
		else
			:
		fi
	fi
	sed -i.bak -e "s/post_max_size.*/post_max_size = 64M/" \
		-e "s/upload_max_filesize.*/upload_max_filesize = 92M/" \
		-e "s/expose_php.*/expose_php = Off/" \
		-e "s/128M/768M/" \
		-e "s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=1/" \
		-e "s/;opcache.enable.*/opcache.enable=1/" \
		-e "s/;opcache.memory_consumption.*/opcache.memory_consumption=128/" \
		-e "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files=4000/" \
		-e "s/;opcache.revalidate_freq.*/opcache.revalidate_freq=240/" /etc/php/8.1/fpm/php.ini

	sed -i.bak -e "s/post_max_size.*/post_max_size = 64M/" \
		-e "s/upload_max_filesize.*/upload_max_filesize = 92M/" \
		-e "s/expose_php.*/expose_php = Off/" \
		-e "s/128M/768M/" \
		-e "s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=1/" \
		-e "s/;opcache.enable.*/opcache.enable=1/" \
		-e "s/;opcache.memory_consumption.*/opcache.memory_consumption=128/" \
		-e "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files=4000/" \
		-e "s/;opcache.revalidate_freq.*/opcache.revalidate_freq=240/" /etc/php/8.1/cli/php.ini
	phpenmod -v 8.1 opcache
	phpenmod -v 8.1 xml
	phpenmod -v 8.1 mbstring
	phpenmod -v 8.1 msgpack
	phpenmod -v 8.1 memcached
	echo "${OK}"
}
function _php5() {
	echo -ne "Installing and Adjusting php${green}${PHPVERSION}${normal}-fpm w/ OPCode Cache ... "
	apt-get -y install libssl1.0.2 php-common php5.6 php5.6-cli php5.6-common php5.6-fpm php5.6-json php5.6-opcache php5.6-readline php5.6-mysql php5.6-curl php5.6-gd php5.6-dev php5.6-imap php5.6-mcrypt php5.6-mbstring php5.6-xml php-gettext >>"${OUTTO}" 2>&1
	sed -i.bak -e "s/post_max_size = 8M/post_max_size = 64M/g" \
		-e "s/upload_max_filesize = 2M/upload_max_filesize = 92M/g" \
		-e "s/expose_php = On/expose_php = Off/g" \
		-e "s/128M/512M/g" \
		-e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" \
		-e "s/;opcache.enable=0/opcache.enable=1/g" \
		-e "s/;opcache.memory_consumption=64/opcache.memory_consumption=128/g" \
		-e "s/;opcache.max_accelerated_files=2000/opcache.max_accelerated_files=4000/g" \
		-e "s/;opcache.revalidate_freq=2/opcache.revalidate_freq=240/g" /etc/php/5.6/fpm/php.ini
	# ensure opcache module is activated
	phpenmod -v 5.6 opcache
	# ensure mcrypt module is activated
	phpenmod -v 5.6 mcrypt
	# ensure mbstring module is activated
	phpenmod -v 5.6 mbstring
	# ensure xml module is activated
	phpenmod -v 5.6 xml
	echo "${OK}"
}
function _hhvm() {
	echo -ne "Installing and Adjusting ${green}${PHPVERSION}${normal} ... "
	{
		apt-get -y install hhvm
		/usr/share/hhvm/install_fastcgi.sh
		update-rc.d hhvm defaults
	} >>"${OUTTO}" 2>&1
	/usr/bin/update-alternatives --install /usr/bin/php php /usr/bin/hhvm 60 >>"${OUTTO}" 2>&1
	# get off the port and use socket - HStacklet nginx configurations already know this
	cp "${local_hhvm}server.ini.template" /etc/hhvm/server.ini
	cp "${local_hhvm}php.ini.template" /etc/hhvm/php.ini
	echo "${OK}"
}

# install nginx function (8)
function _nginx() {
	{
		apt-get -y install nginx-extras
		update-rc.d nginx defaults
	} >>"${OUTTO}" 2>&1
	service nginx stop >>"${OUTTO}" 2>&1
	mv /etc/nginx /etc/nginx-previous
	rsync -aP --exclude=/pagespeed --exclude=LICENSE --exclude=README --exclude=.git "${local_nginx}"* /etc/nginx >>"${OUTTO}" 2>&1
	\cp -rf /etc/nginx-previous/uwsgi_params /etc/nginx-previous/fastcgi_params /etc/nginx >>"${OUTTO}" 2>&1
	mkdir -p /etc/nginx/{conf.d,cache}
	chown -R www-data /etc/nginx/cache
	chgrp -R www-data /etc/nginx/cache
	chmod -R g+rw /etc/nginx/cache
	sh -c 'find /etc/nginx/cache -type d -print0 | sudo xargs -0 chmod g+s'
	# rename default.conf template
	if [[ ${sitename} == "yes" ]]; then
		if [[ ${PHPVERSION} == "8.1" ]]; then
			cp "${local_php8}nginx/conf.d/default.php8.conf.save" "/etc/nginx/conf.d/${site_path}.conf"
			# build applications web root directory if sitename is provided
			mkdir -p "/srv/www/${site_path}"/{logs,ssl,public}
		fi
		if [[ ${PHPVERSION} == "5.6" ]]; then
			cp "${local_php5}nginx/conf.d/default.php5.conf.save" "/etc/nginx/conf.d/${site_path}.conf"
			# build applications web root directory if sitename is provided
			mkdir -p "/srv/www/${site_path}"/{logs,ssl,public}
		fi
		if [[ ${PHPVERSION} == "HHVM" ]]; then
			cp "${local_hhvm}nginx/conf.d/default.hhvm.conf.save" "/etc/nginx/conf.d/${site_path}.conf"
			# build applications web root directory if sitename is provided
			mkdir -p "/srv/www/${site_path}"/{logs,ssl,public}
		fi
	else
		if [[ ${PHPVERSION} == "8.1" ]]; then
			cp "${local_php8}nginx/conf.d/default.php8.conf.save" "/etc/nginx/conf.d/${hostname1}.conf"
			# build applications web root directory if sitename is provided
			mkdir -p "/srv/www/${hostname1}"/{logs,ssl,public}
		fi
		if [[ ${PHPVERSION} == "5.6" ]]; then
			cp "${local_php5}nginx/conf.d/default.php5.conf.save" "/etc/nginx/conf.d/${hostname1}.conf"
			# build applications web root directory if no sitename is provided
			mkdir -p "/srv/www/${hostname1}"/{logs,ssl,public}
		fi
		if [[ ${PHPVERSION} == "HHVM" ]]; then
			cp "${local_hhvm}nginx/conf.d/default.hhvm.conf.save" "/etc/nginx/conf.d/${hostname1}.conf"
			# build applications web root directory if sitename is provided
			mkdir -p "/srv/www/${hostname1}"/{logs,ssl,public}
		fi
	fi
	# write checkinfo for php verification
	if [[ ${sitename} == "yes" ]]; then
		echo '<?php phpinfo(); ?>' >"/srv/www/${site_path}/public/checkinfo.php"
	else
		echo '<?php phpinfo(); ?>' >"/srv/www/${hostname1}/public/checkinfo.php"
	fi
	echo "${OK}"
}

# adjust permissions function (9)
function _perms() {
	chgrp -R www-data /srv/www/*
	chmod -R g+rw /srv/www/*
	sh -c 'find /srv/www/* -type d -print0 | sudo xargs -0 chmod g+s'
	echo "${OK}"
}

# install varnishd (10)
function _askvarnish() {
	echo -n "${bold}${yellow}Do you want to install Varnish?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") varnish=yes ;;
	[nN] | [nN][Oo]) varnish=no ;;
	*)
		echo "Invalid input..."
		_askvarnish
		;;
	esac
}

function _varnish() {
	if [[ ${varnish} == "yes" ]]; then
		echo -n "Installing Varnish ... "
		apt-get -y install varnish >>"${OUTTO}" 2>&1
		cd /etc/varnish || echo "Error: /etc/varnish does not exist" && exit 1
		mv default.vcl default.vcl.ORIG
		\cp -f "${local_varnish}default.vcl.template" "/etc/varnish/default.vcl" >/dev/null 2>&1
		cd || echo "Error: unable to change directory" && exit 1
		sed -i "s/127.0.0.1/${server_ip}/g" "/etc/varnish/default.vcl"
		sed -i "s/6081/80/g" "/etc/default/varnish"
		# then there is varnish with systemd in ubuntu 15.x
		# let us shake that headache now
		\cp -f /lib/systemd/system/varnishlog.service /etc/systemd/system/
		\cp -f /lib/systemd/system/varnish.service /etc/systemd/system/
		sed -i "s/6081/80/g" /etc/systemd/system/varnish.service
		sed -i "s/6081/80/g" /lib/systemd/system/varnish.service
		systemctl daemon-reload
		echo "${OK}"
	fi
}

function _novarnish() {
	if [[ ${varnish} == "no" ]]; then
		echo "${cyan}Skipping Varnish Installation...${normal}"
	fi
}

# install memcached for php8 function (12)
function _askmemcached() {
	echo -n "${bold}${yellow}Do you want to install Memcached for PHP 8?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") memcached=yes ;;
	[nN] | [nN][Oo]) memcached=no ;;
	*)
		echo "Invalid input..."
		_askmemcached
		;;
	esac
}

function _memcached() {
	if [[ ${memcached} == "yes" ]]; then
		echo -n "Installing Memcached for PHP 8 ... "
		apt-get -y install php8.1-dev git pkg-config build-essential libmemcached-dev >/dev/null 2>&1
		apt-get -y install php-memcached memcached >/dev/null 2>&1
	fi
	echo "${OK}"
}

function _nomemcached() {
	if [[ ${memcached} == "no" ]]; then
		echo "${cyan}Skipping Memcached Installation...${normal}"
	fi
}

# install ioncube loader function (12)
function _askioncube() {
	echo -n "${bold}${yellow}Do you want to install IonCube Loader?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") ioncube=yes ;;
	[nN] | [nN][Oo]) ioncube=no ;;
	*)
		echo "Invalid input..."
		_askioncube
		;;
	esac
}

function _ioncube() {
	if [[ ${ioncube} == "yes" ]]; then
		echo -n "${green}Installing IonCube Loader${normal} ... "
		mkdir tmp 2>&1
		cd tmp || echo "Error: Could not change directory to tmp" && exit 1
		wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz >/dev/null 2>&1
		tar xvfz ioncube_loaders_lin_x86-64.tar.gz >/dev/null 2>&1
		cd ioncube || echo "Error: ioncube directory not found" >/dev/null 2>&1
		cp ioncube_loader_lin_5.6.so /usr/lib/php/20131226/ >/dev/null 2>&1
		echo -e "zend_extension = /usr/lib/php/20131226/ioncube_loader_lin_5.6.so" >/etc/php/5.6/fpm/conf.d/20-ioncube.ini
		echo "zend_extension = /usr/lib/php/20131226/ioncube_loader_lin_5.6.so" >>/etc/php/5.6/fpm/php.ini
		cd || echo "Error: unable to change directory" >/dev/null 2>&1
		rm -rf tmp*
		echo "${OK}"
	fi
}

function _noioncube() {
	if [[ ${ioncube} == "no" ]]; then
		echo "${cyan}Skipping IonCube Installation...${normal}"
	fi
}

# install mariadb function (13)
function _askmariadb() {
	echo -n "${bold}${yellow}Do you want to install MariaDB?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") mariadb=yes ;;
	[nN] | [nN][Oo]) mariadb=no ;;
	*)
		echo "Invalid input..."
		_askmariadb
		;;
	esac
}

function _mariadb() {
	if [[ ${mariadb} == "yes" ]]; then
		export DEBIAN_FRONTEND=noninteractive
		apt-get -y install mariadb-server >>"${OUTTO}" 2>&1
		echo "${OK}"
	fi
}

function _nomariadb() {
	if [[ ${mariadb} == "no" ]]; then
		echo "${cyan}Skipping MariaDB Installation...${normal}"
	fi
}

# install phpmyadmin function (14)
function _askphpmyadmin() {
	echo -n "${bold}${yellow}Do you want to install phpMyAdmin?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") phpmyadmin=yes ;;
	[nN] | [nN][Oo]) phpmyadmin=no ;;
	*)
		echo "Invalid input..."
		_askphpmyadmin
		;;
	esac
}

function _phpmyadmin() {
	if [[ ${phpmyadmin} == "yes" ]]; then
		# generate random passwords for the MySql root user
		pmapass=$(perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 15)
		mysqlpass=$(perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 15)
		mysqladmin -u root -h localhost password "${mysqlpass}"
		echo -n "${bold}Installing MySQL with user:${normal} ${bold}${green}root${normal}${bold} / passwd:${normal} ${bold}${green}${mysqlpass}${normal} ... "
		apt-get -y install debconf-utils >>"${OUTTO}" 2>&1
		export DEBIAN_FRONTEND=noninteractive
		# silently configure given options and install
		echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
		echo "phpmyadmin phpmyadmin/mysql/admin-pass password ${mysqlpass}" | debconf-set-selections
		echo "phpmyadmin phpmyadmin/mysql/app-pass password ${pmapass}" | debconf-set-selections
		echo "phpmyadmin phpmyadmin/app-password-confirm password ${pmapass}" | debconf-set-selections
		echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
		apt-get -y install phpmyadmin >>"${OUTTO}" 2>&1
		if [[ ${sitename} == "yes" ]]; then
			# create a sym-link to live directory.
			ln -s /usr/share/phpmyadmin "/srv/www/${site_path}/public"
		else
			# create a sym-link to live directory.
			ln -s /usr/share/phpmyadmin "/srv/www/${hostname1}/public"
		fi
		echo "${OK}"
		# show phpmyadmin creds
		{
			echo '[phpMyAdmin Login]'
			echo " - pmadbuser='phpmyadmin'"
			echo " - pmadbpass='${pmapass}'"
			echo ''
			echo "   Access phpMyAdmin at: "
			echo "   http://${server_ip}:8080/phpmyadmin/"
			echo ''
			echo ''
			echo '[MySQL Login]'
			echo " - sqldbuser='root'"
			echo " - sqldbpass='${mysqlpass}'"
			echo
		} >>~/.my.cnf
		# closing statement
		echo
		echo "${bold}Below are your phpMyAdmin and MySQL details.${normal}"
		echo "${bold}Details are logged in the${normal} ${bold}${green}/root/.my.cnf${normal} ${bold}file.${normal}"
		echo "Best practice is to copy this file locally then rm ~/.my.cnf"
		echo
		# show contents of .my.cnf file
		cat ~/.my.cnf
		echo
	fi
}

function _nophpmyadmin() {
	if [[ ${phpmyadmin} == "no" ]]; then
		echo "${cyan}Skipping phpMyAdmin Installation...${normal}"
	fi
}

# install and adjust config server firewall function (15)
function _askcsf() {
	echo -n "${bold}${yellow}Do you want to install CSF (Config Server Firewall)?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") csf=yes ;;
	[nN] | [nN][Oo]) csf=no ;;
	*)
		echo "Invalid input..."
		_askcsf
		;;
	esac
}

function _csf() {
	if [[ ${csf} == "yes" ]]; then
		echo -n "${green}Installing and Adjusting CSF${normal} ... "
		apt-get -y install e2fsprogs >/dev/null 2>&1
		wget https://download.configserver.com/csf.tgz
		#wget http://www.configserver.com/free/csf.tgz >/dev/null 2>&1;
		tar -xzf csf.tgz >/dev/null 2>&1
		ufw disable >>"${OUTTO}" 2>&1
		cd csf || echo "Error: Could not change directory to csf" && exit 1
		sh install.sh >>"${OUTTO}" 2>&1
		perl /usr/local/csf/bin/csftest.pl >>"${OUTTO}" 2>&1
		# modify csf blocklists - essentially like CloudFlare, but on your machine
		sed -i.bak -e "s/#SPAMDROP|86400|0|/SPAMDROP|86400|100|/g" \
			-e "s/#SPAMEDROP|86400|0|/SPAMEDROP|86400|100|/g" \
			-e "s/#DSHIELD|86400|0|/DSHIELD|86400|100|/g" \
			-e "s/#TOR|86400|0|/TOR|86400|100|/g" \
			-e "s/#ALTTOR|86400|0|/ALTTOR|86400|100|/g" \
			-e "s/#BOGON|86400|0|/BOGON|86400|100|/g" \
			-e "s/#HONEYPOT|86400|0|/HONEYPOT|86400|100|/g" \
			-e "s/#CIARMY|86400|0|/CIARMY|86400|100|/g" \
			-e "s/#BFB|86400|0|/BFB|86400|100|/g" \
			-e "s/#OPENBL|86400|0|/OPENBL|86400|100|/g" \
			-e "s/#AUTOSHUN|86400|0|/AUTOSHUN|86400|100|/g" \
			-e "s/#MAXMIND|86400|0|/MAXMIND|86400|100|/g" \
			-e "s/#BDE|3600|0|/BDE|3600|100|/g" \
			-e "s/#BDEALL|86400|0|/BDEALL|86400|100|/g" /etc/csf/csf.blocklists
		# modify csf ignore - ignore nginx, varnish & mysql
		{
			echo
			echo "[ VStacklet Additions - ignore nginx, varnish & mysql ]"
			echo "nginx"
			echo "varnishd"
			echo "mysqld"
			echo "rsyslogd"
			echo "systemd-timesyncd"
			echo "systemd-resolved"
		} >>/etc/csf/csf.ignore
		# modify csf allow - allow ssh, http, https, mysql, phpmyadmin, varnish
		{
			echo
			echo "[ VStacklet Additions - allow ssh, http, https, mysql, phpmyadmin, varnish ]"
			echo "22"
			echo "80"
			echo "443"
			echo "3306"
			echo "8080"
			echo "6081"
		} >>/etc/csf/csf.allow
		# modify csf conf - make suitable changes for non-cpanel environment
		sed -i.bak -e 's/TESTING = "1"/TESTING = "0"/g' \
			-e 's/RESTRICT_SYSLOG = "0"/RESTRICT_SYSLOG = "3"/g' \
			-e 's/TCP_IN = "20,21,22,25,53,80,110,143,443,465,587,993,995,2077,2078,2082,2083,2086,2087,2095,2096"/TCP_IN = "20,21,22,25,53,80,110,143,443,465,587,993,995,8080"/g' \
			-e 's/TCP_OUT = "20,21,22,25,37,43,53,80,110,113,443,587,873,993,995,2086,2087,2089,2703"/TCP_OUT = "20,21,22,25,37,43,53,80,110,113,443,465,587,873,993,995,8080"/g' \
			-e 's/TCP6_IN = "20,21,22,25,53,80,110,143,443,465,587,993,995,2077,2078,2082,2083,2086,2087,2095,2096"/TCP6_IN = "20,21,22,25,53,80,110,143,443,465,587,993,995,8080"/g' \
			-e 's/TCP6_OUT = "20,21,22,25,37,43,53,80,110,113,443,587,873,993,995,2086,2087,2089,2703"/TCP6_OUT = "20,21,22,25,37,43,53,80,110,113,443,465,587,873,993,995,8080"/g' \
			-e 's/DENY_TEMP_IP_LIMIT = "100"/DENY_TEMP_IP_LIMIT = "1000"/g' \
			-e 's/SMTP_ALLOWUSER = "cpanel"/SMTP_ALLOWUSER = "root"/g' \
			-e 's/PT_USERMEM = "200"/PT_USERMEM = "500"/g' \
			-e 's/PT_USERTIME = "1800"/PT_USERTIME = "7200"/g' /etc/csf/csf.conf
		echo "${OK}"
		# install sendmail as it's binary is required by CSF
		echo "${green}Installing Sendmail${normal} ... "
		apt-get -y install sendmail >>"${OUTTO}" 2>&1
		export DEBIAN_FRONTEND=noninteractive /usr/sbin/sendmailconfig >>"${OUTTO}" 2>&1
		# add administrator email
		echo "${magenta}${bold}Add an Administrator Email Below for Aliases Inclusion${normal}"
		read -rp "${bold}Email: ${normal}" admin_email
		echo "${bold}The email ${green}${bold}${admin_email}${normal} ${bold}is now the forwarding address for root mail${normal}"
		echo -n "${green}finalizing sendmail installation${normal} ... "
		# install aliases
		echo -e "mailer-daemon: postmaster
postmaster: root
nobody: root
hostmaster: root
usenet: root
news: root
webmaster: root
www: root
ftp: root
abuse: root
        root: ${admin_email}" >/etc/aliases
		newaliases >>"${OUTTO}" 2>&1
		echo "${OK}"
	fi
}

function _nocsf() {
	if [[ ${csf} == "no" ]]; then
		echo "${cyan}Skipping Config Server Firewall Installation${normal} ... "
	fi
}

# if you're using cloudlfare as a protection and/or cdn - this next bit is important
function _askcloudflare() {
	echo -n "${bold}${yellow}Would you like to whitelist CloudFlare IPs?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") cloudflare=yes ;;
	[nN] | [nN][Oo]) cloudflare=no ;;
	*)
		echo "Invalid input..."
		_askcloudflare
		;;
	esac
}

function _cloudflare() {
	if [[ ${cloudflare} == "yes" ]]; then
		echo -n "${green}Whitelisting Cloudflare IPs-v4 and -v6${normal} ... "
		echo -e "# BEGIN CLOUDFLARE WHITELIST
# ips-v4
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
104.16.0.0/12
108.162.192.0/18
131.0.72.0/22
141.101.64.0/18
162.158.0.0/15
172.64.0.0/13
173.245.48.0/20
188.114.96.0/20
190.93.240.0/20
197.234.240.0/22
198.41.128.0/17
199.27.128.0/21
# ips-v6
2400:cb00::/32
2405:8100::/32
2405:b500::/32
2606:4700::/32
2803:f800::/32
# END CLOUDFLARE WHITELIST
        " >>/etc/csf/csf.allow
		echo "${OK}"
	fi
}

# install sendmail function (16)
function _asksendmail() {
	echo -n "${bold}${yellow}Do you want to install Sendmail?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") sendmail=yes ;;
	[nN] | [nN][Oo]) sendmail=no ;;
	*)
		echo "Invalid input..."
		_asksendmail
		;;
	esac
}

function _sendmail() {
	if [[ ${sendmail} == "yes" ]]; then
		echo "${green}Installing Sendmail ... ${normal}"
		apt-get -y install sendmail >>"${OUTTO}" 2>&1
		export DEBIAN_FRONTEND=noninteractive | /usr/sbin/sendmailconfig >>"${OUTTO}" 2>&1
		# add administrator email
		echo "${magenta}Add an Administrator Email Below for Aliases Inclusion${normal}"
		read -rp "${bold}Email: ${normal}" admin_email
		echo
		echo "${bold}The email ${green}${bold}${admin_email}${normal} ${bold}is now the forwarding address for root mail${normal}"
		echo -n "${green}finalizing sendmail installation${normal} ... "
		# install aliases
		echo -e "mailer-daemon: postmaster
postmaster: root
nobody: root
hostmaster: root
usenet: root
news: root
webmaster: root
www: root
ftp: root
abuse: root
        root: ${admin_email}" >/etc/aliases
		newaliases >>"${OUTTO}" 2>&1
		echo "${OK}"
	fi
}

function _nosendmail() {
	if [[ ${sendmail} == "no" ]]; then
		echo "${cyan}Skipping Sendmail Installation...${normal}"
	fi
}

#################################################################
# The following security & enhancements cover basic security
# measures to protect against common exploits.
# Enhancements covered are adding cache busting, cross domain
# font support, expires tags and protecting system files.
#
# You can find the included files at the following directory...
# /etc/nginx/server.configs/
#
# Not all profiles are included, review your $sitename.conf
# for additions made by the script & adjust accordingly.
#################################################################

# Round 1 - Location
# enhance configuration function (17)
function _locenhance() {
	if [[ ${sitename} == "yes" ]]; then
		locconf1="include server.configs\/location\/cache-busting.conf;"
		sed -i "s/locconf1/${locconf1}/g" "/etc/nginx/conf.d/${site_path}.conf"
		locconf2="include server.configs\/location\/cross-domain-fonts.conf;"
		sed -i "s/locconf2/${locconf2}/g" "/etc/nginx/conf.d/${site_path}.conf"
		locconf3="include server.configs\/location\/expires.conf;"
		sed -i "s/locconf3/${locconf3}/g" "/etc/nginx/conf.d/${site_path}.conf"
		locconf4="include server.configs\/location\/protect-system-files.conf;"
		sed -i "s/locconf4/${locconf4}/g" "/etc/nginx/conf.d/${site_path}.conf"
		locconf5="include server.configs\/location\/letsencrypt.conf;"
		sed -i "s/locconf5/${locconf5}/g" "/etc/nginx/conf.d/${site_path}.conf"
	else
		locconf1="include server.configs\/location\/cache-busting.conf;"
		sed -i "s/locconf1/${locconf1}/g" "/etc/nginx/conf.d/${hostname1}.conf"
		locconf2="include server.configs\/location\/cross-domain-fonts.conf;"
		sed -i "s/locconf2/${locconf2}/g" "/etc/nginx/conf.d/${hostname1}.conf"
		locconf3="include server.configs\/location\/expires.conf;"
		sed -i "s/locconf3/${locconf3}/g" "/etc/nginx/conf.d/${hostname1}.conf"
		locconf4="include server.configs\/location\/protect-system-files.conf;"
		sed -i "s/locconf4/${locconf4}/g" "/etc/nginx/conf.d/${hostname1}.conf"
		locconf5="include server.configs\/location\/letsencrypt.conf;"
		sed -i "s/locconf5/${locconf5}/g" "/etc/nginx/conf.d/${hostname1}.conf"
	fi
	echo "${OK}"
}

# Round 2 - Security
# optimize security configuration function (18)
function _security() {
	if [[ ${sitename} == "yes" ]]; then
		secconf1="include server.configs\/directives\/sec-bad-bots.conf;"
		sed -i "s/secconf1/${secconf1}/g" "/etc/nginx/conf.d/${site_path}.conf"
		secconf2="include server.configs\/directives\/sec-file-injection.conf;"
		sed -i "s/secconf2/${secconf2}/g" "/etc/nginx/conf.d/${site_path}.conf"
		secconf3="include server.configs\/directives\/sec-php-easter-eggs.conf;"
		sed -i "s/secconf3/${secconf3}/g" "/etc/nginx/conf.d/${site_path}.conf"
	else
		secconf1="include server.configs\/directives\/sec-bad-bots.conf;"
		sed -i "s/secconf1/${secconf1}/g" "/etc/nginx/conf.d/${hostname1}.conf"
		secconf2="include server.configs\/directives\/sec-file-injection.conf;"
		sed -i "s/secconf2/${secconf2}/g" "/etc/nginx/conf.d/${hostname1}.conf"
		secconf3="include server.configs\/directives\/sec-php-easter-eggs.conf;"
		sed -i "s/secconf3/${secconf3}/g" "/etc/nginx/conf.d/${hostname1}.conf"
	fi
	echo "${OK}"
}

# create self-signed certificate function (19)
function _askcert() {
	echo -n "${bold}${yellow}Do you want to generate an SSL cert and configure HTTPS?${normal} (${bold}${green}Y${normal}/n): "
	read -r responce
	case ${responce} in
	[yY] | [yY][Ee][Ss] | "") cert=yes ;;
	[nN] | [nN][Oo]) cert=no ;;
	*)
		echo "${bold}${red}Invalid input...${normal}"
		_askcert
		;;
	esac
}

function _cert() {
	if [[ ${cert} == "yes" ]]; then
		if [[ ${sitename} == "yes" ]]; then
			# Using Lets Encrypt for SSL deployment is currently being developed on VStacklet
			#git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
			openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "/srv/www/${site_path}/ssl/${site_path}.key" -out "/srv/www/${site_path}/ssl/${site_path}.crt"
			chmod 400 "/etc/ssl/private/${site_path}.key"
			sed -i -e "s/# listen [::]:443 ssl http2;/listen [::]:443 ssl http2;/g" \
				-e "s/# listen *:443 ssl http2;/listen *:443 ssl http2;/g" \
				-e "s/# include vstacklet\/directive-only\/ssl.conf;/include vstacklet\/directive-only\/ssl.conf;/g" \
				-e "s/# ssl_certificate \/srv\/www\/sitename\/ssl\/sitename.crt;/ssl_certificate \/srv\/www\/${site_path}\/ssl\/${site_path}.crt;/g" \
				-e "s/# ssl_certificate_key \/srv\/www\/sitename\/ssl\/sitename.key;/ssl_certificate_key \/srv\/www\/${site_path}\/ssl\/${site_path}.key;/g" "/etc/nginx/conf.d/${site_path}.conf"
			sed -i "s/sitename/${site_path}/g" "/etc/nginx/conf.d/${site_path}.conf"
			#sed -i "s/sitename.crt/${site_path}_access/" /etc/nginx/conf.d/${site_path}.conf
			#sed -i "s/sitename.key/${site_path}_error/" /etc/nginx/conf.d/${site_path}.conf
			#sed -i "s/sitename.crt/${site_path}.crt/" /etc/nginx/conf.d/${site_path}.conf
			#sed -i "s/sitename.key/${site_path}.key/" /etc/nginx/conf.d/${site_path}.con
		else
			openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "/srv/www/${hostname1}/ssl/${hostname1}.key" -out "/srv/www/${hostname1}/ssl/${hostname1}.crt"
			chmod 400 "/etc/ssl/private/${hostname1}.key"
			sed -i -e "s/# listen [::]:443 ssl http2;/listen [::]:443 ssl http2;/g" \
				-e "s/# listen *:443 ssl http2;/listen *:443 ssl http2;/g" \
				-e "s/# include vstacklet\/directive-only\/ssl.conf;/include vstacklet\/directive-only\/ssl.conf;/g" \
				-e "s/# ssl_certificate \/srv\/www\/sitename\/ssl\/sitename.crt;/ssl_certificate \/srv\/www\/${hostname1}\/ssl\/${hostname1}.crt;/g" \
				-e "s/# ssl_certificate_key \/srv\/www\/sitename\/ssl\/sitename.key;/ssl_certificate_key \/srv\/www\/${hostname1}\/ssl\/${hostname1}.key;/g" "/etc/nginx/conf.d/${hostname1}.conf"
			sed -i "s/sitename/${hostname1}/" "/etc/nginx/conf.d/${hostname1}.conf"
			#sed -i "s/sitename_access/${hostname1}_access/" /etc/nginx/conf.d/${hostname1}.conf
			#sed -i "s/sitename_error/${hostname1}_error/" /etc/nginx/conf.d/${hostname1}.conf
			#sed -i "s/sitename.crt/${hostname1}.crt/" /etc/nginx/conf.d/${hostname1}.conf
			#sed -i "s/sitename.key/${hostname1}.key/" /etc/nginx/conf.d/${hostname1}.conf
		fi
		echo "${OK}"
	fi
}

function _nocert() {
	#  if [[ ${cert} == "no" ]]; then
	if [[ ${sitename} == "yes" ]]; then
		sed -i "s/sitename/${site_path}/g" "/etc/nginx/conf.d/${site_path}.conf"
		#sed -i "s/sitename.crt/${site_path}_access/" /etc/nginx/conf.d/${site_path}.conf
		#sed -i "s/sitename.key/${site_path}_error/" /etc/nginx/conf.d/${site_path}.conf
		#sed -i "s/sitename.crt/${site_path}.crt/" /etc/nginx/conf.d/${site_path}.conf
		#sed -i "s/sitename.key/${site_path}.key/" /etc/nginx/conf.d/${site_path}.conf
	else
		sed -i "s/sitename/${hostname1}/g" "/etc/nginx/conf.d/${hostname1}.conf"
		#sed -i "s/sitename.crt/${hostname1}_access/" /etc/nginx/conf.d/${hostname1}.conf
		#sed -i "s/sitename.key/${hostname1}_error/" /etc/nginx/conf.d/${hostname1}.conf
		#sed -i "s/sitename.crt/${hostname1}.crt/" /etc/nginx/conf.d/${hostname1}.conf
		#sed -i "s/sitename.key/${hostname1}.key/" /etc/nginx/conf.d/${hostname1}.conf
	fi
	#    echo "${cyan}Skipping SSL Certificate Creation...${normal}"
	#  fi
}

# finalize and restart services function (20)
function _services() {
	service apache2 stop >>"${OUTTO}" 2>&1
	for i in ssh nginx varnish php${PHPVERSION}-fpm; do
		service "${i}" restart >>"${OUTTO}" 2>&1
		systemctl enable "${i}" >>"${OUTTO}" 2>&1
	done
	if [[ ${sendmail} == "yes" ]]; then
		service sendmail restart >>"${OUTTO}" 2>&1
	fi
	if [[ ${csf} == "yes" ]]; then
		service lfd restart >>"${OUTTO}" 2>&1
		csf -r >>"${OUTTO}" 2>&1
	fi
	echo "${OK}"
	echo
}

# function to show finished data (21)
function _finished() {
	echo
	echo
	echo
	echo '                                /\                 '
	echo '                               /  \                '
	echo '                          ||  /    \               '
	echo '                          || /______\              '
	echo '                          |||        |             '
	echo '                         |  |        |             '
	echo '                         |  |        |             '
	echo '                         |__|________|             '
	echo '                         |___________|             '
	echo '                         |  |        |             '
	echo '                         |__|   ||   |\            '
	echo '                          |||   ||   | \           '
	echo '                         /|||   ||   |  \          '
	echo '                        /_|||...||...|___\         '
	echo '                          |||::::::::|             '
	echo "                ${standout}ENJOY${reset_standout}     || \::::::/              "
	echo '                o /       ||  ||__||               '
	echo '               /|         ||    ||                 '
	echo '               / \        ||     \\_______________ '
	echo '           _______________||______`--------------- '
	echo
	echo
	echo "${black}${on_green}    [vstacklet] Varnish LEMP Stack Installation Completed    ${normal}"
	echo
	echo "${bold}Visit ${green}http://${server_ip}/checkinfo.php${normal} ${bold}to verify your install. ${normal}"
	echo "${bold}Remember to remove the checkinfo.php file after verification. ${normal}"
	echo
	echo
	echo "${standout}INSTALLATION COMPLETED in ${FIN}/min ${normal}"
	echo
}

clear

spinner() {
	local pid=$1
	local delay=0.25
	# shellcheck disable=SC2034,SC1003,SC2086,SC2312
	local spinstr='|/-\' # / = forward slash, \ = backslash

	while "$(ps a -o pid | awk '{ print $1 }' | grep "${pid}")"; do
		local temp=${spinstr#?}
		printf " [${bold}${yellow}%c${normal}]  " "${spinstr}"
		local spinstr=${temp}${spinstr%"${temp}"}
		sleep "${delay}"
		printf "\b\b\b\b\b\b"
	done
	printf "    \b\b\b\b"
	echo -ne "${OK}"
}

local_setup=/etc/vstacklet/setup/
local_php8=/etc/vstacklet/php8/
local_php5=/etc/vstacklet/php5/
local_hhvm=/etc/vstacklet/hhvm/
local_nginx=/etc/vstacklet/nginx/
local_varnish=/etc/vstacklet/varnish/

S=$(date +%s)
OK=$(echo -e "[ ${bold}${green}DONE${normal} ]")

# VSTACKLET STRUCTURE
_intro
_checkroot
_logcheck
_hostname
_asksitename
if [[ ${sitename} == yes ]]; then
	_sitename
elif [[ ${sitename} == no ]]; then
	_nositename
fi
_bashrc
_askcontinue

# Begin installer prompts
_askvarnish
_askphpversion
if [[ ${PHPVERSION} == "8.1" ]]; then
	_askmemcached
fi
if [[ ${PHPVERSION} == "5.6" ]]; then
	_askioncube
fi
_askmariadb
_askphpmyadmin
_askcsf
if [[ ${csf} == "yes" ]]; then
	_askcloudflare
fi
if [[ ${csf} == "no" ]]; then
	_asksendmail
fi

#_locale;
echo -n "${bold}Installing Common Software Properties${normal} ... " && _softcommon
echo -n "${bold}Installing: nano, unzip, dos2unix, htop, iotop, libwww-perl${normal} ... " && _depends
echo -n "${bold}Installing signed keys for MariaDB, Nginx, PHP, HHVM and Varnish${normal} ... " && _keys
echo -n "${bold}Adding trusted repositories${normal} ... " && _repos
_updates

if [[ ${varnish} == "yes" ]]; then
	_varnish
elif [[ ${varnish} == "no" ]]; then
	_novarnish
fi

#_askphpversion;
if [[ ${PHPVERSION} == "8.1" ]]; then
	_php8
fi
if [[ ${PHPVERSION} == "5.6" ]]; then
	_php5
fi
if [[ ${PHPVERSION} == "HHVM" ]]; then
	_hhvm
fi
#if [[ "${PHPVERSION}" == "8.1" ]]; then
#_askmemcached;
if [[ ${memcached} == "yes" ]]; then
	_memcached
elif [[ ${memcached} == "no" ]]; then
	_nomemcached
fi
#fi
#if [[ "${PHPVERSION}" == "5.6" ]]; then
#_askioncube;
if [[ ${ioncube} == "yes" ]]; then
	_ioncube
elif [[ ${ioncube} == "no" ]]; then
	_noioncube
fi
#fi
echo -n "${bold}Installing and Configuring Nginx${normal} ... " && _nginx
echo -n "${bold}Adjusting Permissions${normal} ... " && _perms
#echo -n "${bold}Installing and Configuring Varnish${normal} ... ";_varnish;
#_askmariadb;
if [[ ${mariadb} == "yes" ]]; then
	echo -n "${bold}Installing MariaDB Drop-in Replacement${normal} ... " && _mariadb
elif [[ ${mariadb} == "no" ]]; then
	_nomariadb
fi
#_askphpmyadmin;
if [[ ${phpmyadmin} == "yes" ]]; then
	_phpmyadmin
elif [[ ${phpmyadmin} == "no" ]]; then
	_nophpmyadmin
fi
#_askcsf;
if [[ ${csf} == "yes" ]]; then
	_csf
elif [[ ${csf} == "no" ]]; then
	_nocsf
fi
#if [[ ${csf} == "yes" ]]; then
#_askcloudflare;
if [[ ${cloudflare} == "yes" ]]; then
	_cloudflare
fi
#fi
#if [[ ${csf} == "no" ]]; then
#_asksendmail;
if [[ ${sendmail} == "yes" ]]; then
	_sendmail
elif [[ ${sendmail} == "no" ]]; then
	_nosendmail
fi
#fi
echo "${bold}Addressing Location Edits: cache busting, cross domain font support,${normal}"
echo -n "${bold}expires tags, and system file protection${normal} ... " && _locenhance
echo "${bold}Performing Security Enhancements: protecting against bad bots,${normal}"
echo -n "${bold}file injection, and php easter eggs${normal} ... " && _security
#_askcert;
#if [[ ${cert} == "yes" ]]; then
#    _cert;
#elif [[ ${cert} == "no" ]]; then
_nocert
#fi
echo -n "${bold}Completing Installation & Restarting Services${normal} ... " && _services

E=$(date +%s)
DIFF=$(echo "${E}" - "${S}" | bc)
FIN=$(echo "${DIFF}" / 60 | bc)
_finished
