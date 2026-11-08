#!/usr/bin/env bash
# =============================================================================
#  yumiOS - script de construcción de la ISO (versión ligera)
#  Base: Debian 13 "trixie" + XFCE + dock Plank
#  Pensado para equipos modestos (p. ej. Celeron N4000 con 4 GB de RAM).
#
#  Identidad propia:
#    - Barra superior fina (menú a la izquierda, reloj centrado, bandeja a la derecha)
#    - Dock inferior que se oculta solo (Plank)
#    - Tema oscuro Orchis con acento violeta, iconos Papirus, fondo propio
#    - zram + earlyoom para ir fluido con poca RAM
#    - Asistente de bienvenida "yumi-welcome"
#
#  Uso (en Debian/Ubuntu con internet y ~20 GB libres):
#      sudo ./build-yumios.sh              # configura y construye la ISO
#      sudo ./build-yumios.sh --no-build   # solo genera la configuración
# =============================================================================
set -euo pipefail

YUMI_NAME="yumiOS"
YUMI_VERSION="1.0"
YUMI_CODENAME="mochi"
DEBIAN_SUITE="trixie"
WORKDIR="${PWD}/yumios-build"
DO_BUILD=1
[[ "${1:-}" == "--no-build" ]] && DO_BUILD=0

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta este script con sudo (live-build necesita root)." >&2
  exit 1
fi

echo "==> Instalando herramientas de construcción..."
apt-get update
apt-get install -y live-build debootstrap squashfs-tools xorriso \
  isolinux syslinux-utils mtools dosfstools grub-pc-bin grub-efi-amd64-bin \
  grub-efi-amd64-signed shim-signed

mkdir -p "$WORKDIR"
cd "$WORKDIR"
lb clean --purge >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# 1) Configuración base de live-build
# -----------------------------------------------------------------------------
lb config \
  --distribution "$DEBIAN_SUITE" \
  --architectures amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer none \
  --bootloaders "syslinux,grub-efi" \
  --binary-images iso-hybrid \
  --linux-flavours amd64 \
  --security true --updates true \
  --iso-application "$YUMI_NAME" \
  --iso-publisher "$YUMI_NAME Project" \
  --iso-volume "${YUMI_NAME} ${YUMI_VERSION}" \
  --image-name "yumios" \
  --bootappend-live "boot=live components quiet splash username=yumi user-fullname=${YUMI_NAME} locales=es_ES.UTF-8 keyboard-layouts=es timezone=Europe/Madrid"

INC="config/includes.chroot"
mkdir -p config/package-lists config/hooks/live
mkdir -p "$INC/etc/dconf/profile" "$INC/etc/dconf/db/local.d"
mkdir -p "$INC/etc/lightdm/lightdm.conf.d"
mkdir -p "$INC/etc/default" "$INC/etc/sysctl.d"
mkdir -p "$INC/usr/share/backgrounds/yumios" "$INC/usr/share/yumios"
mkdir -p "$INC/usr/local/bin" "$INC/usr/share/applications"
SKEL="$INC/etc/skel/.config"
mkdir -p "$SKEL/xfce4/xfconf/xfce-perchannel-xml" "$SKEL/xfce4/panel"
mkdir -p "$SKEL/plank/dock1/launchers" "$SKEL/autostart" "$SKEL/gtk-3.0" "$SKEL/fastfetch"

# -----------------------------------------------------------------------------
# 2) Paquetes
# -----------------------------------------------------------------------------
cat > config/package-lists/yumios.list.chroot <<'EOF'
# --- Sistema gráfico y escritorio ligero ---
xorg
xfce4
xfce4-whiskermenu-plugin
xfce4-pulseaudio-plugin
xfce4-power-manager
xfce4-power-manager-plugins
xfce4-notifyd
xfce4-screenshooter
xfce4-taskmanager
xfce4-terminal
thunar
thunar-archive-plugin
thunar-volman
file-roller
mousepad
ristretto
plank
lxpolkit
lightdm
slick-greeter
# --- Red, audio, bluetooth ---
network-manager-gnome
blueman
pipewire-audio
pavucontrol
# --- Aspecto ---
orchis-gtk-theme
papirus-icon-theme
fonts-noto-core
fonts-noto-color-emoji
librsvg2-bin
zenity
# --- Aplicaciones cotidianas ---
firefox-esr
firefox-esr-l10n-es-es
celluloid
flatpak
gnome-software
gnome-software-plugin-flatpak
timeshift
synaptic
fastfetch
htop
git
curl
wget
# --- Rendimiento con poca RAM ---
zram-tools
earlyoom
# --- Firmware (wifi, etc.) y microcódigo Intel ---
firmware-linux
firmware-misc-nonfree
firmware-iwlwifi
firmware-realtek
firmware-atheros
intel-microcode
# --- Instalador gráfico ---
calamares
calamares-settings-debian
EOF

