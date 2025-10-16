#!/usr/bin/env bash
# install-v2r.sh - Instalador y Administrador profesional de V2Ray
# Requiere: Debian/Ubuntu (apt), curl, wget, unzip, jq, qrencode, uuid-runtime
set -euo pipefail
IFS=$'\n\t'

# ---------------------------
# Configuración y constantes
# ---------------------------
SCRIPT_DIR="/etc/v2ray"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
INFO_FILE="${SCRIPT_DIR}/info.txt"
LOG_FILE="/var/log/v2ray/install.log"
SERVICE_FILE="/etc/systemd/system/v2ray.service"
BIN_DIR="/usr/local/bin"
V2RAY_BIN="${BIN_DIR}/v2ray"
V2CTL_BIN="${BIN_DIR}/v2ctl"
TMP_DIR="$(mktemp -d)"
DEFAULT_PORT=10086

# Colores
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
CYAN="\033[1;36m"
NC="\033[0m"
BARRA="${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Logging básico
log() {
    echo -e "[$(date '+%F %T')] $*" | tee -a "${LOG_FILE}"
}

# Limpieza al salir
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

# Manejo de errores
error_exit() {
    local rc=$?
    log "${RED}ERROR: Ocurrió un problema. Código de salida: ${rc}${NC}"
    echo -e "${RED}Revisa ${LOG_FILE} para más detalles.${NC}"
    exit "${rc}"
}
trap error_exit ERR

# ---------------------------
# Utilidades visuales
# ---------------------------

spinner() {
    # spinner <pid> <mensaje opcional>
    local pid=$1
    local msg="${2:-Procesando...}"
    local delay=0.08
    local spinstr='|/-\'
    printf " %s " "${msg}"
    while kill -0 "${pid}" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep "${delay}"
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo -e " ${GREEN}OK${NC}"
}

animated_banner() {
    local lines=(
"██╗   ██╗██╗   ██╗██████╗  █████╗ ██╗   ██╗    ███╗   ███╗ █████╗ ██╗   ██╗"
"██║   ██║██║   ██║██╔══██╗██╔══██╗██║   ██║    ████╗ ████║██╔══██╗██║   ██║"
"██║   ██║██║   ██║██████╔╝███████║██║   ██║    ██╔████╔██║███████║██║   ██║"
"╚██╗ ██╔╝██║   ██║██╔══██╗██╔══██║██║   ██║    ██║╚██╔╝██║██╔══██║╚██╗ ██╔╝"
" ╚████╔╝ ╚██████╔╝██║  ██║██║  ██║╚██████╔╝    ██║ ╚═╝ ██║██║  ██║ ╚████╔╝ "
"  ╚═══╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝     ╚═╝     ╚═╝╚═╝  ╚═╝  ╚═══╝  "
    )
    for l in "${lines[@]}"; do
        echo -e "${CYAN}${l}${NC}"
        sleep 0.04
    done
    echo -e "${BARRA}"
}

header() {
    clear
    animated_banner
    echo -e "${BLUE}${1:-Panel de administración v2Ray}${NC}"
    echo -e "${BARRA}"
}

prompt_confirm() {
    # prompt_confirm "Mensaje" (default: No)
    local msg="${1:-¿Continuar?}"
    read -rp "${msg} [y/N]: " -n 1 ans
    echo
    [[ "${ans,,}" = "y" ]]
}

# ---------------------------
# Comprobaciones iniciales
# ---------------------------
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Este script debe ejecutarse como root.${NC}"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
    else
        log "Sistema no soportado automáticamente. Continuando bajo su responsabilidad."
        OS="unknown"
    fi
}

# ---------------------------
# Dependencias
# ---------------------------
install_dependencies() {
    log "Instalando dependencias..."
    if [ "${OS}" = "debian" ] || [ "${OS}" = "unknown" ]; then
        apt-get update -y >>"${LOG_FILE}" 2>&1 &
        spinner $! "Actualizando repositorios..."
        apt-get install -y curl wget unzip jq qrencode uuid-runtime net-tools ca-certificates python3 python3-pip >>"${LOG_FILE}" 2>&1 &
        spinner $! "Instalando paquetes requeridos..."
    else
        log "Instalación de dependencias no automatizada para este SO."
    fi
}

# ---------------------------
# V2Ray: instalar, actualizar, desinstalar
# ---------------------------
get_latest_v2ray() {
    local api="https://api.github.com/repos/v2fly/v2ray-core/releases/latest"
    log "Obteniendo última versión de V2Ray..."
    local tag
    tag="$(curl -sSf "${api}" | jq -r '.tag_name' 2>/dev/null || true)"
    if [ -z "${tag}" ] || [ "${tag}" = "null" ]; then
        # fallback
        tag="$(curl -sSf "${api}" | grep '"tag_name"' | head -n1 | cut -d'"' -f4 || true)"
    fi
    echo "${tag}"
}

