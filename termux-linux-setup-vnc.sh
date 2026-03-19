#!/data/data/com.termux/files/usr/bin/bash
#######################################################
#  Termux Linux Setup Script (VNC Server)
#
#  Features:
#  - Choice of Desktop Environment (XFCE, LXQt, MATE, KDE)
#  - VNC Server for Remote Desktop Access
#  - Productivity and Media tools (VLC, Firefox)
#  - Python & Web Dev environment pre-installed
#  - Windows App Support (Wine/Hangover)
#######################################################

# ============== CONFIGURATION ==============
TOTAL_STEPS=11
CURRENT_STEP=0
DE_CHOICE="1"
DE_NAME="XFCE4"
VNC_DISPLAY=":1" # Default VNC display number

# ============== COLORS ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# ============== PROGRESS FUNCTIONS ==============
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))

    FILLED=$((PERCENT / 5))
    EMPTY=$((20 - FILLED))

    BAR="${GREEN}"
    for ((i=0; i<FILLED; i++)); do BAR+="*"; done
    BAR+="${GRAY}"
    for ((i=0; i<EMPTY; i++)); do BAR+="-"; done
    BAR+="${NC}"

    echo ""
    echo -e "${WHITE}------------------------------------------------------------${NC}"
    echo -e "${CYAN}  OVERALL PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}------------------------------------------------------------${NC}"
    echo ""
}

spinner() {
    local pid=$1
    local message=$2
    local spin='-\|/'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r  [*] ${message} ${CYAN}${spin:$i:1}${NC}  "
        sleep 0.1
    done

    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "\r  [+] ${message}                    \n"
    else
        printf "\r  [-] ${message} ${RED}(failed)${NC}     \n"
    fi

    return $exit_code
}

install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}
    (DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confold" $pkg > /dev/null 2>&1) &
    spinner $! "Installing ${name}..."
}

# ============== BANNER ==============
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    -------------------------------------------

            Termux Linux Setup Script
            (VNC Server Edition)

    -------------------------------------------
BANNER
    echo -e "${NC}"
    echo ""
}

# ============== DEVICE & USER SELECTION ==============
setup_environment() {
    echo -e "${PURPLE}[*] Detecting your device...${NC}"
    echo ""

    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    CPU_ABI=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a")
    # GPU detection is less critical for VNC as rendering happens on the server
    # However, keeping it for general info and potential future local X11 uses
    GPU_VENDOR=$(getprop ro.hardware.egl 2>/dev/null || echo "")

    echo -e "  [*] Device: ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  [*] Android: ${WHITE}${ANDROID_VERSION}${NC}"

    if [[ "$GPU_VENDOR" == *"adreno"* ]] || [[ "$DEVICE_BRAND" == *"samsung"* ]] || [[ "$DEVICE_BRAND" == *"Samsung"* ]] || [[ "$DEVICE_BRAND" == *"oneplus"* ]] || [[ "$DEVICE_BRAND" == *"xiaomi"* ]]; then
        GPU_DRIVER="freedreno"
        echo -e "  [*] GPU: ${WHITE}Adreno (Qualcomm) - Hardware Acceleration Supported (for local apps)${NC}"
    else
        GPU_DRIVER="zink_native"
        echo -e "  [*] GPU: ${WHITE}Non-Adreno - Zink Native Vulkan (for local apps)${NC}"
        echo -e "${YELLOW}      [!] VNC performance relies less on local GPU, but lighter DEs are still recommended for overall system snappiness.${NC}"
    fi
    echo ""

    echo -e "${CYAN}Please choose your Desktop Environment:${NC}"
    echo -e "  ${WHITE}1) XFCE4${NC}       (Recommended - Fast, Customizable, macOS style dock)"
    echo -e "  ${WHITE}2) LXQt${NC}        (Ultra lightweight - Best for low end devices)"
    echo -e "  ${WHITE}3) MATE${NC}        (Classic UI, moderately heavy)"
    echo -e "  ${WHITE}4) KDE Plasma${NC}  (Very heavy - Modern, Windows 11 style, requires strong GPU/RAM)"
    echo ""
    while true; do
        read -p "Enter number (1-4) [default: 1]: " DE_INPUT
        DE_INPUT=${DE_INPUT:-1}
        if [[ "$DE_INPUT" =~ ^[1-4]$ ]]; then
            DE_CHOICE="$DE_INPUT"
            break
        else
            echo "Invalid input. Please enter 1, 2, 3, or 4."
        fi
    done

    case $DE_CHOICE in
        1) DE_NAME="XFCE4";;
        2) DE_NAME="LXQt";;
        3) DE_NAME="MATE";;
        4) DE_NAME="KDE Plasma";;
    esac

    echo -e "\n${GREEN}[+] Selected: ${DE_NAME}.${NC}"
    sleep 2
}

