#!/bin/bash
while getopts "p:" arg; do
  case $arg in
    p)
      PASSWORD=$OPTARG  
      ;;
  esac
done

if [ -z "${PASSWORD}" ]; then
	echo "Missing -p (password) parameter"
	exit
fi

BITS=$(getconf LONG_BIT)
ARCH=$(uname -m)
VERSION_ID=$(rpm -E %fedora)
KERNEL=$(uname -r)
COMPUTER_ID='airwave7'

sudo dnf install dnf5
#Disabled Touchpad on X11
sudo echo -e 'Section "InputClass"\n\tIdentifier "ETPS/2 Elantech Touchpad"\n\tMatchProduct "ETPS/2 Elantech Touchpad"\n\tMatchIsTouchpad "on"\n\tMatchOS "Linux"\n\tMatchDevicePath "/dev/input/event*"\n\tOption "Ignore" "on"\nEndSection\n' | sudo tee /etc/X11/xorg.conf.d/synaptics.conf
#Disabled Touchpad on Wayland
sudo echo -e 'ATTRS{name}=="ETPS/2 Elantech Touchpad", ENV{ID_INPUT}="", ENV{ID_INPUT_MOUSE}="", ENV{ID_INPUT_POINTINGSTICK}=""' | sudo tee /usr/lib/udev/rules.d/75-elan-touch.rules

#Add Webmin Repository
sudo curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
sudo sh setup-repos.sh

echo -e "fastestmirror=true\ndeltarpm=true\nmax_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf
echo -e "127.0.0.1\tlocalhost $COMPUTER_ID\n::1\tlocalhost $COMPUTER_ID" | sudo tee /etc/hosts
sudo hostnamectl set-hostname $COMPUTER_ID
echo -e "127.0.0.1\tlocalhost $COMPUTER_ID\n::1\tlocalhost $COMPUTER_ID" | sudo tee /etc/hosts

#Add AdGuard Home
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.d/override1.conf
echo -e "DNS=192.168.15.36 2804:431:c7c6:5949:6b2f:7bc6:e83d:b65b" | sudo tee /etc/systemd/resolved.conf.d/override1.conf

gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true
gsettings set org.gnome.desktop.datetime automatic-timezone true
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'br')]"
gsettings set org.gnome.desktop.interface show-battery-percentage true
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
  
# Other repository and developer packages install
sudo dnf5 -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-"$VERSION_ID".noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$VERSION_ID".noarch.rpm https://dl.google.com/linux/direct/google-chrome-beta_current_"$ARCH".rpm python-devel cairo-devel gobject-introspection-devel cairo-gobject-devel libcurl-devel krb5-devel kernel-devel-"$KERNEL" libvirt-devel pcsc-lite-devel libdb-devel akmods swig expat-devel ninja-build
  
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