# -----------------------------------------------------------------------------
# 3) Fondo de pantalla propio (SVG; el hook lo convierte a PNG) y logo ASCII
# -----------------------------------------------------------------------------
cat > "$INC/usr/share/backgrounds/yumios/yumios-default.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1a1033"/>
      <stop offset="0.55" stop-color="#5b2e91"/>
      <stop offset="1" stop-color="#e86aa8"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.78" cy="0.22" r="0.6">
      <stop offset="0" stop-color="#ffd1e8" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#ffd1e8" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#glow)"/>
  <path d="M0 800 C 400 700, 700 900, 1100 800 S 1700 700, 1920 780 L1920 1080 L0 1080 Z" fill="#ffffff" fill-opacity="0.06"/>
  <path d="M0 880 C 350 800, 800 980, 1200 890 S 1700 820, 1920 900 L1920 1080 L0 1080 Z" fill="#ffffff" fill-opacity="0.08"/>
  <g fill="#ffffff" fill-opacity="0.92" font-family="sans-serif" text-anchor="middle">
    <text x="960" y="520" font-size="120" font-weight="700" letter-spacing="2">yumiOS</text>
    <text x="960" y="580" font-size="30" fill-opacity="0.7" letter-spacing="6">DULCE, LIGERO, TUYO</text>
  </g>
</svg>
EOF

cat > "$INC/usr/share/yumios/logo.txt" <<'EOF'
  __   __             _  ___  ____
  \ \ / /   _ _ __ ___ (_)/ _ \/ ___|
   \ V / | | | '_ ` _ \| | | | \___ \
    | || |_| | | | | | | | |_| |___) |
    |_| \__,_|_| |_| |_|_|\___/|____/
EOF

cat > "$SKEL/fastfetch/config.jsonc" <<'EOF'
{
  "logo": { "type": "file", "source": "/usr/share/yumios/logo.txt" },
  "modules": [
    "title", "separator", "os", "host", "kernel", "uptime", "packages",
    "shell", "de", "wm", "terminal", "cpu", "gpu", "memory", "disk"
  ]
}
EOF

# -----------------------------------------------------------------------------
# 4) Aspecto de XFCE (se copia a cada usuario nuevo desde /etc/skel)
# -----------------------------------------------------------------------------
cat > "$SKEL/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Orchis-Dark-Compact"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 10"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
</channel>
EOF

cat > "$SKEL/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Orchis-Dark-Compact"/>
    <property name="title_font" type="string" value="Noto Sans Bold 10"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="shadow_opacity" type="int" value="60"/>
    <property name="vblank_mode" type="string" value="auto"/>
  </property>
</channel>
EOF

cat > "$SKEL/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="true"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="icon-size" type="uint" value="16"/>
      <property name="size" type="uint" value="30"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
        <value type="int" value="8"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="clock">
      <property name="digital-layout" type="uint" value="3"/>
      <property name="digital-time-format" type="string" value="%a %e %b   %H:%M"/>
    </property>
    <property name="plugin-4" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-5" type="string" value="systray"/>
    <property name="plugin-6" type="string" value="pulseaudio"/>
    <property name="plugin-7" type="string" value="power-manager-plugin"/>
    <property name="plugin-8" type="string" value="actions"/>
  </property>
</channel>
EOF

cat > "$SKEL/xfce4/panel/whiskermenu-1.rc" <<'EOF'
button-icon=start-here
show-button-title=false
favorites=firefox-esr.desktop,thunar.desktop,xfce4-terminal.desktop,org.gnome.Software.desktop
EOF

# Acento violeta propio (mejor esfuerzo sobre el tema Orchis)
cat > "$SKEL/gtk-3.0/gtk.css" <<'EOF'
selection,
*:selected,
*:selected:focus {
  background-color: #8b5cf6;
  color: #ffffff;
}
button.suggested-action,
headerbar button.suggested-action {
  background-image: none;
  background-color: #8b5cf6;
  color: #ffffff;
}
switch:checked {
  background-image: none;
  background-color: #8b5cf6;
}
progressbar progress,
scale highlight,
scale fill {
  background-image: none;
  background-color: #8b5cf6;
}
check:checked,
radio:checked {
  background-image: none;
  background-color: #8b5cf6;
  color: #ffffff;
}
EOF

