#!/bin/bash
set -e

BARRA="\033[1;36m-----------------------------------------------------\033[0m"
PACKAGES=(bc jq curl npm nodejs socat netcat netcat-traditional net-tools cowsay figlet lolcat)
PAQUETES_FAILED=()

# Verifica permisos de root
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[91mPor favor ejecuta este script como root (sudo).\033[0m"
    exit 1
fi

msg () {
    case $1 in
      -ne) echo -ne "\e[31m\e[1m${2}\e[0m";;
      -ama) echo -e "\e[33m\e[1m${2}\e[0m";;
      -verm) echo -e "\e[33m\e[1m[!] \e[31m${2}\e[0m";;
      -azu) echo -e "\033[1;36m\e[1m${2}\e[0m";;
      -verd) echo -e "\e[32m\e[1m${2}\e[0m";;
      -bra) echo -ne "\e[31m${2}\e[0m";;
      "-bar2"|"-bar") echo -e "\e[31m======================================================\e[0m";;
    esac
}

install_packages () {
    clear
    echo -e "$BARRA"
    echo -e "\033[92m        -- INSTALANDO PAQUETES NECESARIOS -- "
    echo -e "$BARRA"

    # Agrega repositorio universe si no está
    if ! grep -q "^deb .*universe" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        add-apt-repository universe -y
    fi

    apt update -y && apt upgrade -y

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