sudo dnf5 -y install rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Update to install repository packages
sudo find /etc/yum.repos.d/*.repo -type f -exec sed -i 's/enabled=0/enabled=1/g' {} \;
sudo flatpak update
sudo dnf5 clean all
sudo dnf5 -y update --refresh

# Remove conflicting packages and not used packages
sudo dnf5 -y remove libswscale-free ffmpeg-free libswresample-free libpostproc-free firefox libavutil-free

# Signed drivers for Secure Boot
sudo /usr/sbin/kmodgenca
sudo mokutil --import /etc/pki/akmods/certs/public_key.der

#### REBOOT

# Install Basic Packages
sudo dnf5 -y install webmin httpd gcc-c++ make nodejs cups-pdf cups-lpd cabextract lzip p7zip p7zip-plugins unrar alsa-plugins-pulseaudio libcurl gstreamer1-plugin-openh264 gstreamer1-plugins-bad-free-extras gstreamer1-plugins-bad-free-fluidsynth gstreamer1-plugins-bad-free-wildmidi gstreamer1-plugins-base-tools gstreamer1-plugins-fc gstreamer1-plugins-good-extras gstreamer1-rtsp-server gstreamer1-vaapi NetworkManager-fortisslvpn-gnome NetworkManager-iodine-gnome NetworkManager-l2tp-gnome NetworkManager-libreswan-gnome NetworkManager-sstp-gnome NetworkManager-strongswan-gnome epson-inkjet-printer-escpr2 NetworkManager-ovs gstreamer1-libav gcc-gfortran cmake fedora-workstation-repositories perl-App-cpanminus seabios swtpm-tools code-insiders mkfontscale xset xorg-x11-drv-nvidia-390xx akmod-nvidia-390xx xorg-x11-drv-nvidia-390xx-cuda vulkan vdpauinfo libva-nvidia-driver gstreamer1-plugin-reqwest gstreamer1-plugin-reqwest gstreamer1-plugins-bad-free-zbar gstreamer1-svt-av1 gstreamer1-svt-vp9 httpd mariadb-server php php-common php-mysqlnd php-xml php-json php-gd php-mbstring php-pecl-imagick php-opcache php-pecl-ssh2 php-tidy nvidia-vaapi-driver ffmpeg yubikey-manager-qt yubico-piv-tool java-latest-openjdk https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm rpmfusion-nonfree-release-tainted nouveau-firmware

sudo flatpak -y install flathub io.dbeaver.DBeaverCommunity
wget -O yubioath-flutter-main.tar.gz https://developers.yubico.com/yubioath-flutter/Releases/yubico-authenticator-latest-linux.tar.gz
mkdir yubico-authenticator-latest-linux
tar -xvf yubioath-flutter-main.tar.gz -C yubico-authenticator-latest-linux/
cd yubico-authenticator-latest-linux
cd $(ls)
sh ./desktop_integration.sh --install


sudo alternatives --config java
  
# TPM for QEMU + Windows 11
mkdir /tmp/myvtpm
sudo swtpm_setup --tpm2 --tpmstate /tmp/myvtpm --create-ek-cert --create-platform-cert
sudo chmod 777 -R /var/lib/swtpm-localca/
sudo ln -s /sys/firmware/acpi/tables/SLIC /usr/share/seabios/slic.bin
sudo ln -s /sys/firmware/acpi/tables/MSDM /usr/share/seabios/msdm.bin
  
sudo restorecon -R -v /usr/share/seabios/
sudo chmod -R 777 /usr/share/seabios/*

# NVIDIA Related commands
sudo cp /usr/share/X11/xorg.conf.d/nvidia.conf /etc/X11/xorg.conf.d/nvidia.conf

# Apache related
sudo systemctl start httpd
sudo systemctl enable httpd
sudo systemctl enable mariadb 
sudo systemctl start mariadb 
sudo mkdir /Apache
sudo chmod +x /Apache
sudo touch /Apache/.htaccess
sudo chmod -R 777 /Apache
sudo chcon -R -t httpd_sys_content_t /Apache
sudo chcon -R -t httpd_sys_rw_content_t /Apache
sudo setsebool -P httpd_can_network_connect true
sudo sed -i 's/\/var\/www\/html/\/Apache/' /etc/httpd/conf/httpd.conf
sudo firewall-cmd --add-service={http,https} --permanent
sudo systemctl reload firewalld
sudo systemctl restart httpd
sudo sudo mysql_secure_installation
  
# Performance Tweaks
sudo grubby --update-kernel=ALL --args="processor.ignore_ppc=1 nowatchdog"
sudo grubby --update-kernel=ALL --args='nvidia-drm.modeset=1'
sudo grubby --update-kernel=ALL --args='video=vesafb:mtrr:3'
sudo akmods --force
sudo dracut --force
sudo /usr/libexec/webmin/changepass.pl /etc/webmin root "$PASSWORD"

# virtio-fs folder
mkdir ~/SHARE

# Web Stuff
sudo npm install -g npm@latest cordova
sudo pip3 install pip wheel debugpy pytest --upgrade --pre

# Perl Upgrade
sudo cpanm App::cpanoutdated

sudo echo "sudo pip3 --disable-pip-version-check list --outdated --pre --format=json | sudo python3 -c \"import json, sys; print('\n'.join([x['name'] for x in json.load(sys.stdin)]))\" | grep -v '^-e' | cut -d = -f 1  | sudo xargs -n1 pip install --upgrade --break-system-packages --pre -U" | sudo tee /usr/bin/auto-upgrade-ign.sh
sudo echo "sudo pip3 --disable-pip-version-check list --outdated --pre --format=json | sudo python3 -c \"import json, sys; print('\n'.join([x['name'] for x in json.load(sys.stdin)]))\" | grep -v '^-e' | cut -d = -f 1  | sudo xargs -n1 pip install --upgrade --break-system-packages --pre --ignore-installed -U" | sudo tee -a /usr/bin/auto-upgrade-ign.sh
sudo echo -e "dnf5 -y update\nflatpak update -y\ncpan-outdated -p | cpanm\nfwupdmgr get-devices\nfwupdmgr refresh --force\nfwupdmgr get-updates\nfwupdmgr update" >> /usr/bin/auto-upgrade-ign.sh
sudo chmod -x /usr/bin/auto-upgrade-ign.sh
sudo sh /usr/bin/auto-upgrade-ign.sh
sudo echo -e '[Unit]\nDescription=Auto Upgrade (Ignacio)\nWants=network-online.target\nAfter=network.target network-online.target\n[Service]\nExecStart=sh "/usr/bin/auto-upgrade-ign.sh"\n\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/auto-upgrade-ign.service
sudo systemctl enable auto-upgrade-ign.service

#Autostart some applications
mkdir ~/.config/autostart
cp /usr/share/applications/google-chrome-beta.desktop ~/.config/autostart
echo -e "X-GNOME-Autostart-enabled=true" | tee -a ~/.config/autostart/google-chrome-beta.desktop

# Install GPG Keys on Yubikeys (One for each SC) -
sudo service pcscd restart
gpg-card --verbose --FETCH # Not Working yet Use "gpg --card-edit" "fetch"
# Install GPG Keys on Yubikeys (One for each SC) - END

gpg --list-keys --fingerprint | grep pub -A 1 | grep -Ev "pub|--" | tr -d ' ' | awk 'BEGIN { FS = "\n" } ; { print $1":6:" } ' | gpg --import-ownertrust

# Setup Printer
sed -i 's/use-ipv4=yes/use-ipv4=no/g' /etc/avahi/avahi-daemon.conf
sed -i 's/use-ipv6=yes/use-ipv6=no/g' /etc/avahi/avahi-daemon.conf
sudo systemctl disable cups-browsed
sudo systemctl stop cups-browsed
sudo lpadmin -p "L3250" -E -v dnssd://EPSON%20L3250%20Series._ipp._tcp.local/ -m everywhere
sudo lpadmin -p "L3250" -o Media=A4 -o PageSize=A4
sudo lpadmin -d "L3250"

# Setup VM
wget https://raw.githubusercontent.com/isantolin/os-templates-and-setup/main/qemu-win11.xml
sudo virsh create qemu-win11.xml
