
menu() {
    printf "%s\n" \
        "Escolha a função a executar:" \
        "1. Repositórios" \
        "2. Instalar Programas" \
        "3. Instalar Flatpak e RPM" \
        "4. Copiar Arquivos"

    read -rp "Entre sua escolha (1, 2, 3 ou 4): " choice
}

menu

# Repositório
if [ $choice -eq 1 ]; then
sudo zypper ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman
sudo env ZYPP_CURL2=1 zypper ref
sudo zypper dup --from packman --allow-vendor-change

# Programas
elif [ $choice -eq 2 ]; then
sudo env ZYPP_PCK_PRELOAD=1 zypper install swww gnome-disk-utility gamemoded gamemode kitty hyprland easyeffects neofetch nautilus pavucontrol gnome-system-monitor steam gnome-text-editor wine xorg-x11-server unrar rar flatpak playerctl gh  libgamemode0-32bit htop zsh sysconfig-netconfig bleachbit xwayland grim slurp socat jq wl-clipboard peazip mangohud xdg-user-dirs pamixer qbittorrent xdg-desktop-portal-hyprland ripgrep polkit-gnome yarn ImageMagick nwg-look nwg-displays && sudo zypper dup --from packman --allow-vendor-change

elif [ $choice -eq 3 ]; then


# Configurar flatpak

sudo npm install -g sass bun
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.vysp3r.ProtonPlus
flatpak install flathub com.github.tchx84.Flatseal
flatpak install flathub org.videolan.VLC
flatpak install flathub com.obsproject.Studio
flatpak install flathub com.stremio.Stremio
flatpak install flathub page.kramo.Cartridges
flatpak install flathub dev.vencord.Vesktop
flatpak install flathub com.visualstudio.code
flatpak install flathub app.zen_browser.zen

# Configurar Perms
sudo flatpak override --filesystem=$HOME/.themes
sudo flatpak override --filesystem=$HOME/.icons

# Copiar arquivos
elif [ $choice -eq 4 ]; then
cp -r /home/octavio/dotfiles/home/.* /home/octavio/

# Lutris
#ln -s -v -r ./Lutris/lutris/ /home/$USER/.local/share
#ln -s -v -r ./Lutris/.config/lutris /home/$USER/.config
#ln -s -v -r ./Steam /home/octavio/.local/share/Steam

#Wake on Lan
sudo cp -r /home/octavio/dotfiles/misc/wol.service /etc/systemd/system
sudo chmod 644 /etc/systemd/system/wol.service

# Hostname
sudo hostnamectl set-hostname Martinez

else
echo "Escolha invalida selecione 1, 2, 3 ou 4"
fi
