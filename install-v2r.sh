#!/bin/bash

BARRA="\033[1;36m-----------------------------------------------------\033[0m"
IVAR="/etc/http-instas"
SCPT_DIR="/etc/SCRIPT"
SCPinstal="$HOME/install"
rm $(pwd)/$0

add-apt-repository universe
apt update -y; apt upgrade -y

install_ini () {
  clear
  echo -e "$BARRA"
  echo -e "\033[92m        -- INSTALANDO PAQUETES NECESARIOS -- "
  echo -e "$BARRA"
  #bc
  [[ $(dpkg --get-selections|grep -w "bc"|head -1) ]] || apt-get install bc -y &>/dev/null
  [[ $(dpkg --get-selections|grep -w "bc"|head -1) ]] || ESTATUS=`echo -e "\033[91mFALLO DE INSTALACION"` &>/dev/null
  [[ $(dpkg --get-selections|grep -w "bc"|head -1) ]] && ESTATUS=`echo -e "\033[92mINSTALADO"` &>/dev/null
  echo -e "\033[97m  # apt-get install bc................... $ESTATUS "
  # Rest of the installation steps for other packages...
}

msg () {
  BRAN='\033[1;37m' && VERMELHO='\e[31m' && VERDE='\e[32m' && AMARELO='\e[33m'
  AZUL='\e[34m' && MAGENTA='\e[35m' && MAG='\033[1;36m' &&NEGRITO='\e[1m' && SEMCOR='\e[0m'
  case $1 in
    -ne)cor="${VERMELHO}${NEGRITO}" && echo -ne "${cor}${2}${SEMCOR}";;
    -ama)cor="${AMARELO}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}";;
    -verm)cor="${AMARELO}${NEGRITO}[!] ${VERMELHO}" && echo -e "${cor}${2}${SEMCOR}";;
    -azu)cor="${MAG}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}";;
    -verd)cor="${VERDE}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}";;
    -bra)cor="${VERMELHO}" && echo -ne "${cor}${2}${SEMCOR}";;
    "-bar2"|"-bar")cor="${VERMELHO}======================================================" && echo -e "${SEMCOR}${cor}${SEMCOR}";;
  esac
}

verificar_arq () {
  unset ARQ
  ARQ="/usr/bin/"
  if [[ ! -f ${ARQ}/$1 ]]; then
    mv -f ${SCPinstal}/$1 ${ARQ}/$1
    chmod +x ${ARQ}/$1
  fi
}

install_ini
clear
echo -e "$BARRA"
echo -e "\033[92m        -- INSTALANDO V2RAY -- "
echo -e "$BARRA"
sleep 2
curl -sL https://multi.netlify.app/v2ray.sh -o /usr/bin/v2r.sh
chmod +x /usr/bin/v2r.sh
clear
echo -e "$BARRA"
echo -e "\033[1;33m Perfecto, utilize el comando\n       \033[1;31mv2r.sh o v2r\n \033[1;33mpara administrar v2ray"
echo -e "$BARRA"
echo -ne "\033[0m"