#!/usr/bin/env bash
# ========================= arch linux installation script =========================

# -------------------- timezone --------------------
echo "Setting localtime..."
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
timedatectl set-local-rtc 1

# -------------------- locale --------------------
echo "Configuring locales..."
cat >> /etc/locale.gen <<- EOF
en_US.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
en_US ISO-8859-1
pt_BR ISO-8859-1
EOF
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" >        /etc/vconsole.conf

# -------------------- hostname --------------------
echo "Configuring hostname..."
read -ep "Enter the desired hostname: " hostname
echo $hostname > /etc/hostname

# -------------------- linux image --------------------
mkinitcpio -P

# -------------------- user management --------------------
echo "Set root password: "
passwd

read -ep "Enter the desired username: " username
useradd -m -G wheel $username --badname
echo "Set user password: "
passwd $username

echo "Configuring super user escalation..."
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# -------------------- bootloader --------------------
bootctl install
systemctl enable systemd-boot-update.service

echo "Configuring bootloader entries..."

# bootloader default config
cat > /boot/loader/loader.conf <<- EOF
default=arch.conf
console-mode max
timeout 4
EOF
