#!/bin/bash

BARRA="\033[1;36m-----------------------------------------------------\033[0m"
SCPT_DIR="/etc/SCRIPT"
SCPinstal="$HOME/install"

add-apt-repository universe
apt update -y && apt upgrade -y

install_ini () {
clear
echo -e "$BARRA"
echo -e "\033[92m        -- INSTALANDO PAQUETES NECESARIOS -- "
echo -e "$BARRA"
PKGS=(bc jq curl npm nodejs socat netcat netcat-traditional net-tools cowsay figlet ruby)
for pkg in "${PKGS[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        apt-get install -y "$pkg" &>/dev/null
        if dpkg -s "$pkg" &>/dev/null; then
            ESTATUS="\033[92mINSTALADO"
        else
            ESTATUS="\033[91mFALLO DE INSTALACION"
        fi
    else
        ESTATUS="\033[92mINSTALADO"
    fi
    echo -e "\033[97m  # apt-get install $pkg................... $ESTATUS "
done
# lolcat puede instalarse por gem también
apt-get install -y lolcat &>/dev/null
gem install lolcat &>/dev/null
if dpkg -s lolcat &>/dev/null; then
    ESTATUS="\033[92mINSTALADO"
else
    ESTATUS="\033[91mFALLO DE INSTALACION"
fi
echo -e "\033[97m  # apt-get install lolcat............... $ESTATUS "
echo -e "$BARRA"
echo -e "\033[92m La instalacion de paquetes necesarios ha finalizado"
echo -e "$BARRA"
}

msg () {
BRAN='\033[1;37m' && VERMELHO='\e[31m' && VERDE='\e[32m' && AMARELO='\e[33m'
AZUL='\e[34m' && MAGENTA='\e[35m' && MAG='\033[1;36m' && NEGRITO='\e[1m' && SEMCOR='\e[0m'
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

meu_ip () {
MIP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
MIP2=$(wget -qO- ipv4.icanhazip.com)
[[ "$MIP" != "$MIP2" ]] && IP="$MIP2" || IP="$MIP"
}

install_v2ray () {
    echo -e "$BARRA"
    echo -e "\033[92m        -- INSTALANDO V2RAY -- "
    echo -e "$BARRA"
    bash <(curl -sL https://multi.netlify.app/v2ray.sh)
    echo -e "$BARRA"
    echo -e "\033[1;33m V2Ray instalado correctamente."
    echo -e "$BARRA"
}

panel_v2ray () {
    clear
    echo -e "$BARRA"
    figlet " Panel V2Ray " | lolcat
    echo -e "$BARRA"
    echo -e "\033[1;36m Bienvenido al panel de administración de V2Ray"
    echo -e "\033[1;37m 1) Ver estado del servicio V2Ray"
    echo -e " 2) Reiniciar V2Ray"
    echo -e " 3) Editar configuración (config.json)"
    echo -e " 4) Ver logs"
    echo -e " 0) Salir"
    echo -ne "\033[1;32mSeleccione una opción: \033[0m"
    read opcion
    case $opcion in
        1) systemctl status v2ray;;
        2) systemctl restart v2ray && echo -e "\033[1;32mV2Ray reiniciado\033[0m";;
        3) nano /etc/v2ray/config.json;;
        4) journalctl -u v2ray --no-pager | tail -n 50;;
        0) echo -e "\033[1;33mSaliendo del panel...\033[0m"; exit 0;;
        *) echo -e "\033[1;31mOpción inválida\033[0m";;
    esac
    echo -e "\033[1;33mPulse Enter para volver al panel...\033[0m"
    read
    panel_v2ray
}

# INICIO DEL SCRIPT
install_ini
meu_ip

clear
msg -bar2
figlet " -V2RAY-" | lolcat
msg -bar2
echo -e "\033[1;36mBienvenido a la instalación automatizada de V2Ray"
echo -e "\033[1;37mEste script instalará V2Ray y mostrará un panel para administrarlo."
echo -e "$BARRA"
sleep 2

install_v2ray

echo -e "$BARRA"
echo -e "\033[1;33m Perfecto, utilice el panel para administrar V2Ray "
echo -e "$BARRA"
sleep 2
panel_v2ray

rm -rf install-v2r.sh    apt update -y && apt upgrade -y

    for pkg in "${PACKAGES[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            apt-get install "$pkg" -y &>/dev/null
        fi
        if dpkg -s "$pkg" &>/dev/null; then
            ESTATUS="\033[92mINSTALADO"
        else
            ESTATUS="\033[91mFALLO DE INSTALACION"
            PAQUETES_FAILED+=("$pkg")
        fi
        echo -e "\033[97m  # apt-get install $pkg................... $ESTATUS \033[0m"
    done

    # lolcat: intenta instalar por gem si falla apt
    if ! command -v lolcat &>/dev/null; then
        if command -v gem &>/dev/null; then
            gem install lolcat &>/dev/null
            if command -v lolcat &>/dev/null; then
                echo -e "\033[97m  # gem install lolcat..................... \033[92mINSTALADO\033[0m"
            else
                echo -e "\033[97m  # gem install lolcat..................... \033[91mFALLO DE INSTALACION\033[0m"
                PAQUETES_FAILED+=("lolcat")
            fi
        fi
    fi

    echo -e "$BARRA"
    echo -e "\033[92m La instalación de paquetes necesarios ha finalizado"
    echo -e "$BARRA"
    if [ ${#PAQUETES_FAILED[@]} -gt 0 ]; then
        echo -e "\033[91m Fallaron los siguientes paquetes: ${PAQUETES_FAILED[*]}"
        echo -ne "\033[97m ¿Desea reintentar la instalación? [s/n]: "
        read -r inst
        if [[ $inst =~ ^[sSyY]$ ]]; then
            PAQUETES_FAILED=()
            install_packages
        fi
    fi
}

clear
msg -bar2
if command -v figlet &>/dev/null && command -v lolcat &>/dev/null; then
    figlet "Bienvenido" | lolcat
else
    echo -e "\033[92mBienvenido\033[0m"
fi
echo -e "$BARRA"
echo -e "\033[92m        -- Bienvenido al instalador V2RAY -- "
echo -e "$BARRA"
echo -e "\033[1;33m ¡La instalación de los paquetes ha comenzado!"
echo -e "$BARRA"
install_packages
