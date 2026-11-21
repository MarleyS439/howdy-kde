#!/usr/bin/env bash
set -euo pipefail

# Instalador do Howdy (Desbloqueio Facial para KDE Plasma)
INSTALL_DIR="/usr/lib/security/howdy"
BIN_LINK="/usr/bin/howdy"
PAM_KDE="/etc/pam.d/kde"
PAM_LINE="auth       sufficient                  pam_python.so         /lib/security/howdy/pam.py"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[AVISO]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERRO]\033[0m %s\n" "$*" >&2; }

if [[ "${EUID}" -ne 0 ]]; then
    error "Execute este instalador como root: sudo ./install.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"

install_deps_arch() {
    info "Detectado sistema baseado em Arch Linux / CachyOS."
    info "Instalando dependências do sistema via pacman..."
    pacman -S --needed --noconfirm \
        python python-pip python-opencv python-numpy \
        libinih libevdev wget bzip2 cmake base-devel dlib

    # Verifica python-dlib
    if ! python3 -c "import dlib" 2>/dev/null; then
        info "Módulo Python 'dlib' não encontrado. Tentando instalar..."
        if [[ -n "$REAL_USER" ]] && command -v paru >/dev/null 2>&1; then
            su - "$REAL_USER" -c "paru -S --needed --noconfirm python-dlib" || true
        elif [[ -n "$REAL_USER" ]] && command -v yay >/dev/null 2>&1; then
            su - "$REAL_USER" -c "yay -S --needed --noconfirm python-dlib" || true
        fi

        if ! python3 -c "import dlib" 2>/dev/null; then
            warn "Instalando dlib via pip (--break-system-packages)..."
            python3 -m pip install --break-system-packages dlib
        fi
    fi

    # Verifica pam_python.so
    if [[ ! -f /usr/lib/security/pam_python.so ]] && [[ ! -f /lib/security/pam_python.so ]]; then
        warn "pam_python.so não encontrado em /usr/lib/security/."
        if [[ -n "$REAL_USER" ]] && command -v paru >/dev/null 2>&1; then
            info "Tentando instalar pam_python via paru..."
            su - "$REAL_USER" -c "paru -S --needed --noconfirm pam_python" || true
        elif [[ -n "$REAL_USER" ]] && command -v yay >/dev/null 2>&1; then
            info "Tentando instalar pam_python via yay..."
            su - "$REAL_USER" -c "yay -S --needed --noconfirm pam_python" || true
        fi
    fi
}

install_deps_debian() {
    info "Detectado sistema baseado em Debian / Ubuntu."
    apt-get update
    apt-get install -y \
        python3 python3-pip python3-opencv python3-numpy \
        libpam-python libinih-dev libevdev2 wget bzip2 cmake build-essential
    if ! python3 -c "import dlib" 2>/dev/null; then
        python3 -m pip install --break-system-packages dlib 2>/dev/null || python3 -m pip install dlib
    fi
}

install_deps_fedora() {
    info "Detectado sistema baseado em Fedora."
    dnf install -y \
        python3 python3-pip python3-opencv python3-numpy \
        inih libevdev wget bzip2 cmake gcc-c++
    if ! python3 -c "import dlib" 2>/dev/null; then
        python3 -m pip install --break-system-packages dlib 2>/dev/null || python3 -m pip install dlib
    fi
}

if command -v pacman >/dev/null 2>&1; then
    install_deps_arch
elif command -v apt-get >/dev/null 2>&1; then
    install_deps_debian
elif command -v dnf >/dev/null 2>&1; then
    install_deps_fedora
else
    warn "Gerenciador de pacotes não reconhecido. Certifique-se de instalar manualmente: python3, opencv, dlib, numpy, pam_python."
fi

info "Copiando arquivos do Howdy para ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"

# Preserva config.ini e models existentes se já instalados
if [[ -f "${INSTALL_DIR}/config.ini" ]]; then
    cp "${INSTALL_DIR}/config.ini" "${INSTALL_DIR}/config.ini.bak"
    info "Backup de config.ini salvo em ${INSTALL_DIR}/config.ini.bak"
fi

cp -r "${SCRIPT_DIR}/src/"* "${INSTALL_DIR}/"

mkdir -p "${INSTALL_DIR}/models" "${INSTALL_DIR}/snapshots"
chmod 755 "${INSTALL_DIR}" "${INSTALL_DIR}/cli.py" "${INSTALL_DIR}/pam.py"
chmod 1777 "${INSTALL_DIR}/snapshots"

ln -sf "${INSTALL_DIR}/cli.py" "${BIN_LINK}"
info "Link simbólico criado: ${BIN_LINK} -> ${INSTALL_DIR}/cli.py"

# Baixa os modelos do dlib se não existirem
if [[ ! -f "${INSTALL_DIR}/dlib-data/shape_predictor_5_face_landmarks.dat" ]] || \
   [[ ! -f "${INSTALL_DIR}/dlib-data/dlib_face_recognition_resnet_model_v1.dat" ]] || \
   [[ ! -f "${INSTALL_DIR}/dlib-data/mmod_human_face_detector.dat" ]]; then
    info "Baixando modelos de reconhecimento facial (dlib-data)..."
    (cd "${INSTALL_DIR}/dlib-data" && chmod +x install.sh && ./install.sh)
else
    info "Modelos dlib-data já estão presentes."
fi

# Configura PAM para tela de bloqueio do KDE
if [[ -f "${PAM_KDE}" ]]; then
    if grep -q "howdy/pam.py" "${PAM_KDE}"; then
        info "PAM do KDE (${PAM_KDE}) já está configurado para o Howdy."
    else
        cp "${PAM_KDE}" "${PAM_KDE}.bak.howdy"
        info "Backup criado: ${PAM_KDE}.bak.howdy"
        awk -v line="$PAM_LINE" '
            NR==1 && /^#%PAM/ { print; print line; next }
            NR==1 { print line; print; next }
            { print }
        ' "${PAM_KDE}.bak.howdy" > "${PAM_KDE}"
        info "Howdy adicionado em ${PAM_KDE}."
    fi
else
    warn "Arquivo ${PAM_KDE} não encontrado. Configure seu PAM manualmente com:"
    echo "    ${PAM_LINE}"
fi

# Verificação final das dependências Python
info "Verificando imports Python..."
if python3 -c "import cv2, dlib, numpy" 2>/dev/null; then
    info "Dependências Python (cv2, dlib, numpy) OK!"
else
    error "Falha ao importar dependências Python. Verifique manualmente: python3 -c 'import cv2, dlib, numpy'"
    exit 1
fi

if [[ ! -f /usr/lib/security/pam_python.so ]] && [[ ! -f /lib/security/pam_python.so ]]; then
    warn "Atenção: pam_python.so não foi encontrado. Instale 'pam_python' (AUR) para o PAM funcionar na tela de bloqueio."
fi

echo ""
info "Instalação concluída!"
echo "Próximos passos:"
echo "  1. Cadastre seu rosto:  sudo howdy add"
echo "  2. Teste a câmera:      sudo howdy test"
echo "  3. Bloqueie a tela do KDE e teste o desbloqueio facial."
