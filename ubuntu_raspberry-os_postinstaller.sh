#!/bin/bash
# BETA: Not for use yet

source /etc/os-release
BITS=$(getconf LONG_BIT)
ARCH=$(uname -m)

KERNEL=$(uname -r)
COMPUTER_ID='airwave7'

# Disabled Touchpad on X11
sudo echo -e 'Section "InputClass"\n\tIdentifier "ETPS/2 Elantech Touchpad"\n\tMatchProduct "ETPS/2 Elantech Touchpad"\n\tMatchIsTouchpad "on"\n\tMatchOS "Linux"\n\tMatchDevicePath "/dev/input/event*"\n\tOption "Ignore" "on"\nEndSection\n' | sudo tee /etc/X11/xorg.conf.d/synaptics.conf
# Disabled Touchpad on Wayland
sudo echo -e 'ATTRS{name}=="ETPS/2 Elantech Touchpad", ENV{ID_INPUT}="", ENV{ID_INPUT_MOUSE}="", ENV{ID_INPUT_POINTINGSTICK}=""' | sudo tee /usr/lib/udev/rules.d/75-elan-touch.rules
# Hostname
echo -e "127.0.0.1\tlocalhost $COMPUTER_ID\n::1\tlocalhost $COMPUTER_ID" | sudo tee /etc/hosts

if [ "$DIST" == "raspbian" ]; then
    sudo rpi-update
fi

# Add Webmin Repository
sudo curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
sudo sh setup-repos.sh
  
wget https://dl.google.com/linux/direct/google-chrome-beta_current_"$ARCH".deb
sudo dpkg --install google-chrome-beta_current_"$ARCH".deb
rm google-chrome-beta_current_"$ARCH".deb

sudo echo "deb http://download.webmin.com/download/repository sarge contrib" | sudo tee /etc/apt/sources.list.d/webmin.list
get -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -

sudo apt update
sudo apt -y upgrade
sudo apt -y full-upgrade
sudo apt -y install --install-recommends brasero
sudo apt -y install winbind apt-transport-https webmin tasksel ubuntu-restricted-extras build-essential synaptic libdvd-pkg libreoffice printer-driver-cups-pdf filezilla rabbitvcs-nautilus ffmpeg git ruby-sass node-less gfortran cmake npm nodejs qt5-qmake curl network-manager-fortisslvpn-gnome network-manager-iodine-gnome network-manager-l2tp-gnome network-manager-openconnect-gnome network-manager-ssh-gnome network-manager-strongswan network-manager-vpnc-gnome python3-pip gstreamer1.0-nice gstreamer1.0-omx-generic gstreamer1.0-opencv gstreamer1.0-pipewire gstreamer1.0-pocketsphinx gstreamer1.0-rtsp gstreamer1.0-plugins-bad

sudo tasksel install lamp-server
sudo mysql_secure_installation
sudo dpkg-reconfigure libdvd-pkg


gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true
gsettings set org.gnome.desktop.datetime automatic-timezone true
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'br')]"
gsettings set org.gnome.desktop.interface show-battery-percentage true
  
# TPM for QEMU + Windows 11
mkdir /tmp/myvtpm
sudo swtpm_setup --tpm2 --tpmstate /tmp/myvtpm --create-ek-cert --create-platform-cert
sudo chmod 777 -R /var/lib/swtpm-localca/
sudo ln -s /sys/firmware/acpi/tables/SLIC /usr/share/seabios/slic.bin
sudo ln -s /sys/firmware/acpi/tables/MSDM /usr/share/seabios/msdm.bin
  
sudo restorecon -R -v /usr/share/seabios/
sudo chmod -R 777 /usr/share/seabios/*

sudo /usr/libexec/webmin/changepass.pl /etc/webmin root "$password"

# virtio-fs folder
mkdir ~/SHARE

# Web Stuff
sudo npm install -g npm@latest cordova
sudo pip3 install pip wheel debugpy pytest --upgrade --pre

# Perl Upgrade
sudo cpanm App::cpanoutdated

sudo echo "pip --disable-pip-version-check list --outdated --pre --format=json | python -c \"import json, sys; print('\n'.join([x['name'] for x in json.load(sys.stdin)]))\" | grep -v '^-e' | cut -d = -f 1  | xargs -n1 pip install --upgrade --pre --ignore-installed -U" | sudo tee /usr/bin/auto-upgrade-ign.sh
sudo echo -e "dnf -y update\nflatpak update -y\ncpan-outdated -p | cpanm\nfwupdmgr get-devices\nfwupdmgr refresh --force\nfwupdmgr get-updates\nfwupdmgr update" >> /usr/bin/auto-upgrade-ign.sh
sudo chmod -x /usr/bin/auto-upgrade-ign.sh
sudo sh /usr/bin/auto-upgrade-ign.sh
sudo echo -e '[Unit]\nDescription=Auto Upgrade (Ignacio)\nWants=network-online.target\nAfter=network.target network-online.target\n[Service]\nExecStart=sh "/usr/bin/auto-upgrade-ign.sh"\n\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/auto-upgrade-ign.service
sudo systemctl enable auto-upgrade-ign.service

#Autostart some applications
mkdir ~/.config/autostart
cp /usr/share/applications/google-chrome-beta.desktop ~/.config/autostart
echo -e "X-GNOME-Autostart-enabled=true" | tee -a ~/.config/autostart/google-chrome-beta.desktop

#Install GPG Keys
gpg2 --import /run/media/ignaciosantolin/KEYS/private.pgp
gpg2 --keyserver keys.openpgp.org --recv-keys ADD3C408CD66D157

mkdir ~/.ssh/
cp /run/media/ignaciosantolin/KEYS/id_rsa ~/.ssh/id_rsa
cp /run/media/ignaciosantolin/KEYS/id_rsa.pub ~/.ssh/id_rsa.pub
sudo chmod 600 ~/.ssh/id_rs*
ssh-add ~/.ssh/id_rsa

# Signed drivers for Secure Boot
sudo /usr/sbin/kmodgenca
sudo mokutil --import /etc/pki/akmods/certs/public_key.der

# Setup Printer
sudo lpadmin -p "L3250" -E -v dnssd://EPSON%20L3250%20Series._ipp._tcp.local/ -m everywhere
sudo lpadmin -d "L3250"

# Setup VM
wget https://raw.githubusercontent.com/isantolin/os-templates-and-setup/main/qemu-win11.xml
sudo virsh create qemu-win11.xml