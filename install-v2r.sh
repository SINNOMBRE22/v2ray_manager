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

# Función para mostrar mensajes
msg() {
    echo -e "${1}"
}

# Verificar root
if [ "$(id -u)" != "0" ]; then
    msg "${RED}Este script debe ejecutarse como root${NC}"
    exit 1
fi

clear_screen() {
    clear
    echo -e "$BARRA"
    echo -e "${CYAN}              INSTALADOR V2RAY MANAGER${NC}"
    echo -e "$BARRA"
}

install_dependencies() {
    msg "\n${GREEN}[*] Instalando dependencias necesarias...${NC}"
    apt-get update -y
    apt-get install -y \
        curl \
        wget \
        socat \
        uuid-runtime \
        unzip \
        net-tools \
        python3 \
        python3-pip \
        jq \
        qrencode
}

install_v2ray() {
    clear_screen
    msg "\n${GREEN}[*] Instalando V2Ray...${NC}"
    
    # Remover instalaciones anteriores
    systemctl stop v2ray 2>/dev/null
    systemctl disable v2ray 2>/dev/null
    rm -rf /etc/v2ray
    rm -rf /usr/local/bin/v2ray
    rm -rf /usr/bin/v2ray
    rm -rf /etc/systemd/system/v2ray.service
    
    # Instalar V2Ray usando método alternativo
    mkdir -p /etc/v2ray
    mkdir -p /usr/local/bin
    
    # Descargar última versión de V2Ray
    local LATEST_VERSION=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases/latest | grep "tag_name" | cut -d'"' -f4)
    local DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/download/${LATEST_VERSION}/v2ray-linux-64.zip"
    
    wget -q --show-progress ${DOWNLOAD_URL} -O v2ray.zip
    unzip -q v2ray.zip -d /usr/local/bin/v2ray
    mv /usr/local/bin/v2ray/v2ray /usr/local/bin/
    mv /usr/local/bin/v2ray/v2ctl /usr/local/bin/
    chmod +x /usr/local/bin/v2ray
    chmod +x /usr/local/bin/v2ctl
    
    # Crear servicio systemd
    cat > /etc/systemd/system/v2ray.service <<EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray -config /etc/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

create_config() {
    local UUID=$(uuid)
    local PORT=10086
    
    # Crear configuración básica
    cat > /etc/v2ray/config.json <<EOF
{
  "inbounds": [{
    "port": ${PORT},
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "${UUID}",
        "alterId": 0
      }]
    },
    "streamSettings": {
      "network": "tcp"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF

    # Guardar información de conexión
    echo "V2Ray Connection Info:" > /etc/v2ray/info.txt
    echo "Port: ${PORT}" >> /etc/v2ray/info.txt
    echo "UUID: ${UUID}" >> /etc/v2ray/info.txt
}

create_manager() {
    # Crear script del menú
    cat > /usr/bin/v2ray <<EOF
#!/bin/bash
bash /etc/v2ray/menu.sh
EOF
    chmod +x /usr/bin/v2ray
}

create_menu() {
    cat > /etc/v2ray/menu.sh <<EOF
#!/bin/bash
export RED="\033[1;31m"
export GREEN="\033[1;32m"
export YELLOW="\033[1;33m"
export BLUE="\033[1;34m"
export PURPLE="\033[1;35m"
export CYAN="\033[1;36m"
export NC="\033[0m"
export BARRA="\${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"

show_connection_info() {
    clear
    echo -e "\$BARRA"
    echo -e "\${CYAN}         INFORMACIÓN DE CONEXIÓN V2RAY\${NC}"
    echo -e "\$BARRA"
    cat /etc/v2ray/info.txt
    echo -e "\$BARRA"
    read -n1 -r -p "Presione cualquier tecla para continuar..."
}

while true; do
    clear
    echo -e "\$BARRA"
    echo -e "\${CYAN}              PANEL DE CONTROL V2RAY\${NC}"
    echo -e "\$BARRA"
    echo -e "\${GREEN}1.\${NC} Ver información de conexión"
    echo -e "\${GREEN}2.\${NC} Iniciar V2Ray"
    echo -e "\${GREEN}3.\${NC} Detener V2Ray"
    echo -e "\${GREEN}4.\${NC} Reiniciar V2Ray"
    echo -e "\${GREEN}5.\${NC} Ver estado"
    echo -e "\${GREEN}6.\${NC} Ver configuración"
    echo -e "\${GREEN}7.\${NC} Modificar configuración"
    echo -e "\${GREEN}8.\${NC} Ver logs"
    echo -e "\${RED}0.\${NC} Salir"
    echo -e "\$BARRA"
    read -p "Seleccione una opción: " option

    case \$option in
        1) show_connection_info ;;
        2) systemctl start v2ray && echo -e "\${GREEN}V2Ray iniciado\${NC}" ;;
        3) systemctl stop v2ray && echo -e "\${YELLOW}V2Ray detenido\${NC}" ;;
        4) systemctl restart v2ray && echo -e "\${GREEN}V2Ray reiniciado\${NC}" ;;
        5) clear && systemctl status v2ray ;;
        6) clear && cat /etc/v2ray/config.json ;;
        7) nano /etc/v2ray/config.json && systemctl restart v2ray ;;
        8) journalctl -u v2ray --no-pager | tail -n 50 ;;
        0) break ;;
        *) echo -e "\${RED}Opción inválida\${NC}" ;;
    esac
    [ "\$option" != "1" ] && read -n1 -r -p "Presione cualquier tecla para continuar..."
done
EOF
    chmod +x /etc/v2ray/menu.sh
}

# Inicio de la instalación
clear_screen
msg "\n${YELLOW}[*] Iniciando instalación de V2Ray...${NC}"

# Instalar dependencias
install_dependencies

# Instalar V2Ray
install_v2ray

# Crear configuración y menú
create_config
create_manager
create_menu

# Iniciar servicio
systemctl enable v2ray
systemctl start v2ray

msg "\n${GREEN}[✓] Instalación completada${NC}"
msg "${YELLOW}[!] Use el comando 'v2ray' para acceder al panel de control${NC}"
msg "$BARRA"

# Mostrar información de conexión
cat /etc/v2ray/info.txt
echo -e "$BARRA"
read -n1 -r -p "Presione cualquier tecla para abrir el panel..."

# Ejecutar el menú
bash /etc/v2ray/menu.sh