install_v2ray() {
    header "Instalando V2Ray"
    systemctl stop v2ray.service >/dev/null 2>&1 || true
    systemctl disable v2ray.service >/dev/null 2>&1 || true

    mkdir -p "${SCRIPT_DIR}" "${BIN_DIR}"
    rm -f "${TMP_DIR}/v2ray.zip"

    local tag
    tag="$(get_latest_v2ray)"
    if [ -z "${tag}" ]; then
        log "No fue posible obtener la versión más reciente. Abortando."
        exit 1
    fi
    log "Versión obtenida: ${tag}"

    local url="https://github.com/v2fly/v2ray-core/releases/download/${tag}/v2ray-linux-64.zip"
    log "Descargando ${url}..."
    wget -q --show-progress --progress=bar:force:noscroll -O "${TMP_DIR}/v2ray.zip" "${url}" 2>>"${LOG_FILE}" &
    spinner $! "Descargando v2ray ${tag}..."
    mkdir -p "${TMP_DIR}/v2ray"
    unzip -o "${TMP_DIR}/v2ray.zip" -d "${TMP_DIR}/v2ray" >/dev/null 2>&1
    mv -f "${TMP_DIR}/v2ray/v2ray" "${V2RAY_BIN}"
    mv -f "${TMP_DIR}/v2ray/v2ctl" "${V2CTL_BIN}"
    chmod +x "${V2RAY_BIN}" "${V2CTL_BIN}"
    log "Binarios instalados en ${BIN_DIR}"

    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=${V2RAY_BIN} -config ${CONFIG_FILE}
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable v2ray.service
    log "Servicio systemd creado y habilitado."
}

uninstall_v2ray() {
    header "Desinstalando V2Ray"
    if prompt_confirm "¿Desea desinstalar V2Ray y eliminar configuración (irreversible)?" ; then
        systemctl stop v2ray.service || true
        systemctl disable v2ray.service || true
        rm -f "${V2RAY_BIN}" "${V2CTL_BIN}" "${SERVICE_FILE}"
        rm -rf "${SCRIPT_DIR}"
        systemctl daemon-reload
        log "V2Ray desinstalado."
        echo -e "${GREEN}Desinstalación completa.${NC}"
    else
        echo "Operación cancelada."
    fi
}

update_v2ray() {
    header "Actualizando V2Ray"
    if prompt_confirm "¿Continuar con la actualización a la última versión?"; then
        install_v2ray
        systemctl restart v2ray.service || true
        log "Actualización finalizada."
        echo -e "${GREEN}V2Ray actualizado correctamente.${NC}"
    else
        echo "Actualización cancelada."
    fi
}

# ---------------------------
# Configuración y gestión de usuarios (vmess)
# ---------------------------
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