# ============== STEP 1: UPDATE SYSTEM ==============
step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating system packages...${NC}"
    echo ""
    (DEBIAN_FRONTEND=noninteractive apt-get update -y > /dev/null 2>&1) &
    spinner $! "Updating package lists..."
    (DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q -o Dpkg::Options::="--force-confold" > /dev/null 2>&1) &
    spinner $! "Upgrading installed packages..."
}

# ============== STEP 2: INSTALL REPOSITORIES ==============
step_repos() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Adding package repositories...${NC}"
    echo ""
    install_pkg "tur-repo" "TUR Repository (Firefox)"
}

# ============== STEP 3: INSTALL VNC SERVER ==============
step_vnc() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing VNC Server...${NC}"
    echo ""
    install_pkg "tigervnc" "TigerVNC Server"
    echo -e "\n${YELLOW}[!] You will be prompted to set a VNC password.${NC}"
    echo -e "${YELLOW}    Remember this password for connecting to your desktop.${NC}"
    vncpasswd
    echo -e "  [+] VNC password set."

    # Create xstartup file for VNC
    mkdir -p ~/.vnc
    cat > ~/.vnc/xstartup << VNCSTARTUPEOF
#!/data/data/com.termux/files/usr/bin/bash
xrdb \$HOME/.Xresources
# For some DEs, specific setup might be needed
# Source GPU config for local rendering if needed, though VNC is software rendered by default
source \$HOME/.config/linux-gpu.sh 2>/dev/null

# Clean environment variables that can interfere with VNC session
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

case "${DE_CHOICE}" in
    1) # XFCE4
        xfce4-session
        ;;
    2) # LXQt
        startlxqt
        ;;
    3) # MATE
        mate-session
        ;;
    4) # KDE Plasma
        startplasma-x11
        ;;
esac
VNCSTARTUPEOF
    chmod +x ~/.vnc/xstartup
    echo -e "  [+] Created ~/.vnc/xstartup for ${DE_NAME}."
}

# ============== STEP 4: INSTALL DESKTOP ==============
step_desktop() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing ${DE_NAME} Desktop...${NC}"
    echo ""

    if [ "$DE_CHOICE" == "1" ]; then
        # XFCE
        install_pkg "xfce4" "XFCE4 Desktop"
        install_pkg "xfce4-terminal" "XFCE4 Terminal"
        install_pkg "xfce4-whiskermenu-plugin" "Whisker Menu"
        install_pkg "plank-reloaded" "Plank Dock"
        install_pkg "thunar" "Thunar File Manager"
        install_pkg "mousepad" "Mousepad Editor"
    elif [ "$DE_CHOICE" == "2" ]; then
        # LXQt
        install_pkg "lxqt" "LXQt Desktop"
        install_pkg "qterminal" "QTerminal"
        install_pkg "pcmanfm-qt" "PCManFM-Qt"
        install_pkg "featherpad" "FeatherPad"
    elif [ "$DE_CHOICE" == "3" ]; then
        # MATE
        install_pkg "mate" "MATE Desktop"
        install_pkg "mate-tweak" "MATE Tweak"
        install_pkg "plank-reloaded" "Plank Dock"
        install_pkg "mate-terminal" "MATE Terminal"
    elif [ "$DE_CHOICE" == "4" ]; then
        # KDE
        install_pkg "plasma-desktop" "KDE Plasma"
        install_pkg "konsole" "Konsole"
        install_pkg "dolphin" "Dolphin"
    fi
}

