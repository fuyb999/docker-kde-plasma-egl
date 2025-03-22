
print_header "Configure Fcitx5"

fcitx5_autostart_desktop="$(cat <<EOF
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=Fctix5
Comment=Launch fctix5 on login
Exec=/usr/bin/fcitx5 %U
Icon=fctix5
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOF
)"

print_step_header "Enable Fcitx5 auto-start script"
mkdir -p "${USER_HOME:?}/.config/autostart"
echo "${fcitx5_autostart_desktop:?}" > "${USER_HOME:?}/.config/autostart/Fcitx5.desktop"
#sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/fcitx5.ini

echo -e "\e[34mDONE\e[0m"