# -----------------------------------------------------------------------------
# 5) Dock Plank + arranque automático
# -----------------------------------------------------------------------------
mk_dockitem() {
  printf '[PlankDockItemPreferences]\nLauncher=file:///usr/share/applications/%s\n' "$2" \
    > "$SKEL/plank/dock1/launchers/$1.dockitem"
}
mk_dockitem firefox-esr    firefox-esr.desktop
mk_dockitem thunar         thunar.desktop
mk_dockitem terminal       xfce4-terminal.desktop
mk_dockitem store          org.gnome.Software.desktop
mk_dockitem settings       xfce-settings-manager.desktop

cat > "$SKEL/autostart/plank.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Plank
Exec=plank
X-GNOME-Autostart-enabled=true
EOF

cat > "$SKEL/autostart/yumi-first-login.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=yumiOS primer inicio
Exec=/usr/local/bin/yumi-first-login
X-GNOME-Autostart-enabled=true
EOF

cat > "$INC/etc/dconf/profile/user" <<'EOF'
user-db:user
system-db:local
EOF

cat > "$INC/etc/dconf/db/local.d/00-yumios" <<'EOF'
[net/launchpad/plank/docks/dock1]
theme='Transparent'
position='bottom'
alignment='center'
icon-size=44
hide-mode='window-dodge'
zoom-enabled=true
zoom-percent=135
dock-items=['firefox-esr.dockitem','thunar.dockitem','terminal.dockitem','store.dockitem','settings.dockitem']
EOF

# -----------------------------------------------------------------------------
# 6) Pantalla de inicio de sesión
# -----------------------------------------------------------------------------
cat > "$INC/etc/lightdm/lightdm.conf.d/50-yumios.conf" <<'EOF'
[Seat:*]
greeter-session=slick-greeter
user-session=xfce
EOF

cat > "$INC/etc/lightdm/slick-greeter.conf" <<'EOF'
[Greeter]
background=/usr/share/backgrounds/yumios/yumios-default.png
draw-user-backgrounds=false
theme-name=Orchis-Dark-Compact
icon-theme-name=Papirus-Dark
font-name=Noto Sans 11
show-a11y=false
show-keyboard=false
EOF

# -----------------------------------------------------------------------------
# 7) Rendimiento con poca RAM (zram + earlyoom)
# -----------------------------------------------------------------------------
cat > "$INC/etc/default/zramswap" <<'EOF'
ALGO=zstd
PERCENT=60
PRIORITY=100
EOF

cat > "$INC/etc/sysctl.d/99-yumios.conf" <<'EOF'
vm.swappiness=100
vm.vfs_cache_pressure=50
EOF

# -----------------------------------------------------------------------------
# 8) Herramientas propias: primer inicio y bienvenida
# -----------------------------------------------------------------------------
cat > "$INC/usr/local/bin/yumi-first-login" <<'EOF'
#!/bin/sh
# Se ejecuta una sola vez por usuario: pone el fondo y abre la bienvenida.
MARK="$HOME/.config/yumios/first-login-done"
[ -f "$MARK" ] && exit 0
WP=/usr/share/backgrounds/yumios/yumios-default.png
PROPS=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  PROPS=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image$' || true)
  [ -n "$PROPS" ] && break
  sleep 1
done
if [ -n "$PROPS" ]; then
  for p in $PROPS; do
    xfconf-query -c xfce4-desktop -p "$p" -s "$WP"
  done
else
  xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image \
    -n -t string -s "$WP"
fi
# Si el tema elegido no existe con ese nombre, usar la mejor alternativa instalada
for T in Orchis-Dark-Compact Orchis-Dark Adwaita-dark; do
  if [ -d "/usr/share/themes/$T" ]; then
    xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "$T"
    [ -d "/usr/share/themes/$T/xfwm4" ] && \
      xfconf-query -c xfwm4 -p /general/theme -n -t string -s "$T"
    break
  fi
done
mkdir -p "$(dirname "$MARK")"
touch "$MARK"
yumi-welcome &
EOF

cat > "$INC/usr/local/bin/yumi-welcome" <<'EOF'
#!/bin/bash
# Asistente de bienvenida de yumiOS
ITEMS=()
if grep -q 'boot=live' /proc/cmdline 2>/dev/null; then
  ITEMS+=("install" "Instalar yumiOS en este equipo")
