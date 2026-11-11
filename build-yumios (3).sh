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
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1920 1080" width="1920" height="1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#fbf8ff"/>
      <stop offset="0.55" stop-color="#e4d8fb"/>
      <stop offset="1" stop-color="#b9a0ee"/>
    </linearGradient>
    <radialGradient id="glowL" cx="0.15" cy="0.2" r="0.55">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.9"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowR" cx="0.9" cy="0.95" r="0.5">
      <stop offset="0" stop-color="#8b5cf6" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#8b5cf6" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="r1" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.85"/>
      <stop offset="0.5" stop-color="#c9b0f7" stop-opacity="0.75"/>
      <stop offset="1" stop-color="#8b5cf6" stop-opacity="0.55"/>
    </linearGradient>
    <linearGradient id="r2" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#e9ddff" stop-opacity="0.9"/>
      <stop offset="1" stop-color="#9b72f0" stop-opacity="0.5"/>
    </linearGradient>
    <linearGradient id="r3" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="#7c4ddb" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0.7"/>
    </linearGradient>
    <path id="spark" d="M0,-40 C3,-10 10,-3 40,0 C10,3 3,10 0,40 C-3,10 -10,3 -40,0 C-10,-3 -3,-10 0,-40 Z"/>
    <filter id="glow" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="5"/></filter>
    <filter id="soft"><feGaussianBlur stdDeviation="1.2"/></filter>
  </defs>

  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#glowL)"/>
  <rect width="1920" height="1080" fill="url(#glowR)"/>

  <!-- cintas -->
  <path d="M-120,760 C260,360 640,1020 1060,640 S1700,180 2060,90 L2060,430 C1720,560 1340,1010 920,1010 S220,880 -120,1040 Z" fill="url(#r1)"/>
  <path d="M-120,520 C240,180 700,640 1000,420 S1560,-40 2040,-60 L2040,160 C1580,200 1260,700 900,760 S260,560 -120,760 Z" fill="url(#r2)"/>
  <path d="M520,1120 C760,780 1100,900 1380,700 S1800,420 2060,460 L2060,1120 Z" fill="url(#r3)"/>
  <path d="M-120,760 C260,360 640,1020 1060,640 S1700,180 2060,90" fill="none" stroke="#ffffff" stroke-opacity="0.7" stroke-width="3"/>

  <!-- destellos -->
  <g fill="#ffffff">
    <g filter="url(#glow)" opacity="0.9">
      <use href="#spark" transform="translate(180 210) scale(1.3)"/>
      <use href="#spark" transform="translate(560 520) scale(1.6)"/>
      <use href="#spark" transform="translate(900 760) scale(1.8)"/>
      <use href="#spark" transform="translate(1480 300) scale(1.2)"/>
      <use href="#spark" transform="translate(1700 800) scale(1.4)"/>
    </g>
    <use href="#spark" transform="translate(180 210) scale(1.3)"/>
    <use href="#spark" transform="translate(90 120) scale(0.5)"/>
    <use href="#spark" transform="translate(300 330) scale(0.35)"/>
    <use href="#spark" transform="translate(560 520) scale(1.6)"/>
    <use href="#spark" transform="translate(460 430) scale(0.4)"/>
    <use href="#spark" transform="translate(700 600) scale(0.55)"/>
    <use href="#spark" transform="translate(900 760) scale(1.8)"/>
    <use href="#spark" transform="translate(1010 850) scale(0.6)"/>
    <use href="#spark" transform="translate(1250 200) scale(0.45)"/>
    <use href="#spark" transform="translate(1480 300) scale(1.2)"/>
    <use href="#spark" transform="translate(1620 150) scale(0.5)"/>
    <use href="#spark" transform="translate(1700 800) scale(1.4)"/>
    <use href="#spark" transform="translate(1820 640) scale(0.45)"/>
    <use href="#spark" transform="translate(760 220) scale(0.3)"/>
  </g>

  <text x="110" y="960" font-family="'Noto Sans','DejaVu Sans',sans-serif" font-size="64" font-weight="700" fill="#5b2fb4" fill-opacity="0.55" letter-spacing="1">yumiOS</text>
