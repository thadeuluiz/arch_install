#!/usr/bin/env bash
# ========================= desktop environment installation script =========================
pac="sudo pacman --needed --noconfirm -S"
sys="sudo systemctl"

install_xorg() {
  echo "Installing xorg..."
  $pac xorg xorg-server mesa

  echo "Select xorg driver:"
  readarray -t drivers <<< $(pacman -Ss xf86-video | grep -oE "xf86-video-\S+")

  for i in "${!drivers[@]}"; do
    echo "  $i) ${drivers[i]}"
  done
  while :; do
    read -ep "Enter the desired alternative:" num
    if [[ $num -lt 0 || $num -gt $i ]]
    then
      echo "error: invalid value: $num is not between 0 and $i"
    else
      $pac ${drivers[num]}
      break
    fi
  done
}

install_lightdm() {
  echo "Installing lightdm..."
  $pac lightdm lightdm-slick-greeter

  echo "Replacing default greeter..."
  sudo sed -i 's/#greeter-session=.*/greeter-session=lightdm-slick-greeter/g' /etc/lightdm/lightdm.conf

  echo "Enabling service..."
  $sys enable lightdm.service
}

install_xfce4() {
  echo "Installing xfce4..."
  $pac xfce4 xfce4-goodies

  #echo "Configuring i3 failsafe session for user..."
  #mkdir $HOME/.config/xfce4/xfconf
  #cp -r /etc/xdg/xfce4/xfconf $HOME/.config/xfce4/xfconf/
  #xfconf-query -c xfce4-session -p /sessions/Failsafe/Client0_Command -t string -sa xfsettingsd
  #xfconf-query -c xfce4-session -p /sessions/Failsafe/Client1_Command -t string -sa i3
  #xfconf-query -c xfce4-session -p /sessions/Failsafe/Count -t int -s 2
}

install_aur_helper(){
  $pac base-devel git
  tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" RETURN
  (
    cd $tmp_dir
    git clone https://aur.archlinux.org/pikaur.git .
    makepkg -fsri --noconfirm
  )
}

install_i3() {
  echo "Installing i3..."
  $pac i3-gaps i3blocks i3lock i3status dmenu

}

install_extras() {
  echo "Installing network components..."
  $pac networkmanager network-manager-applet nm-connection-editor
  $sys enable NetworkManager.service

  echo "Installing audio components..."
  $pac pulseaudio pulseaudio-alsa pulseaudio-jack pulseaudio-bluetooth pavucontrol pamixer pasystray

  echo "Installing bluetooth components..."
  $pac bluez bluez-utils blueman
  $sys enable bluetooth.service

  echo "Installing GUI extras..."
  $pac feh picom rofi polybar python-pywal papirus-icon-theme
  pikaur -S nerd-fonts-complete python-haishoku

  echo "Installing goodies..."
  $pac firefox kitty neovim python-pynvim zsh tmux zathura-pdf-mupdf discord vlc transmission-gtk
}

install_xorg
install_lightdm
install_aur_helper
install_xfce4
install_i3
install_extras
