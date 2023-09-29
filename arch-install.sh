#!/bin/bash


# Specify the disk to be partitioned
DISK="/dev/sda"

# Btrfs mount options
BTRFS_OPTS="noatime,compress=zstd,space_cache,ssd"

# Partition and format the disk
parted "$DISK" mklabel gpt
parted "$DISK" mkpart ESP fat32 1MiB 513MiB
parted "$DISK" set 1 boot on
parted "$DISK" mkpart primary linux-swap 513MiB 2.5GiB
parted "$DISK" mkpart primary btrfs 2.5GiB 100%

mkfs.fat -F32 "${DISK}1"
mkswap "${DISK}2"
swapon "${DISK}2"
mkfs.btrfs "${DISK}3"

# Create Btrfs subvolumes and mount them
mount "${DISK}3" /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
umount /mnt

mount -o $BTRFS_OPTS,subvol=@root "${DISK}3" /mnt
mkdir -p /mnt/{home,boot}
mount -o $BTRFS_OPTS,subvol=@home "${DISK}3" /mnt/home
mount "${DISK}1" /mnt/boot

# Bootstrap Arch Linux
pacstrap /mnt base linux linux-headers base-devel linux-firmware vim nano

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and setup the system
arch-chroot /mnt <<EOF

# Timezone and locale
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "archlinux" > /etc/hostname

# Install additional software
pacman -S --noconfirm grub efibootmgr dosfstools os-prober mtools sddm xfce4 xmonad xmobar dmenu emacs pulseaudio bluez bluez-utils cups networkmanager network-manager-applet wpa_supplicant neofetch

# Enable services
systemctl enable sddm NetworkManager bluetooth cups

# Set up GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "Installation completed! You can now reboot into your new Arch Linux system."
