#!/bin/bash
# ./build.sh outputdir

USER=sawako
EXTRA_PACKAGES=(
    base-devel tree htop screen wget grml-zsh-config unrar p7zip grub
    #intel-ucode amd-ucode
    xorg-server xorg-xinit xterm
    xf86-video-intel xf86-video-ati xf86-video-amdgpu xf86-video-nouveau mesa
    lightdm xfce4 xfce4-goodies networkmanager network-manager-applet
    pulseaudio pavucontrol gvfs file-roller gparted gsmartcontrol
    bluez bluez-utils blueman
    yt-dlp mpv gst-plugins-bad gst-plugins-good gst-plugins-ugly
    veracrypt tumbler ffmpegthumbnailer gimp cheese audacity
    noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra
)
AUR_PACKAGES=(
    yay f3 google-chrome tor-browser-bin onlyoffice-bin kemono-scraper
)


SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TMPDIR=$(mktemp -d)
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
    mkdir $TMPDIR/$pkg
    cd $TMPDIR/$pkg
    git clone --quiet "https://aur.archlinux.org/$pkg.git" .
    makepkg --syncdeps --clean --rmdeps --noconfirm --noprogressbar >/dev/null || exit 1
    rm *-debug-*.zst
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
ln -sf /usr/lib/systemd/system/lightdm.service $ETC/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target $ETC/systemd/system/default.target
rm $ETC/systemd/system/multi-user.target.wants/systemd-networkd.service &&
rm $ETC/systemd/system/multi-user.target.wants/systemd-resolved.service &&
rm $ETC/systemd/system/sockets.target.wants/systemd-networkd.socket &&


# Other configs
mkdir -p $ETC/sudoers.d &&
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > $ETC/sudoers.d/g_wheel &&
mkdir -p $ETC/lightdm &&
echo "
[LightDM]
run-directory=/run/lightdm

[Seat:*]
session-wrapper=/etc/lightdm/Xsession
autologin-user=$USER
autologin-session=xfce
" > $ETC/lightdm/lightdm.conf &&

cat $SCRIPT_DIR/passwd.skel > $ETC/passwd
echo "
$USER:x:1000:1000::/home/$USER:/bin/zsh
" >> $ETC/passwd &&
cat $SCRIPT_DIR/shadow.skel > $ETC/shadow
echo "
$USER"':$6$6KMe1NizgXgXV508$r.r94d8DgkZw4mHo9PDOpcNq2n46qOete226rVqCtwMtvSJvq.t2oaZhfs/XKVlJbQ3oyixn4qpUMOF651mOW.:18468:0:99999:7:::
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
sed -r -e 's~iso_name=.*$~iso_name="sawalinux"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e 's~iso_label=.*$~iso_label="SAWALINUX"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e 's~iso_publisher=.*$~iso_publisher="Dory <https://dory.moe>"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e 's~iso_application=.*~iso_application="SawaLinux Live/Rescue Distro"~g' -i $ARCHLIVE/profiledef.sh
sed -r -e 's~install_dir=.*$~install_dir="sawa"~g' -i $ARCHLIVE/profiledef.sh
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

