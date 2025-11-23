#!/bin/bash
# ./build.sh outputdir

USER=moon
EXTRA_PACKAGES=(
    base-devel tree htop screen wget grml-zsh-config unrar p7zip grub
    intel-ucode amd-ucode
    gnome #gnome-extra
    gnome-tweaks file-roller dconf-editor gnome-sound-recorder 
    mesa
    gdm networkmanager network-manager-applet
    gvfs file-roller gparted gsmartcontrol
    pavucontrol pipewire-pulse
    bluez bluez-utils
    yt-dlp mpv gst-plugins-bad gst-plugins-good gst-plugins-ugly
    veracrypt tumbler ffmpegthumbnailer gimp cheese audacity
    noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra
    discord steam firefox
)
AUR_PACKAGES=(
    yay f3 google-chrome tor-browser-bin onlyoffice-bin kemono-scraper
)


SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TMPDIR=$(mktemp -d)
CWD=$(pwd)
echo ">>> TMPDIR=$TMPDIR <<< If this crashes or Ctrl-C'd, delete it manually!"


# Make sure we have a clean fresh archlive
sudo pacman -S --needed --quiet --noconfirm --noprogressbar archiso &&
ARCHLIVE=$TMPDIR/archlive
cp -r /usr/share/archiso/configs/releng/ $ARCHLIVE || exit 1


# Extra official packages
for pkg in ${EXTRA_PACKAGES[@]}; do
    echo $pkg
done >> $ARCHLIVE/packages.x86_64

# Extra AUR packages
REPODIR=$TMPDIR/repo
mkdir -p $REPODIR
gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org
for pkg in ${AUR_PACKAGES[@]}; do
    echo ">> Building $pkg"
    mkdir $TMPDIR/$pkg
    cd $TMPDIR/$pkg
    git clone --quiet "https://aur.archlinux.org/$pkg.git" .
    makepkg --config "$CWD/makepkg.conf" --syncdeps --clean --rmdeps --noconfirm --noprogressbar >/dev/null || exit 1
    cp *.zst $REPODIR/
    >/dev/null cd -
    echo $pkg >> $ARCHLIVE/packages.x86_64
    rm -rf $TMPDIR/$pkg
done
repo-add $REPODIR/custom.db.tar.gz $REPODIR/*.zst
echo "
[multilib]
Include = /etc/pacman.d/mirrorlist
[custom]
SigLevel = Optional TrustAll
Server = file://$REPODIR" >> $ARCHLIVE/pacman.conf

ETC=$ARCHLIVE/airootfs/etc


# Services
ln -sf /usr/lib/systemd/system/NetworkManager.service $ETC/systemd/system/multi-user.target.wants/NetworkManager.service
mkdir -p $ETC/systemd/system/bluetooth.target.wants
ln -sf /usr/lib/systemd/system/bluetooth.service $ETC/systemd/system/bluetooth.target.wants/bluetooth.service
ln -sf /usr/lib/systemd/system/gdm.service $ETC/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target $ETC/systemd/system/default.target
rm $ETC/systemd/system/multi-user.target.wants/systemd-networkd.service &&
rm $ETC/systemd/system/multi-user.target.wants/systemd-resolved.service &&
rm $ETC/systemd/system/sockets.target.wants/systemd-networkd.socket &&


# default gnome configs
mkdir -p $ETC/dconf/db/lunarch.d
echo "
user-db:user
system-db:lunarch
" > $ETC/dconf/db/lunarch.d/00-lunarch-settings
echo "
[org/gnome/shell]
favorite-apps = ['firefox.desktop', 'google-chrome.desktop', 'org.gnome.Nautilus.desktop']
" > $ETC/dconf/db/lunarch.d/00-lunarch-settings
mkdir -p $ETC/pacman.d/hooks
echo "# remove from airootfs!
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = gnome-shell

[Action]
Description = Generating dconf...
When = PostTransaction
Depends = glibc
Exec = /usr/bin/dconf update
" > $ETC/pacman.d/hooks/gnome-dconf.hook


# locale
echo "en_US.UTF-8 UTF-8" > $ETC/locale.gen
mkdir -p $ETC/pacman.d/hooks
echo "# remove from airootfs!
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = glibc

[Action]
Description = Generating localisation files...
When = PostTransaction
Depends = glibc
Exec = /usr/bin/locale-gen
" > $ETC/pacman.d/hooks/locale-gen.hook

# Other configs
mkdir -p $ETC/sudoers.d &&
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > $ETC/sudoers.d/g_wheel &&

cat $SCRIPT_DIR/passwd.skel > $ETC/passwd
echo "
$USER:x:1000:1000::/home/$USER:/bin/zsh
" >> $ETC/passwd &&
cat $SCRIPT_DIR/shadow.skel > $ETC/shadow
echo "
$USER"':$y$j9T$SxiEZ3FI1s.C0HSII0lkf.$UM5o4i0sbJ.9gnwHUszStl.Da/Pg2cqeVZQFOzaEdh0:20415:0:99999:7:::
' >> $ETC/shadow &&
cat $SCRIPT_DIR/group.skel > $ETC/group &&
echo "
wheel:x:998:$USER
autologin:x:970:$USER
$USER:x:1000:
" >> $ETC/group &&
cat $SCRIPT_DIR/gshadow.skel > $ETC/gshadow &&
echo "
wheel:!!::$USER
autologin:!::$USER
$USER:!::
" >> $ETC/gshadow &&

echo 'blacklist pcspkr
blacklist snd_pcsp' > $ETC/modprobe.d/nobeep.conf


# branding
sed -r -e 's~iso_name=.*$~iso_name="lunarch"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e 's~iso_label=.*$~iso_label="LUNARCH"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e 's~iso_publisher=.*$~iso_publisher="Dory <https://dory.moe>"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e 's~iso_application=.*~iso_application="Lunarch"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e 's~install_dir=.*$~install_dir="lunarch"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e '/file_permissions=/a ["/etc/gshadow"]="0:0:400"' -i $ARCHLIVE/profiledef.sh
rm $ETC/motd
rm -r $ARCHLIVE/efiboot && cp -r $SCRIPT_DIR/efiboot $ARCHLIVE/
rm -r $ARCHLIVE/syslinux && cp -r $SCRIPT_DIR/syslinux $ARCHLIVE/
rm -rf $ETC/skel && cp -r $SCRIPT_DIR/skel $ETC/
cp $SCRIPT_DIR/os-release $ETC/


#echo ==== $ARCHLIVE ====
#exit 1
# Build the ISO
OUTDIR="$1"
if [ -z "$OUTDIR" ]; then
    OUTDIR="out"
fi
mkdir -p "$OUTDIR" &&
sudo mkarchiso -v -r -o "$OUTDIR" $ARCHLIVE || exit 1
sudo rm -rf "$TMPDIR"


# Test the ISO
OUTFILE="$OUTDIR/$(ls -rt "$OUTDIR" | tail -n 1)"
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd OVMF_VARS.4m.fd.tmp
qemu-system-x86_64 \
    -cpu host,+topoext \
    -smp cores=2,threads=2 \
    -m 6G \
    -enable-kvm \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive if=pflash,format=raw,file=OVMF_VARS.4m.fd.tmp \
    -nic user,model=virtio-net-pci,hostfwd=tcp::12345-:22 \
    -device virtio-keyboard-pci -device virtio-mouse-pci \
    -cdrom "$OUTFILE" &&
rm OVMF_VARS.4m.fd.tmp