</svg>
EOF

cat > "$INC/usr/share/backgrounds/yumios/yumios-lirio.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#120b24"/>
      <stop offset="0.5" stop-color="#2b1856"/>
      <stop offset="1" stop-color="#5a2a86"/>
    </linearGradient>
    <radialGradient id="halo" cx="0.70" cy="0.42" r="0.5">
      <stop offset="0" stop-color="#c9a6ff" stop-opacity="0.55"/>
      <stop offset="0.6" stop-color="#8b5cf6" stop-opacity="0.12"/>
      <stop offset="1" stop-color="#8b5cf6" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="petal" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="-340">
      <stop offset="0" stop-color="#f2e48a"/>
      <stop offset="0.18" stop-color="#fff6ea"/>
      <stop offset="0.7" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#f6d3ee"/>
    </linearGradient>
    <linearGradient id="petalBack" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="-340">
      <stop offset="0" stop-color="#d8c26a"/>
      <stop offset="0.25" stop-color="#e9dff2"/>
      <stop offset="1" stop-color="#d9b8ee"/>
    </linearGradient>
    <path id="p" d="M0,0 C78,-70 84,-240 0,-340 C-84,-240 -78,-70 0,0 Z"/>
    <path id="rib" d="M0,-18 C4,-120 3,-230 0,-318" fill="none" stroke="#c9a6d8" stroke-opacity="0.55" stroke-width="3" stroke-linecap="round"/>
    <filter id="blur"><feGaussianBlur stdDeviation="14"/></filter>
    <filter id="soft"><feGaussianBlur stdDeviation="2"/></filter>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="40"/>
    </filter>
  </defs>

  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#halo)"/>

  <!-- luces suaves (bokeh) -->
  <g fill="#ffffff" filter="url(#blur)">
    <circle cx="260" cy="240" r="70" fill-opacity="0.07"/>
    <circle cx="520" cy="820" r="110" fill-opacity="0.05"/>
    <circle cx="880" cy="140" r="50" fill-opacity="0.08"/>
    <circle cx="1740" cy="900" r="90" fill-opacity="0.06"/>
  </g>

  <!-- lirio pequeño de fondo, desenfocado -->
  <g transform="translate(1680 190) rotate(18) scale(0.42)" opacity="0.5" filter="url(#soft)">
    <g fill="url(#petalBack)">
      <use href="#p" transform="rotate(0)"/><use href="#p" transform="rotate(60)"/>
      <use href="#p" transform="rotate(120)"/><use href="#p" transform="rotate(180)"/>
      <use href="#p" transform="rotate(240)"/><use href="#p" transform="rotate(300)"/>
    </g>
  </g>

  <!-- sombra del lirio principal -->
  <ellipse cx="1345" cy="560" rx="300" ry="190" fill="#0d0618" opacity="0.28" filter="url(#shadow)"/>

  <!-- lirio principal -->
  <g transform="translate(1330 440) rotate(-14)">
    <!-- pétalos de atrás -->
    <g fill="url(#petalBack)">
      <use href="#p" transform="rotate(60) scale(0.98)"/>
      <use href="#p" transform="rotate(180) scale(0.98)"/>
      <use href="#p" transform="rotate(300) scale(0.98)"/>
    </g>
    <!-- pétalos delanteros -->
    <g fill="url(#petal)">
      <use href="#p" transform="rotate(0)"/>
      <use href="#p" transform="rotate(120)"/>
      <use href="#p" transform="rotate(240)"/>
    </g>
    <g>
      <use href="#rib" transform="rotate(0)"/>
      <use href="#rib" transform="rotate(120)"/>
      <use href="#rib" transform="rotate(240)"/>
    </g>
    <!-- garganta -->
    <circle r="44" fill="#f2e48a" fill-opacity="0.85" filter="url(#soft)"/>
    <!-- estambres -->
    <g stroke="#f7efd0" stroke-width="5" stroke-linecap="round" fill="none">
      <path d="M0,0 C14,-60 20,-110 24,-150"/>
      <path d="M0,0 C-30,-40 -62,-80 -92,-104"/>
      <path d="M0,0 C20,32 56,62 96,80"/>
      <path d="M0,0 C-14,40 -24,90 -20,142"/>
      <path d="M0,0 C-48,10 -100,10 -140,-6"/>
    </g>
    <g fill="#b4532a">
      <ellipse cx="24" cy="-156" rx="9" ry="26" transform="rotate(8 24 -156)"/>
      <ellipse cx="-96" cy="-108" rx="9" ry="26" transform="rotate(-52 -96 -108)"/>
      <ellipse cx="100" cy="82" rx="9" ry="26" transform="rotate(115 100 82)"/>
      <ellipse cx="-20" cy="148" rx="9" ry="26" transform="rotate(-4 -20 148)"/>
      <ellipse cx="-146" cy="-8" rx="9" ry="26" transform="rotate(-100 -146 -8)"/>
    </g>
    <path d="M0,0 C30,-26 70,-46 112,-54" stroke="#c7e9a8" stroke-width="6" stroke-linecap="round" fill="none"/>
    <circle cx="116" cy="-55" r="9" fill="#9bd07a"/>
  </g>

  <!-- marca -->
  <g font-family="'Noto Sans','DejaVu Sans',sans-serif" fill="#ffffff">
    <text x="120" y="930" font-size="76" font-weight="700" letter-spacing="1" fill-opacity="0.95">yumiOS</text>
    <text x="124" y="978" font-size="24" letter-spacing="7" fill-opacity="0.6">LIGERO · LIMPIO · TUYO</text>
  </g>