fi
ITEMS+=(
  "update"   "Actualizar el sistema"
  "store"    "Abrir la tienda de aplicaciones"
  "backup"   "Crear un punto de restauración (Timeshift)"
  "settings" "Ajustes del sistema"
  "info"     "Información del sistema"
)
while true; do
  CHOICE=$(zenity --list --title="Bienvenida a yumiOS" \
    --text="Hola, ¿qué quieres hacer?" \
    --column="id" --column="Acción" --hide-column=1 --print-column=1 \
    --width=480 --height=400 "${ITEMS[@]}") || exit 0
  case "$CHOICE" in
    install)  sudo -E calamares & exit 0 ;;
    update)   xfce4-terminal --hold -e "sudo sh -c 'apt-get update && apt-get -y full-upgrade'" ;;
    store)    gnome-software & ;;
    backup)   sudo -E timeshift-launcher & ;;
    settings) xfce4-settings-manager & ;;
    info)     xfce4-terminal --hold -e fastfetch ;;
  esac
done
EOF
chmod +x "$INC/usr/local/bin/yumi-first-login" "$INC/usr/local/bin/yumi-welcome"

cat > "$INC/usr/share/applications/yumi-welcome.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Bienvenida a yumiOS
Comment=Asistente de bienvenida
Exec=yumi-welcome
Icon=start-here
Categories=System;Settings;
EOF

# -----------------------------------------------------------------------------
# 9) Hook: branding de sistema y ajustes finales dentro de la imagen
# -----------------------------------------------------------------------------
cat > config/hooks/live/0100-yumios-branding.hook.chroot <<EOF
#!/bin/sh
set -e

YUMI_NAME="${YUMI_NAME}"
YUMI_VERSION="${YUMI_VERSION}"
YUMI_CODENAME="${YUMI_CODENAME}"
EOF
cat >> config/hooks/live/0100-yumios-branding.hook.chroot <<'EOF'

# Evitar que futuras actualizaciones de base-files pisen nuestro os-release
dpkg-divert --quiet --divert /usr/lib/os-release.debian --rename /usr/lib/os-release || true

cat > /usr/lib/os-release <<EOT
PRETTY_NAME="${YUMI_NAME} ${YUMI_VERSION} (${YUMI_CODENAME})"
NAME="${YUMI_NAME}"
VERSION_ID="${YUMI_VERSION}"
VERSION="${YUMI_VERSION} (${YUMI_CODENAME})"
VERSION_CODENAME=${YUMI_CODENAME}
ID=yumios
ID_LIKE=debian
HOME_URL="https://example.com/yumios"
SUPPORT_URL="https://example.com/yumios/soporte"
BUG_REPORT_URL="https://example.com/yumios/bugs"
DEBIAN_CODENAME=trixie
EOT
ln -sf ../usr/lib/os-release /etc/os-release

cat > /etc/lsb-release <<EOT
DISTRIB_ID=${YUMI_NAME}
DISTRIB_RELEASE=${YUMI_VERSION}
DISTRIB_CODENAME=${YUMI_CODENAME}
DISTRIB_DESCRIPTION="${YUMI_NAME} ${YUMI_VERSION}"
EOT

echo "${YUMI_NAME} ${YUMI_VERSION} \\n \\l" > /etc/issue
echo "${YUMI_NAME} ${YUMI_VERSION}" > /etc/issue.net

# Fondo: SVG -> PNG 4K (más compatible con el escritorio y el greeter)
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 3840 -h 2160 \
    /usr/share/backgrounds/yumios/yumios-default.svg \
    -o /usr/share/backgrounds/yumios/yumios-default.png
fi

# Flathub activado de serie (mejor esfuerzo)
flatpak remote-add --system --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo || true

# La tienda no necesita arrancar sola en segundo plano (ahorra RAM)
rm -f /etc/xdg/autostart/org.gnome.Software.desktop

# Branding del instalador Calamares (mejor esfuerzo)
if [ -d /usr/share/calamares/branding ]; then
  grep -rl "Debian GNU/Linux" /usr/share/calamares/branding 2>/dev/null \
    | xargs -r sed -i "s#Debian GNU/Linux#${YUMI_NAME}#g" || true
fi

# Aplicar la base de datos de dconf
dconf update || true
EOF
chmod +x config/hooks/live/0100-yumios-branding.hook.chroot

echo "==> Configuración de yumiOS generada en: $WORKDIR"

# -----------------------------------------------------------------------------
# 10) Construcción
# -----------------------------------------------------------------------------
if [[ $DO_BUILD -eq 1 ]]; then
  echo "==> Construyendo la ISO (puede tardar 20-60 min)..."
  lb build
  ISO="$(ls -1 *.iso | head -n1)"
  OUT="${YUMI_NAME}-${YUMI_VERSION}-amd64.iso"
  mv "$ISO" "$OUT"
  echo "==> Listo: $WORKDIR/$OUT"
  echo "    Pruébala con:  qemu-system-x86_64 -m 4G -enable-kvm -cdrom $OUT"
else
  echo "==> Para construir:  cd $WORKDIR && sudo lb build"
fi
