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

# Verificar root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Este script debe ejecutarse como root${NC}"
    exit 1
fi

clear_screen() {
    clear
    echo -e "$BARRA"
    echo -e "${CYAN}              INSTALADOR V2RAY MANAGER${NC}"
    echo -e "$BARRA"
}

install_v2ray() {
    clear_screen
    echo -e "\n${GREEN}[*] Instalando V2Ray...${NC}"
    
    # Primero removemos cualquier instalación anterior
    systemctl stop v2ray 2>/dev/null
    systemctl disable v2ray 2>/dev/null
    rm -rf /etc/v2ray
    rm -rf /usr/local/bin/v2ray
    rm -rf /usr/bin/v2ray
    rm -rf /etc/systemd/system/v2ray.service
    
    # Instalamos V2Ray usando el instalador oficial
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] V2Ray instalado correctamente${NC}"
    else
        echo -e "${RED}[×] Error en la instalación de V2Ray${NC}"
        exit 1
    fi
}

create_config() {
    # Crear configuración básica de V2Ray
    cat > /etc/v2ray/config.json <<EOF
{
  "inbounds": [{
    "port": 10086,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$(uuid)",
          "alterId": 0
        }
      ]
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF

    # Crear script del menú
    cat > /usr/bin/v2ray-manager <<EOF
#!/bin/bash
bash /etc/v2ray/menu.sh
EOF
    chmod +x /usr/bin/v2ray-manager

    # Crear enlace simbólico
    ln -sf /usr/bin/v2ray-manager /usr/bin/v2ray
}

create_menu() {
    # Crear archivo de menú
    cat > /etc/v2ray/menu.sh <<EOF
#!/bin/bash
while true; do
    clear
    echo -e "$BARRA"
    echo -e "${CYAN}              PANEL DE CONTROL V2RAY${NC}"
    echo -e "$BARRA"
    echo -e "${GREEN}1.${NC} Iniciar V2Ray"
    echo -e "${GREEN}2.${NC} Detener V2Ray"
    echo -e "${GREEN}3.${NC} Reiniciar V2Ray"
    echo -e "${GREEN}4.${NC} Ver estado"
    echo -e "${GREEN}5.${NC} Ver configuración"
    echo -e "${GREEN}6.${NC} Modificar configuración"
    echo -e "${GREEN}7.${NC} Ver logs"
    echo -e "${RED}0.${NC} Salir"
    echo -e "$BARRA"
    read -p "Seleccione una opción: " option

    case \$option in
        1) systemctl start v2ray && echo -e "${GREEN}V2Ray iniciado${NC}" ;;
        2) systemctl stop v2ray && echo -e "${YELLOW}V2Ray detenido${NC}" ;;
        3) systemctl restart v2ray && echo -e "${GREEN}V2Ray reiniciado${NC}" ;;
        4) clear && systemctl status v2ray ;;
        5) clear && cat /etc/v2ray/config.json ;;
        6) nano /etc/v2ray/config.json && systemctl restart v2ray ;;
        7) journalctl -u v2ray --no-pager | tail -n 50 ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida${NC}" ;;
    esac
    read -n1 -r -p "Presione cualquier tecla para continuar..."
done
EOF
    chmod +x /etc/v2ray/menu.sh
}

# Inicio de la instalación
clear_screen
echo -e "\n${YELLOW}[*] Iniciando instalación de V2Ray...${NC}"

# Actualizar sistema
echo -e "\n${GREEN}[*] Actualizando sistema...${NC}"
apt update -y
apt upgrade -y

# Instalar dependencias
echo -e "\n${GREEN}[*] Instalando dependencias...${NC}"
apt install -y curl wget uuid-runtime unzip net-tools

# Instalar V2Ray
install_v2ray

# Crear configuración y menú
create_config
create_menu

# Iniciar servicio
systemctl enable v2ray
systemctl start v2ray

echo -e "\n${GREEN}[✓] Instalación completada${NC}"
echo -e "${YELLOW}[!] Use el comando 'v2ray' para acceder al panel de control${NC}"
echo -e "$BARRA"

# Ejecutar el menú
bash /etc/v2ray/menu.sh