create_default_config() {
    header "Creando configuración por defecto"
    mkdir -p "${SCRIPT_DIR}"
    local uuid port
    uuid="$(generate_uuid)"
    port="${DEFAULT_PORT}"

    cat > "${CONFIG_FILE}" <<EOF
{
  "inbounds": [{
    "port": ${port},
    "listen": "0.0.0.0",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "${uuid}",
          "alterId": 0,
          "security": "auto"
        }
      ]
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

    echo "Port: ${port}" > "${INFO_FILE}"
    echo "UUID: ${uuid}" >> "${INFO_FILE}"
    echo "CreatedAt: $(date -Iseconds)" >> "${INFO_FILE}"
    log "Configuración inicial creada en ${CONFIG_FILE}"
}

backup_config() {
    header "Respaldo de configuración"
    local dest="/root/v2ray-config-backup-$(date +%F-%H%M%S).tar.gz"
    tar -czf "${dest}" -C / etc/v2ray 2>/dev/null || tar -czf "${dest}" -C "${SCRIPT_DIR}" .
    log "Respaldo guardado en ${dest}"
    echo -e "${GREEN}Backup creado: ${dest}${NC}"
}

restore_config() {
    header "Restaurar configuración"
    read -rp "Ruta al archivo .tar.gz de backup: " file
    if [ ! -f "${file}" ]; then
        echo -e "${RED}Archivo no encontrado.${NC}"
        return 1
    fi
    tar -xzf "${file}" -C / || tar -xzf "${file}" -C "${SCRIPT_DIR}"
    systemctl restart v2ray.service || true
    log "Restauración completada desde ${file}"
    echo -e "${GREEN}Restauración completada.${NC}"
}

add_vmess_user() {
    header "Agregar cliente Vmess"
    read -rp "Etiqueta para el cliente (ej. user1): " label
    read -rp "Puerto (ENTER para ${DEFAULT_PORT}): " port
    port="${port:-${DEFAULT_PORT}}"
    local uuid
    uuid="$(generate_uuid)"

    # Asegurarse de que config exista
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "${RED}No existe ${CONFIG_FILE}. Crear configuración por defecto primero.${NC}"
        return 1
    fi

    # Añadir cliente con jq
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}jq no está instalado. Imposible modificar JSON de forma segura.${NC}"
        return 1
    fi

    # Copia de seguridad del config actual
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak-$(date +%s)"

    # Insertar nuevo cliente (clientes se asumen en .inbounds[0].settings.clients)
    tmp="$(mktemp)"
    jq --arg id "${uuid}" '.inbounds[0].settings.clients += [{"id":$id,"alterId":0,"security":"auto"}]' "${CONFIG_FILE}" > "${tmp}" && mv "${tmp}" "${CONFIG_FILE}"

    # Escribir info
    local ip
    ip="$(curl -sS https://ifconfig.me || echo "IP_DESCONOCIDA")"
    local vmess_json
    vmess_json=$(jq -n --arg v "2" \
        --arg ps "${label}" \
        --arg add "${ip}" \
        --arg port "${port}" \
        --arg id "${uuid}" \
        --arg aid "0" \
        --arg net "tcp" \
        '{v:$v, ps:$ps, add:$add, port:$port, id:$id, aid:$aid, net:$net, type:"none", host:"", path:""}')
    local vmess_b64
    vmess_b64="$(echo -n "${vmess_json}" | base64 -w 0)"
    local vmess_link="vmess://${vmess_b64}"

    # Guardar en info
    echo -e "### Cliente: ${label} ###" >> "${INFO_FILE}"
    echo "Label: ${label}" >> "${INFO_FILE}"
    echo "Port: ${port}" >> "${INFO_FILE}"
    echo "UUID: ${uuid}" >> "${INFO_FILE}"
    echo "VMESS: ${vmess_link}" >> "${INFO_FILE}"
    echo "" >> "${INFO_FILE}"

    # Generar QR
    if command -v qrencode >/dev/null 2>&1; then
        local qrfile="/etc/v2ray/${label}_vmess_qr.png"
        echo -n "${vmess_link}" | qrencode -o "${qrfile}" -s 6 >/dev/null 2>&1 || true
        log "QR guardado en ${qrfile}"
        echo -e "${GREEN}Cliente agregado. Enlace vmess y QR creados.${NC}"
        echo "Enlace vmess: ${vmess_link}"
        echo "QR: ${qrfile}"
    else
        echo -e "${YELLOW}qrencode no disponible. Se creó el enlace vmess.${NC}"
        echo "Enlace vmess: ${vmess_link}"
    fi

    systemctl restart v2ray.service || true
}

remove_vmess_user() {
    header "Eliminar cliente Vmess"
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}jq no instalado.${NC}"
        return 1
    fi
    jq '.inbounds[0].settings.clients' "${CONFIG_FILE}"
    read -rp "Copie y pegue el UUID a eliminar: " uuid_del
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak-$(date +%s)"
    tmp="$(mktemp)"
    jq --arg id "${uuid_del}" '.inbounds[0].settings.clients |= map(select(.id != $id))' "${CONFIG_FILE}" > "${tmp}" && mv "${tmp}" "${CONFIG_FILE}"
    systemctl restart v2ray.service || true
    echo -e "${GREEN}Cliente eliminado (si existía).${NC}"
    log "Cliente ${uuid_del} eliminado si existía."
}

show_connection_info() {
    header "Información de conexión"
    if [ -f "${INFO_FILE}" ]; then
        cat "${INFO_FILE}"
    else
        echo -e "${YELLOW}No hay información guardada.${NC}"
    fi
    echo -e "${BARRA}"
    read -n1 -r -p "Presione cualquier tecla para continuar..."
}

# ---------------------------
# Herramientas de servicio y monitor
# ---------------------------
service_start() { systemctl start v2ray.service && log "Servicio iniciado." || log "Fallo al iniciar servicio."; }
service_stop()  { systemctl stop  v2ray.service && log "Servicio detenido." || log "Fallo al detener servicio."; }
service_restart(){ systemctl restart v2ray.service && log "Servicio reiniciado." || log "Fallo al reiniciar servicio."; }
service_status(){ systemctl status v2ray.service --no-pager || true; }

view_logs() {
    journalctl -u v2ray.service --no-pager | tail -n 200
}

tail_logs() {
    journalctl -u v2ray.service -f
}

show_config() {
    header "Configuración actual"
    if [ -f "${CONFIG_FILE}" ]; then
        jq . "${CONFIG_FILE}" || cat "${CONFIG_FILE}"
    else
        echo -e "${YELLOW}No existe configuración.${NC}"
    fi
    read -n1 -r -p "Presione cualquier tecla para continuar..."
}