</svg>
EOF

# Logo de yumiOS (icono del menú de inicio)
mkdir -p "$INC/usr/share/icons/hicolor/scalable/apps"
cat > "$INC/usr/share/icons/hicolor/scalable/apps/yumios-logo.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#a78bfa"/>
      <stop offset="1" stop-color="#f472b6"/>
    </linearGradient>
    <path id="p" d="M0,0 C9,-8 10,-24 0,-30 C-10,-24 -9,-8 0,0 Z"/>
  </defs>
  <circle cx="32" cy="32" r="31" fill="url(#g)"/>
  <g transform="translate(32 33)" fill="#ffffff">
    <use href="#p" transform="rotate(0)"/>
    <use href="#p" transform="rotate(60)" fill-opacity="0.85"/>
    <use href="#p" transform="rotate(120)"/>
    <use href="#p" transform="rotate(180)" fill-opacity="0.85"/>
    <use href="#p" transform="rotate(240)"/>
    <use href="#p" transform="rotate(300)" fill-opacity="0.85"/>
  </g>
  <circle cx="32" cy="33" r="4" fill="#f2e48a"/>
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

cat > "$SKEL/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
  <property name="screen0" type="empty">
    <property name="monitorVirtual-1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitorVirtual1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitoreDP-1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitoreDP1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitorLVDS-1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitorLVDS1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitorHDMI-1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitorHDMI1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitorHDMI-A-1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitorDP-1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitorVGA-1" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
    <property name="monitor0" type="empty">
      <property name="workspace0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="image-style" type="int" value="5"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/yumios/yumios-default.png"/>
      </property>
    </property>
  </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="icon-size" type="uint" value="48"/>
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
      <property name="background-style" type="uint" value="1"/>
      <property name="background-rgba" type="array">
        <value type="double" value="0.07"/>
        <value type="double" value="0.04"/>
        <value type="double" value="0.15"/>
        <value type="double" value="0.82"/>
      </property>
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
button-icon=yumios-logo
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

# Tema propio del dock (Plank): píldora oscura translúcida con borde suave
mkdir -p "$INC/usr/share/plank/themes/yumi"
cat > "$INC/usr/share/plank/themes/yumi/dock.theme" <<'EOF'
[PlankTheme]
TopRoundness=24
BottomRoundness=24
LineWidth=1
OuterStrokeColor=255;;255;;255;;40
FillStartColor=28;;20;;48;;225
FillEndColor=28;;20;;48;;225
InnerStrokeColor=255;;255;;255;;18

