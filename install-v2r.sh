#!/bin/bash

# Colores
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
CYAN="\033[1;36m"
NC="\033[0m"
BARRA="${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Directorios
SCRIPT_DIR="/etc/v2ray"
CONFIG_DIR="/etc/v2ray"
LOG_FILE="/var/log/v2ray/install.log"

# Crear directorios necesarios
mkdir -p $SCRIPT_DIR
mkdir -p $CONFIG_DIR
mkdir -p $(dirname $LOG_FILE)
touch $LOG_FILE

print_center() {
    local text="$1"
    local color="${2:-$NC}"
    local width=$(tput cols)
    local padding=$(( ($width - ${#text}) / 2 ))
    printf "%${padding}s" ''
    echo -e "${color}${text}${NC}"
}

show_banner() {
    clear
    echo -e "$BARRA"
    print_center "BIENVENIDO A LA INSTALACIÓN DE V2RAY" "$CYAN"
    print_center "SCRIPT BY @SINNOMBRE22" "$YELLOW"
    echo -e "$BARRA"
}

install_dependencies() {
    show_banner
    echo -e "\n${GREEN}[*] Actualizando sistema...${NC}"
    apt update -y &>/dev/null
    apt upgrade -y &>/dev/null

    echo -e "\n${GREEN}[*] Instalando dependencias necesarias...${NC}"
    local packages=(curl wget socat uuid-runtime unzip net-tools python3 python3-pip)
    
    for package in "${packages[@]}"; do
        echo -ne "${YELLOW}Installing ${package}...${NC}"
        apt install -y $package &>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN} OK${NC}"
        else
            echo -e "${RED} FAILED${NC}"
            echo "Error instalando $package" >> $LOG_FILE
        fi
    done
}

install_v2ray() {
    show_banner
    echo -e "\n${GREEN}[*] Instalando V2Ray...${NC}"
    
    # Descargar script oficial de instalación
    echo -e "${YELLOW}Descargando script de instalación...${NC}"
    curl -sL https://multi.netlify.app/v2ray.sh -o v2ray_install.sh
    
    if [ ! -f "v2ray_install.sh" ]; then
        echo -e "${RED}Error: No se pudo descargar el script de instalación${NC}"
        exit 1
    fi
    
    # Dar permisos y ejecutar
    chmod +x v2ray_install.sh
    ./v2ray_install.sh --force
    
    # Verificar instalación
    if ! command -v v2ray &>/dev/null; then
        echo -e "${RED}Error: V2Ray no se instaló correctamente${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[✓] V2Ray instalado correctamente${NC}"
}

config_menu() {
    while true; do
        show_banner
        echo -e "\n${CYAN}PANEL DE CONFIGURACIÓN V2RAY${NC}\n"
        echo -e "${GREEN}1.${NC} Ver estado de V2Ray"
        echo -e "${GREEN}2.${NC} Iniciar V2Ray"
        echo -e "${GREEN}3.${NC} Detener V2Ray"
        echo -e "${GREEN}4.${NC} Reiniciar V2Ray"
        echo -e "${GREEN}5.${NC} Ver configuración actual"
        echo -e "${GREEN}6.${NC} Modificar configuración"
        echo -e "${GREEN}7.${NC} Ver logs"
        echo -e "${RED}0.${NC} Salir\n"
        echo -e "$BARRA"
        
        read -p "Seleccione una opción: " opt
        
        case $opt in
            1)
                clear
                echo -e "$BARRA"
                systemctl status v2ray
                read -n1 -r -p "Presione cualquier tecla para continuar..."
                ;;
            2)
                systemctl start v2ray
                echo -e "${GREEN}[✓] V2Ray iniciado${NC}"
                sleep 2
                ;;
            3)
                systemctl stop v2ray
                echo -e "${YELLOW}[!] V2Ray detenido${NC}"
                sleep 2
                ;;
            4)
                systemctl restart v2ray
                echo -e "${GREEN}[✓] V2Ray reiniciado${NC}"
                sleep 2
                ;;
            5)
                clear
                echo -e "$BARRA"
                cat /etc/v2ray/config.json
                echo -e "$BARRA"
                read -n1 -r -p "Presione cualquier tecla para continuar..."
                ;;
            6)
                nano /etc/v2ray/config.json
                systemctl restart v2ray
                ;;
            7)
                clear
                echo -e "$BARRA"
                journalctl -u v2ray --no-pager | tail -n 50
                echo -e "$BARRA"
                read -n1 -r -p "Presione cualquier tecla para continuar..."
                ;;
            0)
                echo -e "${YELLOW}¡Gracias por usar el script!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opción inválida${NC}"
                sleep 2
                ;;
        esac
    done
}

# Inicio del script
clear
show_banner
echo -e "\n${YELLOW}[!] Iniciando instalación de V2Ray...${NC}"
sleep 2

# Verificar si es root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Instalar componentes
install_dependencies
install_v2ray

# Crear acceso directo
echo '#!/bin/bash
bash /etc/v2ray/menu.sh
' > /usr/bin/v2ray
chmod +x /usr/bin/v2ray

# Guardar menú
cp "$0" /etc/v2ray/menu.sh
chmod +x /etc/v2ray/menu.sh

echo -e "\n${GREEN}[✓] Instalación completada${NC}"
echo -e "${YELLOW}[!] Use el comando 'v2ray' para acceder al panel de control${NC}"
sleep 3

# Mostrar panel de configuración
config_menu