edit_config() {
    header "Editar configuración"
    if ! command -v nano >/dev/null 2>&1 && ! command -v vi >/dev/null 2>&1; then
        echo -e "${YELLOW}No hay editor de texto instalado (nano/vi). Instalando nano...${NC}"
        apt-get install -y nano >>"${LOG_FILE}" 2>&1
    fi
    ${EDITOR:-nano} "${CONFIG_FILE}"
    systemctl restart v2ray.service || true
}

# ---------------------------
# Menú interactivo
# ---------------------------
main_menu() {
    while true; do
        header "Panel de Control v2Ray - Menú Principal"
        echo -e "${GREEN}1${NC}. Instalar / Reinstalar V2Ray"
        echo -e "${GREEN}2${NC}. Actualizar V2Ray"
        echo -e "${GREEN}3${NC}. Desinstalar V2Ray"
        echo -e "${GREEN}4${NC}. Crear configuración por defecto"
        echo -e "${GREEN}5${NC}. Agregar cliente (vmess)"
        echo -e "${GREEN}6${NC}. Eliminar cliente (vmess)"
        echo -e "${GREEN}7${NC}. Ver información de conexión"
        echo -e "${GREEN}8${NC}. Iniciar servicio"
        echo -e "${GREEN}9${NC}. Detener servicio"
        echo -e "${GREEN}10${NC}. Reiniciar servicio"
        echo -e "${GREEN}11${NC}. Estado del servicio"
        echo -e "${GREEN}12${NC}. Ver configuración"
        echo -e "${GREEN}13${NC}. Editar configuración"
        echo -e "${GREEN}14${NC}. Ver logs (últimas 200 líneas)"
        echo -e "${GREEN}15${NC}. Seguir logs (en vivo)"
        echo -e "${GREEN}16${NC}. Backup configuración"
        echo -e "${GREEN}17${NC}. Restaurar configuración"
        echo -e "${RED}0${NC}. Salir"
        echo -e "${BARRA}"
        read -rp "Selecciona una opción: " opt
        case "${opt}" in
            1) install_dependencies; install_v2ray; echo -e "${GREEN}Instalación completada.${NC}"; read -n1 -r -p "Presione cualquier tecla...";;
            2) update_v2ray; read -n1 -r -p "Presione cualquier tecla...";;
            3) uninstall_v2ray; read -n1 -r -p "Presione cualquier tecla...";;
            4) create_default_config; systemctl restart v2ray.service || true; read -n1 -r -p "Presione cualquier tecla...";;
            5) add_vmess_user; read -n1 -r -p "Presione cualquier tecla...";;
            6) remove_vmess_user; read -n1 -r -p "Presione cualquier tecla...";;
            7) show_connection_info;;
            8) service_start; read -n1 -r -p "Presione cualquier tecla...";;
            9) service_stop; read -n1 -r -p "Presione cualquier tecla...";;
            10) service_restart; read -n1 -r -p "Presione cualquier tecla...";;
            11) service_status; read -n1 -r -p "Presione cualquier tecla...";;
            12) show_config;;
            13) edit_config;;
            14) view_logs; read -n1 -r -p "Presione cualquier tecla...";;
            15) tail_logs;;
            16) backup_config; read -n1 -r -p "Presione cualquier tecla...";;
            17) restore_config; read -n1 -r -p "Presione cualquier tecla...";;
            0) echo -e "${GREEN}Saliendo...${NC}"; break;;
            *) echo -e "${RED}Opción inválida${NC}"; sleep 1;;
        esac
    done
}

# ---------------------------
# Inicio del script
# ---------------------------
ensure_root
detect_os
header "Iniciando instalador/administrador v2Ray"
log "Ejecución iniciada por $(whoami) en $(hostname)"

# Crear log file si no existe
touch "${LOG_FILE}"
chmod 640 "${LOG_FILE}"

# Si no existe v2ray instalado ni config, mostrar recomendación
if [ ! -f "${V2RAY_BIN}" ]; then
    echo -e "${YELLOW}V2Ray no detectado en ${V2RAY_BIN}.${NC}"
    if prompt_confirm "¿Desea instalar V2Ray ahora?"; then
        install_dependencies
        install_v2ray
    else
        echo "Puedes instalarlo más tarde desde este menú."
    fi
fi

# Crear script de acceso rápido /usr/bin/v2ray -> abre el menú
cat > /usr/bin/v2ray <<'EOF'
#!/usr/bin/env bash
bash /etc/v2ray/install-v2r.sh
EOF
chmod +x /usr/bin/v2ray || true

# Lanzar menú
main_menu

# Fin
log "Ejecución finalizada."
echo -e "${GREEN}Gracias por usar el instalador/administrador v2Ray.${NC}"
