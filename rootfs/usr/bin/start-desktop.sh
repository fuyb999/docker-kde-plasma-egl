#!/usr/bin/env bash
###
# File: start-desktop.sh
# Project: bin
# File Created: Thursday, 1st January 1970 12:00:00 pm
# Author: Console and webGui login account (jsunnex@gmail.com)
# -----
# Last Modified: Saturday, 8th July 2023 6:16:47 pm
# Modified By: Console and webGui login account (jsunnex@gmail.com)
###
set -e
source /usr/bin/common-functions.sh

# CATCH TERM SIGNAL:
_term() {
    kill -TERM "$desktop_pid" 2>/dev/null
}
trap _term SIGTERM SIGINT

# CONFIGURE:
# Remove lockfile
rm -f /tmp/.started-desktop
# Start a session bus instance of dbus-daemon
# Note: This script should be the only one that waits for X after exporting this dbus session
rm -fv /tmp/.dbus-desktop-session.env
export_desktop_dbus_session
# Configure some XDG environment variables
export XDG_CACHE_HOME="${USER_HOME:?}/.cache"
export XDG_CONFIG_HOME="${USER_HOME:?}/.config"
export XDG_DATA_HOME="${USER_HOME:?}/.local/share"

# Wait for XDG_RUNTIME_DIR
until [ -d "${XDG_RUNTIME_DIR}" ]; do sleep 0.5; done

# Make user directory owned by the default user
chown -f "$(id -nu):$(id -ng)" ~ || sudo chown -f "$(id -nu):$(id -ng)" ~ || chown -R -f -h --no-preserve-root "$(id -nu):$(id -ng)" ~ || sudo chown -R -f -h --no-preserve-root "$(id -nu):$(id -ng)" ~ || echo 'Failed to change user directory permissions, there may be permission issues'
# Change operating system password to environment variable
#(echo "${USER_PASSWORD}"; echo "${USER_PASSWORD}";) | sudo passwd "$(id -nu)" || (echo "password"; echo "${USER_PASSWORD}"; echo "${USER_PASSWORD}";) | passwd "$(id -nu)" || echo 'Password change failed, using default password'
# Remove directories to make sure the desktop environment starts
rm -rf /tmp/.X* ~/.cache || echo 'Failed to clean X11 paths'
# Change time zone from environment variable
#ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" | tee /etc/timezone > /dev/null || echo 'Failed to set timezone'
# Add Lutris directories to path
export PATH="${PATH:+${PATH}:}/usr/local/games:/usr/games"
# Add LibreOffice to library path
export LD_LIBRARY_PATH="/usr/lib/libreoffice/program${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# Configure joystick interposer
export SELKIES_INTERPOSER='/usr/$LIB/selkies_joystick_interposer.so'
export LD_PRELOAD="${SELKIES_INTERPOSER}${LD_PRELOAD:+:${LD_PRELOAD}}"
export SDL_JOYSTICK_DEVICE=/dev/input/js0
mkdir -pm1777 /dev/input || sudo mkdir -pm1777 /dev/input || echo 'Failed to create joystick interposer directory'
touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || sudo touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || echo 'Failed to create joystick interposer devices'
chmod 777 /dev/input/js* || sudo chmod 777 /dev/input/js* || echo 'Failed to change permission for joystick interposer devices'

# Set default display
export DISPLAY="${DISPLAY:-:20}"
# PipeWire-Pulse server socket path
export PIPEWIRE_LATENCY="128/48000"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"

if [ -z "$(ldconfig -N -v $(sed 's/:/ /g' <<< $LD_LIBRARY_PATH) 2>/dev/null | grep 'libEGL_nvidia.so.0')" ] || [ -z "$(ldconfig -N -v $(sed 's/:/ /g' <<< $LD_LIBRARY_PATH) 2>/dev/null | grep 'libGLX_nvidia.so.0')" ]; then
  # Install NVIDIA userspace driver components including X graphic libraries, keep contents same between docker-nvidia-glx-desktop and docker-nvidia-egl-desktop
  export NVIDIA_DRIVER_ARCH="$(dpkg --print-architecture | sed -e 's/arm64/aarch64/' -e 's/armhf/32bit-ARM/' -e 's/i.*86/x86/' -e 's/amd64/x86_64/' -e 's/unknown/x86_64/')"
  if [ -z "${NVIDIA_DRIVER_VERSION}" ]; then
    # Driver version is provided by the kernel through the container toolkit, prioritize kernel driver version if available
    if [ -f "/proc/driver/nvidia/version" ]; then
      export NVIDIA_DRIVER_VERSION="$(head -n1 </proc/driver/nvidia/version | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9\.]+/) {print $i; exit}}')"
    elif command -v nvidia-smi >/dev/null 2>&1; then
      # Use NVIDIA-SMI when not available
      export NVIDIA_DRIVER_VERSION="$(nvidia-smi --version | grep 'DRIVER version' | cut -d: -f2 | tr -d ' ')"
    else
      echo 'Failed to find NVIDIA GPU driver version, container will likely not start because of no NVIDIA container toolkit or NVIDIA GPU driver present'
    fi
  fi
fi

# Run Xvfb server with required extensions
/usr/bin/Xvfb "${DISPLAY}" -screen 0 "8192x4096x${DISPLAY_CDEPTH}" -dpi "${DISPLAY_DPI}" +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" +extension "XFIXES" +extension "XTEST" +iglx +render -nolisten "tcp" -ac -noreset -shmem &

# EXECUTE PROCESS:
# Wait for the X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Resize the screen to the provided size
/usr/local/bin/selkies-gstreamer-resize "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}"

echo "**** Starting KDE plasma ****"
# Use VirtualGL to run the KDE desktop environment with OpenGL if the GPU is available, otherwise use OpenGL with llvmpipe
export XDG_SESSION_ID="${DISPLAY#*:}"
export QT_LOGGING_RULES="${QT_LOGGING_RULES:-*.debug=false;qt.qpa.*=false}"
if [ -n "$(nvidia-smi --query-gpu=uuid --format=csv,noheader | head -n1)" ] || [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
  export VGL_FPS="${DISPLAY_REFRESH}"
  /usr/bin/vglrun -d "${VGL_DISPLAY:-egl}" +wm /usr/bin/dbus-launch --exit-with-session /usr/bin/startplasma-x11 &
else
  /usr/bin/dbus-launch --exit-with-session /usr/bin/startplasma-x11 &
fi

desktop_pid=$!
touch /tmp/.started-desktop

# WAIT FOR CHILD PROCESS:
wait "$desktop_pid"
