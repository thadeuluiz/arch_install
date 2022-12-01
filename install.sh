#!/usr/bin/env bash

# disk partitioning subroutine
create_partition () {
  echo "Creating $1 partition..."

  # get pnum and size
  read -ep "Enter the $1 partition number: " pnum
  read -ep "Enter the $1 partition size: " psize

  case $1 in
    EFI)
      ptype=ef00;
      fmt="mkfs.fat -F32";;
    system)
      ptype=8300;
      fmt="mkfs.btrfs";;
    swap)
      ptype=8200;
      fmt="mkswap";;
  esac

  sgdisk -n ${pnum}:+0:+${psize} -t${pnum}:${ptype} $2
  $fmt ${2}p${pnum}

  eval ${1}_path=${2}p${pnum}
  eval ${1}_uuid=$(lsblk -dno UUID ${2}p${pnum})
}

# disk table creation
partition_disk() {

  echo "Partitioning disks..."

  echo "Choose available device..."
  readarray -t devices <<< $(lsblk -d | tail -n+2 | cut -d " " -f1)

  for i in "${!devices[@]}"; do
    echo "  $i) /dev/${devices[i]}"
  done
  read -ep "Enter the desired device: " num
  if [[ $num -lt 0 || $num -gt $i ]]; then
    echo "Invalid option, exiting."; exit;
  fi
  device=/dev/${devices[num]}

  read -ep "Do you wish to reset device partitions? (y/N)" ans
  case $ans in
    [yY]) sgdisk -Z $device;;
    [nN]) echo "skipping table reset.";;
    *) echo "Invalid option, exiting."; exit;;
  esac
  
  create_partition "EFI"    $device
  create_partition "system" $device
  create_partition "swap"   $device

  echo "Creating btrfs subvolumes..."

  mount $system_path /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  umount /mnt

  echo "Mounting filesystems..."
  mount $system_path         /mnt      -ossd,subvol=@,compress=lzo
  mount $system_path --mkdir /mnt/home -ossd,subvol=@home,compress=zstd:9
  mount $EFI_path    --mkdir /mnt/boot
  swapon $swap_path

  echo "Select microcode package..."
  readarray -t vendors <<< $(pacman -Ssq ucode)
  for i in "${!vendors[@]}"; do
    echo "  $i) ${vendors[i]}"
  done
  read -ep "Enter the desired alternative:" num
  if [[ $num -lt 0 || $num -gt $i ]]; then
    echo "Invalid value. Exiting"; exit
  else
    vendor_ucode=${vendors[num]}
  fi

  echo "Installing essentials..."
  pacstrap -K /mnt base linux-zen linux-firmware btrfs-progs sudo $vendor_ucode

  echo "Generating fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab
}

install_bootloader() {
  # run post chroot setup
  cp "$(dirname "${BASH_SOURCE[0]}")"/bootloader.sh /mnt/
  trap "rm /mnt/bootloader.sh" RETURN

  arch-chroot /mnt ./bootloader.sh

  cat > /mnt/boot/loader/entries/arch.conf <<- EOF
  title Arch Linux
  linux /vmlinuz-linux-zen
  initrd /${vendor_ucode}.img
  initrd /initramfs-linux-zen.img
  options root=UUID=$system_uuid rw rootflags=subvol=@,compress=lzo,ssd
  EOF

  cat > /mnt/boot/loader/entries/arch-fallback.conf <<- EOF
  title Arch Linux (fallback)
  linux /vmlinuz-linux-zen
  initrd /${vendor_ucode}.img
  initrd /initramfs-linux-zen-fallback.img
  options root=UUID=$system_uuid rw rootflags=subvol=@,compress=lzo,ssd
  EOF
}

install_ui() {
  # run post chroot setup
  cp "$(dirname "${BASH_SOURCE[0]}")"/i3.sh /mnt/
  trap "rm /mnt/i3.sh" RETURN

  read -ep "enter user: " user
  arch-chroot /mnt su $user ./i3.sh

}

partition_disk
install_bootloader
install_ui