# ============== STEP 5: INSTALL GPU DRIVERS ==============
# Note: GPU acceleration is less directly applied to VNC's *rendering*
# as VNC often does software rendering or relies on the server-side X server.
# However, for applications running *within* the VNC session that might
# try to use GPU (e.g., Firefox with WebRender), these drivers can still be useful.
step_gpu() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing GPU Acceleration Libraries (for VNC session apps)...${NC}"
    echo ""
    install_pkg "mesa-zink" "Mesa Zink Core"
    if [ "$GPU_DRIVER" == "freedreno" ]; then
        install_pkg "mesa-vulkan-icd-freedreno" "Turnip Adreno Driver"
    fi
    install_pkg "vulkan-loader-android" "Vulkan Loader"
}

# ============== STEP 6: INSTALL AUDIO ==============
step_audio() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Audio...${NC}"
    echo ""
    install_pkg "pulseaudio" "PulseAudio Server"
}

# ============== STEP 7: INSTALL APPS (VS Code, VLC, etc.) ==============
step_apps() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Media & Dev Apps...${NC}"
    echo ""
    install_pkg "firefox" "Firefox Browser"
    install_pkg "vlc" "VLC Media Player"
    install_pkg "git" "Git Version Control"
    install_pkg "wget" "Wget Downloader"
    install_pkg "curl" "cURL"
}

# ============== STEP 8: PYTHON & FLASK DEMO ==============
step_python() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Python Environment...${NC}"
    echo ""
    install_pkg "python" "Python 3"

    (pip install flask > /dev/null 2>&1) &
    spinner $! "Installing Flask Web Framework..."

    # Create Python Demo
    mkdir -p ~/demo_python
    cat > ~/demo_python/app.py << 'EOF'
from flask import Flask, render_template_string
app = Flask(__name__)

@app.route("/")
def hello():
    return render_template_string("""
    <html>
        <body style="background-color:#1e1e1e;color:#00ff00;font-family:monospace;text-align:center;padding:50px">
            <h1>Hardware Accelerated Linux</h1>
            <h3>This Python server is running natively on a Snapdragon Android phone!</h3>
        </body>
    </html>
    """)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF
    echo -e "  [+] Python Web Demo created in ~/demo_python"
}

# ============== STEP 9: INSTALL WINE ==============
step_wine() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Windows Support (Wine/Box64)...${NC}"
    echo ""
    (pkg remove wine-stable -y > /dev/null 2>&1) &
    spinner $! "Removing old Wine versions..."

    install_pkg "hangover-wine" "Wine Compatibility Layer"
    install_pkg "hangover-wowbox64" "Box64 Wrapper"

    ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/wine /data/data/com.termux/files/usr/bin/wine
    ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/winecfg /data/data/com.termux/files/usr/bin/winecfg
}

