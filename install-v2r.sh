#!/usr/bin/env bash
# install-v2r.sh - Instalador y configurador de v2ray con menú configurable
# Ejecutar como root
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="/etc/v2ray"
MENU_CONF="${SCRIPT_DIR}/menu.conf"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
MENU_SH="${SCRIPT_DIR}/menu.sh"
WRAPPER="/usr/bin/v2ray"
LOG_FILE="/var/log/v2ray/install.log"
BIN_DIR="/usr/local/bin"
V2RAY_BIN="${BIN_DIR}/v2ray"
TMP_DIR="$(mktemp -d)"
DEFAULT_UUID="$(cat /proc/sys/kernel/random/uuid)"
DEFAULT_PORT=443

# Colores por defecto
DEFAULT_CYAN="\033[1;36m"
DEFAULT_GREEN="\033[1;32m"
DEFAULT_YELLOW="\033[1;33m"
DEFAULT_RED="\033[1;31m"
DEFAULT_NC="\033[0m"

log() {
  mkdir -p "$(dirname "${LOG_FILE}")"
  echo -e "[$(date '+%F %T')] $*" | tee -a "${LOG_FILE}"
}

cleanup(){ rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecuta como root"; exit 1
  fi
}

# Crea menu.conf con valores editables
create_menu_conf() {
  mkdir -p "${SCRIPT_DIR}"
  cat > "${MENU_CONF}" <<'EOF'
# /etc/v2ray/menu.conf - configuracion del menu y plantilla para config.json
# Edita estos valores y luego en el menú selecciona "Regenerar config desde plantilla"

# UI
BANNER_ENABLED=true
BANNER_COLOR="\033[1;36m"
BANNER_ANIM=true

# Colores del menu
COLOR_OK="\033[1;32m"
COLOR_WARN="\033[1;33m"
COLOR_ERROR="\033[1;31m"
COLOR_RESET="\033[0m"

# Config template values (ajusta según necesites)
PORT=443
UUID=REPLACE_UUID
ALTER_ID=2
NETWORK=ws
SECURITY=tls
CERT_FILE="/data/v2ray.crt"
KEY_FILE="/data/v2ray.key"
WS_PATH="/v2r/"
WS_HOST="dominio.com"
DOMAIN="argentina.gob.ar"

# Rutas de logs
ACCESS_LOG="/var/log/v2ray/access.log"
ERROR_LOG="/var/log/v2ray/error.log"
LOG_LEVEL="info"

# Menu options (puedes habilitar/deshabilitar acciones aquí)
ENABLE_ADD_USER=true
ENABLE_REMOVE_USER=true
ENABLE_BACKUP=true
ENABLE_RESTORE=true

EOF

  # Replace UUID placeholder
  sed -i "s|REPLACE_UUID|${DEFAULT_UUID}|" "${MENU_CONF}"
  chmod 600 "${MENU_CONF}"
  log "Se creó ${MENU_CONF}"
}

# Crea config.json usando variables de menu.conf
generate_config_from_template() {
  # cargar valores
  # shellcheck disable=SC1090
  source "${MENU_CONF}"

  mkdir -p "${SCRIPT_DIR}"
  cat > "${CONFIG_FILE}" <<EOF
{
  "log": {
    "access": "${ACCESS_LOG}",
    "error": "${ERROR_LOG}",
    "loglevel": "${LOG_LEVEL}"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "alterId": ${ALTER_ID},
            "id": "${UUID}"
          }
        ]
      },
      "streamSettings": {
        "network": "${NETWORK}",
        "security": "${SECURITY}",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${CERT_FILE}",
              "keyFile": "${KEY_FILE}"
            }
          ]
        },
        "tcpSettings": {},
        "kcpSettings": {},
        "httpSettings": {},
        "wsSettings": {
          "path": "${WS_PATH}",
          "headers": {
            "Host": "${WS_HOST}"
          }
        },
        "quicSettings": {}
      },
      "domain": "${DOMAIN}"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF
  chmod 640 "${CONFIG_FILE}"
  log "Se generó ${CONFIG_FILE} desde plantilla."
}