[PlankDockTheme]
HorizPadding=6
TopPadding=4
BottomPadding=4
ItemPadding=8
IndicatorSize=5
IconShadowSize=0
UrgentBounceHeight=1.6667
LaunchBounceHeight=0.625
FadeOpacity=1
ClickTime=300
UrgentBounceTime=600
LaunchBounceTime=600
ActiveTime=300
SlideTime=300
FadeTime=250
HideTime=250
GlowSize=30
GlowTime=10000
GlowPulseTime=2000
UrgentHueShift=150
ItemMoveTime=450
CascadeHide=true
EOF

cat > "$INC/etc/dconf/profile/user" <<'EOF'
user-db:user
system-db:local
EOF

cat > "$INC/etc/dconf/db/local.d/00-yumios" <<'EOF'
[net/launchpad/plank/docks/dock1]
theme='yumi'
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
background=/usr/share/backgrounds/yumios/yumios-lirio.png
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

# Esperar un poco a que arranque el escritorio
sleep 3

# Fondo en todos los monitores conectados (y en los 4 primeros escritorios)
MONS=$(xrandr 2>/dev/null | awk '/ connected/{print $1}')
[ -z "$MONS" ] && MONS="Virtual-1 eDP-1 LVDS-1 HDMI-1"
for m in $MONS; do
  for ws in 0 1 2 3; do
    P="/backdrop/screen0/monitor$m/workspace$ws"
    xfconf-query -c xfce4-desktop -p "$P/last-image" -n -t string -s "$WP"
    xfconf-query -c xfce4-desktop -p "$P/image-style" -n -t int -s 5
  done
done
# Y en cualquier propiedad de fondo que ya exista
for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image$'); do
  xfconf-query -c xfce4-desktop -p "$p" -s "$WP"
done
xfdesktop --reload >/dev/null 2>&1 || true

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
  for f in /usr/share/backgrounds/yumios/*.svg; do
    rsvg-convert -w 2560 -h 1440 "$f" -o "${f%.svg}.png"
  done
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

# El instalador y el icono del escritorio dicen yumiOS, no Debian
grep -rlE 'Install Debian|Instalar Debian' /usr/share/applications /etc/skel /usr/share/calamares 2>/dev/null \
  | xargs -r sed -i -e 's/Install Debian/Instalar yumiOS/g' -e 's/Instalar Debian/Instalar yumiOS/g' || true

# Fondo de yumiOS como valor por defecto del sistema (además de /etc/skel)
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cp /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml \
   /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml || true

# Logo nuevo disponible para el tema de iconos
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

# Carpetas e iconos en violeta (recolorea el azul de Papirus; mejor esfuerzo)
for d in /usr/share/icons/Papirus /usr/share/icons/Papirus-Dark; do
  [ -d "$d" ] || continue
  find "$d" -name '*.svg' \( -name 'folder*' -o -name 'user-*' -o -name 'inode-directory*' \) -type f -print0 \
    | xargs -0 -r sed -i -e 's/#5294e2/#8b5cf6/gI' -e 's/#4877b1/#6d3fd1/gI' -e 's/#2e7bcf/#6d3fd1/gI' || true
  gtk-update-icon-cache -f "$d" 2>/dev/null || true
done

# Inicio de sesión: grupo y regla PAM para entrar sin contraseña, y teclado en español
getent group nopasswdlogin >/dev/null || groupadd -r nopasswdlogin
getent group autologin >/dev/null || groupadd -r autologin
if [ -f /etc/pam.d/lightdm ] && ! grep -q nopasswdlogin /etc/pam.d/lightdm; then
  sed -i '0,/^@include common-auth/s//auth    sufficient      pam_succeed_if.so user ingroup nopasswdlogin\n@include common-auth/' /etc/pam.d/lightdm
fi
cat > /etc/default/keyboard <<EOT
XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOT

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