# ============== STEP 10: CREATE LAUNCHERS ==============
step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring Startup Scripts...${NC}"
    echo ""

    mkdir -p ~/.config

    # Base XDG variables for Termux Paths
    XDG_INJECT="export XDG_DATA_DIRS=/data/data/com.termux/files/usr/share:\${XDG_DATA_DIRS}\nexport XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg:\${XDG_CONFIG_DIRS}"

    # KDE needs a special env injection
    if [ "$DE_CHOICE" == "4" ]; then
        mkdir -p ~/.config/plasma-workspace/env
        echo -e "#!/data/data/com.termux/files/usr/bin/bash\n$XDG_INJECT" > ~/.config/plasma-workspace/env/xdg_fix.sh
        chmod +x ~/.config/plasma-workspace/env/xdg_fix.sh
    fi

    # GPU & Environment Config (still useful for apps, even if VNC is software rendered)
    cat > ~/.config/linux-gpu.sh << EOF
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
EOF

    if [ "$DE_CHOICE" == "4" ]; then
        echo "export KWIN_COMPOSE=O2ES" >> ~/.config/linux-gpu.sh
    else
        echo -e "$XDG_INJECT" >> ~/.config/linux-gpu.sh
    fi

    # Create Plank autostart if XFCE or MATE
    if [ "$DE_CHOICE" == "1" ] || [ "$DE_CHOICE" == "3" ]; then
        mkdir -p ~/.config/autostart
        cat > ~/.config/autostart/plank.desktop << 'PLANKEOF'
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank
PLANKEOF
    else
        rm -f ~/.config/autostart/plank.desktop 2>/dev/null
    fi

    # VNC startup script for each DE will be handled by ~/.vnc/xstartup
    # We just need to define how to kill them

    # Determine execution commands and kill commands based on DE
    case $DE_CHOICE in
        1)
            # XFCE
            KILL_CMD="pkill -9 xfce4-session; pkill -9 plank"
            ;;
        2)
            # LXQt
            KILL_CMD="pkill -9 lxqt-session"
            ;;
        3)
            # MATE
            KILL_CMD="pkill -9 mate-session; pkill -9 plank"
            ;;
        4)
            # KDE Plasma
            KILL_CMD="pkill -9 startplasma-x11; pkill -9 kwin_x11; pkill -9 plasmashell"
            ;;
    esac


    # Main Launcher for VNC
    cat > ~/start-linux-vnc.sh << LAUNCHEREOF
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "[*] Starting ${DE_NAME} VNC Server..."
echo ""

# Ensure VNC display is unique
CURRENT_VNC_PORT=5901
while lsof -i :\$CURRENT_VNC_PORT >/dev/null; do
    CURRENT_VNC_PORT=\$((CURRENT_VNC_PORT + 1))
done
VNC_DISPLAY=":\$((CURRENT_VNC_PORT - 5900))"
echo -e "${CYAN}[*] Using VNC Display: ${WHITE}${VNC_DISPLAY} (Port: ${CURRENT_VNC_PORT})${NC}"

echo "[*] Cleaning up old sessions..."
vncserver -kill ${VNC_DISPLAY} > /dev/null 2>&1
${KILL_CMD} 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
unset PULSE_SERVER
pulseaudio --kill 2>/dev/null
sleep 0.5

echo "[*] Starting audio server..."
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null
export PULSE_SERVER=127.0.0.1

echo "[*] Starting VNC server on ${VNC_DISPLAY}..."
# You can customize resolution here, e.g., -geometry 1280x720
vncserver ${VNC_DISPLAY} -localhost no -xstartup ~/.vnc/xstartup &

echo "-----------------------------------------------"
echo "  [*] VNC Server is running on ${VNC_DISPLAY} (Port: ${CURRENT_VNC_PORT})"
echo "  [*] Use a VNC Client (e.g., VNC Viewer) to connect to ${CYAN}localhost:${VNC_DISPLAY}${NC} or ${CYAN}<Your_Termux_IP>:${VNC_DISPLAY}${NC}"
echo "-----------------------------------------------"
echo ""
LAUNCHEREOF
    chmod +x ~/start-linux-vnc.sh
    echo -e "  [+] Created ~/start-linux-vnc.sh"

    # Stopper for VNC
    cat > ~/stop-linux-vnc.sh << STOPEOF
#!/data/data/com.termux/files/usr/bin/bash
echo "Stopping ${DE_NAME} VNC Server..."

# Try to find running VNC servers
RUNNING_VNCS=\$(vncserver -list | grep -o ":[0-9]")
if [ -n "\$RUNNING_VNCS" ]; then
    echo "  [*] Found active VNC displays: \$RUNNING_VNCS. Killing them..."
    for display in \$RUNNING_VNCS; do
        vncserver -kill \$display
    done