# Crea el menu.sh (usa banner animado y lee menu.conf)
create_menu_sh() {
  cat > "${MENU_SH}" <<'EOF'
#!/usr/bin/env bash
# /etc/v2ray/menu.sh - menú configurable para v2ray
set -euo pipefail
IFS=$'\n\t'

CONF="/etc/v2ray/menu.conf"
CONFIG="/etc/v2ray/config.json"
SERVICE="v2ray.service"
LOGFILE="/var/log/v2ray/install.log"

# Cargar configuración
if [ -f "${CONF}" ]; then
  # shellcheck disable=SC1090
  source "${CONF}"
else
  echo "No existe ${CONF}. Edita /etc/v2ray/menu.conf"
  exit 1
fi

BARRA="${BANNER_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"

animated_banner() {
  if [ "${BANNER_ANIM}" = "true" ]; then
    lines=(
"██╗   ██╗██╗   ██╗██████╗  █████╗ ██╗   ██╗    ███╗   ███╗ █████╗ ██╗   ██╗"
"██║   ██║██║   ██║██╔══██╗██╔══██╗██║   ██║    ████╗ ████║██╔══██╗██║   ██║"
"██║   ██║██║   ██║██████╔╝███████║██║   ██║    ██╔████╔██║███████║██║   ██║"
"╚██╗ ██╔╝██║   ██║██╔══██╗██╔══██║██║   ██║    ██║╚██╔╝██║██╔══██║╚██╗ ██╔╝"
" ╚████╔╝ ╚██████╔╝██║  ██║██║  ██║╚██████╔╝    ██║ ╚═╝ ██║██║  ██║ ╚████╔╝ "
"  ╚═══╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝     ╚═╝     ╚═╝╚═╝  ╚═╝  ╚═══╝  "
    )
    for l in "${lines[@]}"; do
      echo -e "${BANNER_COLOR}${l}${COLOR_RESET}"
      sleep 0.02
    done
  else
    echo -e "${BANNER_COLOR}v2Ray Manager${COLOR_RESET}"
  fi
  echo -e "${BARRA}"
}

pause(){ read -n1 -r -p "Presione cualquier tecla para continuar..."; }

show_info(){
  clear
  animated_banner
  echo -e "${BANNER_COLOR}         INFORMACIÓN DE CONFIGURACIÓN${COLOR_RESET}"
  echo -e "${BARRA}"
  if [ -f "${CONFIG}" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -r '.inbounds[0] | "Puerto: \(.port)\\nProtocolo: \(.protocol)\\nNetwork: \(.streamSettings.network)\\nSecurity: \(.streamSettings.security)\\nWS Path: \(.streamSettings.wsSettings.path)\\nHost Header: \(.streamSettings.wsSettings.headers.Host)"' "${CONFIG}" || cat "${CONFIG}"
    else
      cat "${CONFIG}"
    fi
  else
    echo -e "${COLOR_WARN}No existe ${CONFIG}${COLOR_RESET}"
  fi
  echo -e "${BARRA}"
  pause
}

regenerate_config(){
  echo -e "${COLOR_OK}Regenerando ${CONFIG} desde plantilla...${COLOR_RESET}"
  /bin/bash -c 'source "${CONF}"; /bin/cat > "${CONFIG}" <<EOF
$(sed -n '1,200p' "${CONFIG}" 2>/dev/null || true)
EOF' 2>/dev/null || true
  # Lógica: el script install-v2r.sh crea una función en el sistema para generar desde plantilla
  if command -v v2rays_template_gen >/dev/null 2>&1; then
    v2rays_template_gen
    systemctl restart "${SERVICE}" || true
    echo -e "${COLOR_OK}Configuración regenerada y servicio reiniciado.${COLOR_RESET}"
  else
    echo -e "${COLOR_WARN}No existe la herramienta de generación automática. Ejecuta el instalador para crearla.${COLOR_RESET}"
  fi
  pause
}

service_start(){ systemctl start "${SERVICE}" && echo -e "${COLOR_OK}Servicio iniciado${COLOR_RESET}" || echo -e "${COLOR_ERROR}No se pudo iniciar${COLOR_RESET}"; pause; }
service_stop(){ systemctl stop "${SERVICE}" && echo -e "${COLOR_WARN}Servicio detenido${COLOR_RESET}" || echo -e "${COLOR_ERROR}No se pudo detener${COLOR_RESET}"; pause; }
service_restart(){ systemctl restart "${SERVICE}" && echo -e "${COLOR_OK}Servicio reiniciado${COLOR_RESET}" || echo -e "${COLOR_ERROR}No se pudo reiniciar${COLOR_RESET}"; pause; }
service_status(){ clear; systemctl status "${SERVICE}" --no-pager || true; pause; }

view_config(){ clear; animated_banner; echo -e "${BANNER_COLOR} Config (${CONFIG}) ${COLOR_RESET}"; echo -e "${BARRA}"; if [ -f "${CONFIG}" ]; then jq . "${CONFIG}" || cat "${CONFIG}"; else echo "${COLOR_WARN}No existe config${COLOR_RESET}"; fi; echo -e "${BARRA}"; pause; }

edit_config(){
  if command -v nano >/dev/null 2>&1; then ${EDITOR:-nano} "${CONFIG}"; else ${EDITOR:-vi} "${CONFIG}"; fi
  systemctl restart "${SERVICE}" || true
}

edit_menu_conf(){
  if command -v nano >/dev/null 2>&1; then ${EDITOR:-nano} "${CONF}"; else ${EDITOR:-vi} "${CONF}"; fi
  echo -e "${COLOR_OK}Guardado. Si cambiaste valores, selecciona 'Regenerar config' para aplicar cambios.${COLOR_RESET}"
  pause
}

backup_config(){
  dest="/root/v2ray-config-backup-$(date +%F-%H%M%S).tar.gz"
  tar -czf "${dest}" -C / etc/v2ray 2>/dev/null || tar -czf "${dest}" -C "${SCRIPT_DIR}" .
  echo -e "${COLOR_OK}Backup creado en ${dest}${COLOR_RESET}"
  pause
}

restore_config(){
  read -rp "Ruta al backup (.tar.gz): " f
  if [ -f "${f}" ]; then tar -xzf "${f}" -C / || tar -xzf "${f}" -C "${SCRIPT_DIR}"; systemctl restart "${SERVICE}" || true; echo -e "${COLOR_OK}Restaurado${COLOR_RESET}"; else echo -e "${COLOR_ERROR}Archivo no encontrado${COLOR_RESET}"; fi
  pause
}

view_logs(){
  clear; animated_banner; echo -e "${BARRA}"; journalctl -u "${SERVICE}" --no-pager | tail -n 200 || true; echo -e "${BARRA}"; pause
}

add_vmess_user(){
  if [ "${ENABLE_ADD_USER}" != "true" ]; then echo "Función deshabilitada en menu.conf"; pause; return; fi
  read -rp "Etiqueta (ej: user1): " label
  read -rp "Generar UUID automáticamente? [Y/n]: " gen
  if [[ "${gen,,}" = "n" ]]; then read -rp "UUID: " uuid; else uuid=$(cat /proc/sys/kernel/random/uuid); fi
  cp "${CONFIG}" "${CONFIG}.bak-$(date +%s)"
  tmp="$(mktemp)"
  jq --arg id "${uuid}" '.inbounds[0].settings.clients += [{"id":$id,"alterId":2}]' "${CONFIG}" > "${tmp}" && mv "${tmp}" "${CONFIG}"
  systemctl restart "${SERVICE}" || true
  echo -e "${COLOR_OK}Cliente agregado: ${uuid}${COLOR_RESET}"
  pause
}

remove_vmess_user(){
  if [ "${ENABLE_REMOVE_USER}" != "true" ]; then echo "Función deshabilitada en menu.conf"; pause; return; fi
  jq -r '.inbounds[0].settings.clients[] | .id' "${CONFIG}" || true
  read -rp "UUID a eliminar: " u
  cp "${CONFIG}" "${CONFIG}.bak-$(date +%s)"
  tmp="$(mktemp)"
  jq --arg id "${u}" '.inbounds[0].settings.clients |= map(select(.id != $id))' "${CONFIG}" > "${tmp}" && mv "${tmp}" "${CONFIG}"
  systemctl restart "${SERVICE}" || true
  echo -e "${COLOR_OK}Eliminado (si existía)${COLOR_RESET}"
  pause
}

main_menu(){
  while true; do
    clear; animated_banner
    echo -e "${BARRA}"
    echo -e "${COLOR_OK}1${COLOR_RESET}. Ver información"
    echo -e "${COLOR_OK}2${COLOR_RESET}. Regenerar config desde plantilla"
    echo -e "${COLOR_OK}3${COLOR_RESET}. Editar plantilla/menu.conf"
    echo -e "${COLOR_OK}4${COLOR_RESET}. Editar config.json"
    echo -e "${COLOR_OK}5${COLOR_RESET}. Ver configuración"
    echo -e "${COLOR_OK}6${COLOR_RESET}. Añadir cliente vmess"
    echo -e "${COLOR_OK}7${COLOR_RESET}. Eliminar cliente vmess"
    echo -e "${COLOR_OK}8${COLOR_RESET}. Iniciar servicio"
    echo -e "${COLOR_OK}9${COLOR_RESET}. Detener servicio"
    echo -e "${COLOR_OK}10${COLOR_RESET}. Reiniciar servicio"
    echo -e "${COLOR_OK}11${COLOR_RESET}. Estado del servicio"
    echo -e "${COLOR_OK}12${COLOR_RESET}. Ver logs"
    echo -e "${COLOR_OK}13${COLOR_RESET}. Backup configuración"
    echo -e "${COLOR_OK}14${COLOR_RESET}. Restaurar configuración"
    echo -e "${COLOR_ERROR}0${COLOR_RESET}. Salir"
    echo -e "${BARRA}"
    read -rp "Selecciona: " opt
    case "${opt}" in
      1) show_info;;
      2) regenerate_config;;
      3) edit_menu_conf;;
      4) edit_config;;
      5) view_config;;
      6) add_vmess_user;;
      7) remove_vmess_user;;
      8) service_start;;
      9) service_stop;;
      10) service_restart;;
      11) service_status;;
      12) view_logs;;
      13) backup_config;;
      14) restore_config;;
      0) break;;
      *) echo "Opción inválida"; sleep 1;;
    esac
  done
}

