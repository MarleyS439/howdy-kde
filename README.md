# Howdy KDE — Desbloqueio Facial para Linux (Arch / CachyOS / KDE Plasma)

Configuração e instalador completo do **Howdy** adaptado para desbloqueio facial na tela de bloqueio do **KDE Plasma** (`kscreenlocker` / PAM).

## Recursos

- Reconhecimento facial via câmera (`/dev/video0` por padrão) integrado ao PAM do KDE (`/etc/pam.d/kde`).
- Mensagem personalizada na tela de bloqueio (`"Digite sua senha"` ao atingir timeout).
- Instalador automatizado (`install.sh`) com detecção de dependências do sistema e Python (`dlib`, `opencv`, `numpy`, `pam_python`) e download dos modelos `dlib-data`.
- Desinstalador seguro (`uninstall.sh`) que limpa a configuração do PAM sem quebrar o login/desbloqueio por senha.

## Dependências

- Python 3
- `dlib` (módulo Python `python-dlib` ou via `pip`)
- `python-opencv` (`cv2`)
- `python-numpy` (`numpy`)
- `pam_python` (`/usr/lib/security/pam_python.so`)
- `libinih`, `libevdev`, `wget`/`curl`, `bzip2`, `cmake`

## Instalação

```bash
git clone https://github.com/MarleyS439/howdy-kde.git
cd howdy-kde
chmod +x install.sh uninstall.sh
sudo ./install.sh
```

Após instalar:

```bash
# Cadastrar seu rosto
sudo howdy add

# Testar a detecção da câmera
sudo howdy test
```

## Desinstalação

```bash
sudo ./uninstall.sh
```

Para remover tudo sem confirmação interativa (incluindo modelos faciais e `config.ini`):

```bash
sudo ./uninstall.sh --purge
```

## Solução de Problemas

### `ModuleNotFoundError: No module named 'dlib'`
Se o desbloqueio facial parar de funcionar após remover ou atualizar pacotes Python do sistema, reinstale o módulo `dlib`:

- No Arch / CachyOS (via AUR):
  ```bash
  paru -S python-dlib
  ```
- Ou via `pip`:
  ```bash
  sudo python3 -m pip install --break-system-packages dlib
  ```

### Verificando logs do PAM / tela de bloqueio
```bash
journalctl -b -g "howdy|pam_python|kwin_wayland_wrapper"
```

## Licença

MIT — baseado em [boltgolt/howdy](https://github.com/boltgolt/howdy). Consulte [LICENSE](LICENSE).