fi

pkill -9 -f "pulseaudio" 2>/dev/null
${KILL_CMD} 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
echo "VNC Desktop stopped."
STOPEOF
    chmod +x ~/stop-linux-vnc.sh
    echo -e "  [+] Created ~/stop-linux-vnc.sh"
}

# ============== STEP 11: CREATE SHORTCUTS ==============
step_shortcuts() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Desktop Shortcuts...${NC}"
    echo ""
    mkdir -p ~/Desktop

    # App shortcuts
    cat > ~/Desktop/Firefox.desktop << 'EOF'
[Desktop Entry]
Name=Firefox
Exec=firefox
Icon=firefox
Type=Application
EOF

    cat > ~/Desktop/VLC.desktop << 'EOF'
[Desktop Entry]
Name=VLC Media Player
Exec=vlc
Icon=vlc
Type=Application
EOF

    cat > ~/Desktop/Wine_Config.desktop << 'EOF'
[Desktop Entry]
Name=Wine Config (Windows)
Exec=wine winecfg
Icon=wine
Type=Application
EOF

    # Dynamic terminal shortcut
    local term_cmd="xfce4-terminal"
    local term_icon="utilities-terminal"
    if [ "$DE_CHOICE" == "2" ]; then term_cmd="qterminal"; fi
    if [ "$DE_CHOICE" == "3" ]; then term_cmd="mate-terminal"; fi
    if [ "$DE_CHOICE" == "4" ]; then term_cmd="konsole"; fi

    cat > ~/Desktop/Terminal.desktop << EOF
[Desktop Entry]
Name=Terminal
Exec=${term_cmd}
Icon=${term_icon}
Type=Application
EOF

    chmod +x ~/Desktop/*.desktop 2>/dev/null
    echo -e "  [+] Added Firefox, VLC, Wine, and Terminal shortcuts."
}

# ============== COMPLETION ==============
show_completion() {
    echo ""
    echo -e "${GREEN}"
    cat << 'COMPLETE'
    ---------------------------------------------------------------
             [*]  INSTALLATION COMPLETE!  [*]
    ---------------------------------------------------------------
COMPLETE
    echo -e "${NC}"

    echo -e "${WHITE}[*] Your ${DE_NAME} environment with VNC is ready.${NC}"
    echo -e "${CYAN}[*] Installed Software:${NC}"
    echo "    - Python (Flask Demo located in ~/demo_python)"
    echo "    - Firefox Browser & VLC Media Player"
    echo "    - Wine & Hangover (Windows PC App compatibility)"
    echo "    - GPU Acceleration Libraries (for apps within VNC session)"
    echo ""
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo -e "${WHITE}[*] TO START THE DESKTOP (VNC):${NC}  ${GREEN}./start-linux-vnc.sh${NC}"
    echo -e "${WHITE}[*] TO STOP THE DESKTOP (VNC):${NC}   ${GREEN}./stop-linux-vnc.sh${NC}"
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo ""
    echo -e "${CYAN}After running ${GREEN}./start-linux-vnc.sh${NC}, you will see a message indicating the VNC display (e.g., :1) and port (e.g., 5901).${NC}"
    echo -e "${CYAN}Connect to this from a VNC Client app on your Android device or another computer. ${NC}"
    echo -e "${CYAN}Example VNC Address: ${WHITE}localhost:1${NC} or ${WHITE}127.0.0.1:5901${NC} (if connecting from the same Android device).${NC}"
    echo -e "${CYAN}If connecting from another device on the same network, use your Termux device's IP address (e.g., ${WHITE}192.168.1.100:5901${NC}).${NC}"
    echo ""
}

# ============== MAIN ==============
main() {
    show_banner
    setup_environment

    step_update
    step_repos
    step_vnc # Replaced Termux-X11 step with VNC
    step_desktop
    step_gpu
    step_audio
    step_apps
    step_python
    step_wine
    step_launchers
    step_shortcuts

    show_completion
}

main