main_menu
EOF

  chmod +x "${MENU_SH}"
  log "Se creó ${MENU_SH}"
}

# Crea wrapper /usr/bin/v2ray para ejecutar el menú
create_wrapper() {
  cat > "${WRAPPER}" <<'EOF'
#!/usr/bin/env bash
if [ -f /etc/v2ray/menu.sh ]; then
  exec bash /etc/v2ray/menu.sh
else
  echo "No existe /etc/v2ray/menu.sh. Ejecuta el instalador."
  exit 1
fi
EOF
  chmod +x "${WRAPPER}"
  log "Se creó wrapper ${WRAPPER}"
}

# Crea utilidad que genera config.json desde menu.conf (para uso por menú)
create_template_generator() {
  cat > /usr/bin/v2rays_template_gen <<'EOF'
#!/usr/bin/env bash
CONF="/etc/v2ray/menu.conf"
CONFIG="/etc/v2ray/config.json"
if [ ! -f "${CONF}" ]; then echo "No existe ${CONF}"; exit 1; fi
# shellcheck disable=SC1090
source "${CONF}"
cat > "${CONFIG}" <<EOF2
{
  "log": {
    "access": "${ACCESS_LOG}",
    "error": "${ERROR_LOG}",
    "loglevel": "${LOG_LEVEL}"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "alterId": ${ALTER_ID},
            "id": "${UUID}"
          }
        ]
      },
      "streamSettings": {
        "network": "${NETWORK}",
        "security": "${SECURITY}",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${CERT_FILE}",
              "keyFile": "${KEY_FILE}"
            }
          ]
        },
        "tcpSettings": {},
        "kcpSettings": {},
        "httpSettings": {},
        "wsSettings": {
          "path": "${WS_PATH}",
          "headers": {
            "Host": "${WS_HOST}"
          }
        },
        "quicSettings": {}
      },
      "domain": "${DOMAIN}"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF2
chmod 640 "${CONFIG}"
echo "OK"
EOF
  chmod +x /usr/bin/v2rays_template_gen
  log "Se creó /usr/bin/v2rays_template_gen"
}

# MAIN
ensure_root
mkdir -p "${SCRIPT_DIR}"
touch "${LOG_FILE}" && chmod 640 "${LOG_FILE}"

if [ ! -f "${MENU_CONF}" ]; then
  create_menu_conf
fi

create_menu_sh
create_wrapper
create_template_generator

# Generar config.json inicial si no existe
if [ ! -f "${CONFIG_FILE}" ]; then
  /usr/bin/v2rays_template_gen
  log "Config inicial creada."
fi

echo "Instalación completada. Ejecuta 'v2ray' para abrir el menú (o 'sudo v2ray')."{INFO_FILE}"
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
