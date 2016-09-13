#!/bin/bash
#
# [VStacklet Varnish LEMP Stack Prep Script]
#
# GitHub:   https://github.com/JMSDOnline/vstacklet
# Author:   Jason Matthews
# URL:      https://jmsolodesigns.com/code-projects/vstacklet/varnish-lemp-stack
#
#################################################################################
server_ip=$(ifconfig | sed -n 's/.*inet addr:\([0-9.]\+\)\s.*/\1/p' | grep -v 127 | head -n 1);
hostname1=$(hostname -s);
#################################################################################
#Script Console Colors
green=$(tput setaf 2);yellow=$(tput setaf 3);cyan=$(tput setaf 6);
standout=$(tput smso);normal=$(tput sgr0);title=${standout};
#################################################################################
if [[ -f /usr/bin/lsb_release ]]; then
    DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
else [ -f "/etc/debian_version" ]; then
    DISTRO=='Debian'
fi
#################################################################################


# Create vstacklet & backup directory strucutre
mkdir -p /backup/{directories,databases}

# Download VStacklet System Backup Executable
chmod +x /etc/vstacklet/packages/backup/*
mv vs-backup /usr/local/bin
mv

function _string() { perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 15 ; }

function _askvstacklet() {
  echo
  echo
  echo "${title} Welcome to the VStacklet LEMP stack install kit! ${normal}"
  echo " version: ${VERSION}"
  echo
  echo "${bold} Enjoy the simplicity one script can provide to deliver ${normal}"
  echo "${bold} you the essentials of a finely tuned server environment.${normal}"
  echo "${bold} Nginx, Varnish, CSF, MariaDB w/ phpMyAdmin to name a few.${normal}"
  echo "${bold} Actively maintained and quality controlled.${normal}"
  echo
  echo
  echo -n "${bold}${yellow}Are you ready to install VStacklet for Ubuntu 16.04 & Debian 8?${normal} (${bold}${green}Y${normal}/n): "
  read responce
  case $responce in
    [yY] | [yY][Ee][Ss] | "" ) vstacklet=yes ;;
    [nN] | [nN][Oo] ) vstacklet=no ;;
  esac
}

clear

function _vstacklet() {
  if [[ ${vstacklet} == "yes" ]]; then
    DIR="/etc/vstacklet/setup/"
    if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
      . "${DIR}vstacklet-server-stack.sh"
  fi
}

function _novstacklet() {
  if [[ ${vstacklet} == "no" ]]; then
    echo "${bold}${cyan}Cancelling install. If you would like to run this installer in the future${normal}"
    echo "${bold}${cyan}type${normal} ${green}${bold}./etc/vstacklet/setup/vstacklet.sh${normal}"
    echo "${bold}${cyan}followed by tapping Enter on your keyboard.${normal}"
  fi
}

VERSION="3.1.0"

_askvstacklet;
if [[ ${vstacklet} == "yes" ]]; then
  echo -n "${bold}Installing VStacklet Kit for Ubuntu 16.04 & Debian 8 support${normal} ... ";_vstacklet;
elif [[ ${vstacklet} == "no" ]]; then
  _novstacklet;
fi
