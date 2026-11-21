#!/usr/bin/env bash
set -euo pipefail

# Desinstalador do Howdy (Desbloqueio Facial para KDE Plasma)
INSTALL_DIR="/usr/lib/security/howdy"
BIN_LINK="/usr/bin/howdy"
PAM_KDE="/etc/pam.d/kde"

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[AVISO]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERRO]\033[0m %s\n" "$*" >&2; }

if [[ "${EUID}" -ne 0 ]]; then
    error "Execute este desinstalador como root: sudo ./uninstall.sh"
    exit 1
fi

PURGE=false
if [[ "${1:-}" == "--purge" ]]; then
    PURGE=true
fi

# Remove entrada do Howdy em /etc/pam.d/kde
if [[ -f "${PAM_KDE}" ]]; then
    if grep -q "howdy/pam.py" "${PAM_KDE}"; then
        cp "${PAM_KDE}" "${PAM_KDE}.bak.uninstall"
        grep -v "howdy/pam.py" "${PAM_KDE}.bak.uninstall" > "${PAM_KDE}"
        info "Entrada do Howdy removida de ${PAM_KDE} (backup em ${PAM_KDE}.bak.uninstall)."
    else
        info "Nenhuma entrada do Howdy encontrada em ${PAM_KDE}."
    fi
fi

# Remove link simbólico /usr/bin/howdy
if [[ -L "${BIN_LINK}" ]] || [[ -f "${BIN_LINK}" ]]; then
    rm -f "${BIN_LINK}"
    info "Removido ${BIN_LINK}."
fi

# Remove diretório de instalação
if [[ -d "${INSTALL_DIR}" ]]; then
    if [[ "${PURGE}" == true ]]; then
        rm -rf "${INSTALL_DIR}"
        info "Removido completamente ${INSTALL_DIR} (incluindo modelos e config.ini)."
    else
        # Remove tudo exceto models/ se houver modelos salvos, a menos que usuário confirme
        if [[ -d "${INSTALL_DIR}/models" ]] && [[ -n "$(ls -A "${INSTALL_DIR}/models" 2>/dev/null)" ]]; then
            warn "Modelos faciais encontrados em ${INSTALL_DIR}/models."
            read -r -p "Deseja remover também os modelos faciais e configurações? [s/N] " resp
            if [[ "${resp,,}" == "s" || "${resp,,}" == "y" ]]; then
                rm -rf "${INSTALL_DIR}"
                info "Removido completamente ${INSTALL_DIR}."
            else
                find "${INSTALL_DIR}" -mindepth 1 -maxdepth 1 ! -name "models" ! -name "config.ini" -exec rm -rf {} +
                info "Binários e scripts removidos. Modelos e config.ini mantidos em ${INSTALL_DIR}."
            fi
        else
            rm -rf "${INSTALL_DIR}"
            info "Removido ${INSTALL_DIR}."
        fi
    fi
else
    info "Diretório ${INSTALL_DIR} não encontrado."
fi

echo ""
info "Desinstalação concluída!"
