#!/bin/bash

# Sair imediatamente se um comando sair com status diferente de zero.
set -e

# Variáveis Globais
USER_HOME="$HOME"
RPM_BASE_PATH="/mnt/discos/utilitário/Pacotes"
DOTFILES_SOURCE_HOME="/mnt/discos/utilitário/dotfiles/home"
DOTFILES_SOURCE_MISC="/mnt/discos/utilitário/dotfiles/misc"

# Atualizar o timestamp do sudo para que não peça senha para cada comando
sudo -v
echo "Privilégios de root atualizados."

# --- Funções ---

log_info() {
    printf "\n%s\n" "--------------------------------------------------"
    printf "%s\n" "$1"
    printf "%s\n" "--------------------------------------------------"
}

setup_repositories() {
    log_info "Configurando Repositórios (Packman)..."
    sudo zypper ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman
    sudo env ZYPP_CURL2=1 zypper --gpg-auto-import-keys ref
    sudo zypper dup --from packman --allow-vendor-change
    log_info "Repositórios configurados e sistema atualizado com Packman."
}

install_zypper_packages() {
    log_info "Instalando Programas via Zypper..."
    # Pré-carregar metadados do pacote pode acelerar a instalação
    sudo env ZYPP_PCK_PRELOAD=1 zypper install gnome-disk-utility gamemoded gamemode kitty hyprland easyeffects neofetch nautilus pavucontrol gnome-system-monitor steam lutris gnome-text-editor wine xorg-x11-server unrar rar flatpak playerctl gh  libgamemode0-32bit htop zsh sysconfig-netconfig bleachbit xwayland grim slurp socat jq wl-clipboard peazip mangohud xdg-user-dirs pamixer qbittorrent xdg-desktop-portal-hyprland ripgrep polkit-gnome yarn ImageMagick nwg-look nwg-displays kernel-firmware-amdgpu libdrm_amdgpu1 libdrm_amdgpu1-32bit libdrm_radeon1 libdrm_radeon1-32bit libvulkan_radeon libvulkan_radeon-32bit libvulkan1 libvulkan1-32bit fd nodejs npm && sudo zypper dup --from packman --allow-vendor-change


    log_info "Programas via Zypper instalados."
}

install_rpm_flatpak_npm() {
    log_info "Instalando Pacotes RPM, Flatpak e NPM..."

    # NPM Globals (Node.js e npm devem ser instalados pela função install_zypper_packages)
    log_info "Instalando pacotes NPM globais: sass, bun..."
    if command -v npm > /dev/null; then
        sudo npm install -g sass bun
    else
        log_info "AVISO: npm não encontrado. Pulando instalação de pacotes NPM."
    fi

    # RPMs Locais
    log_info "Instalando pacotes RPM locais..."
    local rpms_to_install=(
        "gconf2-3.2.6-1.31.x86_64.rpm"
        "swww-0.9.1-33.3.x86_64.rpm"
        "triggercmdagent-1.0.1.x86_64.rpm"
        "umu-launcher-1.2.6-1.1.x86_64.rpm"
        "aylurs-gtk-shell-1.8.2-5.8.x86_64.rpm"
    )
    for rpm_file in "${rpms_to_install[@]}"; do
        if [ -f "${RPM_BASE_PATH}/${rpm_file}" ]; then
            sudo zypper install -y "${RPM_BASE_PATH}/${rpm_file}" # Adicionado -y
        else
            log_info "AVISO: Arquivo RPM ${RPM_BASE_PATH}/${rpm_file} não encontrado. Pulando."
        fi
    done

    log_info "Bloqueando versões dos pacotes gconf2 e swww (se instalados)..."
    # Verificar se o pacote existe antes de tentar bloquear
    if rpm -q gconf2 &>/dev/null; then
      sudo zypper al gconf2
    else
      log_info "AVISO: Pacote gconf2 não instalado, não é possível bloquear."
    fi
    if rpm -q swww &>/dev/null; then
      sudo zypper al swww
    else
      log_info "AVISO: Pacote swww não instalado, não é possível bloquear."
    fi


    # Configurar Flatpak
    log_info "Configurando Flatpak e instalando aplicações..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    local flatpaks_to_install=(
        "com.vysp3r.ProtonPlus"
        "org.videolan.VLC"
        "com.obsproject.Studio"
        "dev.vencord.Vesktop"
        "com.visualstudio.code"
    )
    for flatpak_app in "${flatpaks_to_install[@]}"; do
        flatpak install -y flathub "$flatpak_app"
    done

    # Configurar Permissões Flatpak
    log_info "Configurando permissões do Flatpak para temas e ícones..."
    sudo flatpak override --filesystem="${USER_HOME}/.themes"
    sudo flatpak override --filesystem="${USER_HOME}/.icons"

    log_info "Instalação de RPMs, Flatpaks e pacotes NPM concluída."
}

copy_config_files_and_services() {
    log_info "Copiando Arquivos de Configuração e Configurando Serviços..."

    # Copiar dotfiles
    log_info "Copiando dotfiles para ${USER_HOME}..."
    if [ -d "${DOTFILES_SOURCE_HOME}" ]; then
        # Usar rsync para mais controle, ou cp com -i para interativo se preferir
        # Cuidado: cp -r sobrescreverá arquivos existentes sem aviso.
        cp -r "${DOTFILES_SOURCE_HOME}/." "${USER_HOME}/"
    else
        log_info "AVISO: Diretório de origem dos dotfiles ${DOTFILES_SOURCE_HOME} não encontrado. Pulando cópia."
    fi


    # Wake on Lan
    log_info "Configurando serviço Wake on Lan..."
    if [ -f "${DOTFILES_SOURCE_MISC}/wol.service" ]; then
        sudo cp -r "${DOTFILES_SOURCE_MISC}/wol.service" /etc/systemd/system/
        sudo chmod 644 /etc/systemd/system/wol.service
        sudo systemctl enable wol.service
        sudo systemctl start wol.service
    else
        log_info "AVISO: Arquivo wol.service não encontrado em ${DOTFILES_SOURCE_MISC}. Pulando configuração."
    fi

    # Portal XDG Hyprland
    log_info "Iniciando e habilitando portal XDG para Hyprland..."
    # Adicionado enable para persistir após reboot
    sudo systemctl enable --now xdg-desktop-portal-hyprland.service || log_info "AVISO: Falha ao habilitar/iniciar xdg-desktop-portal-hyprland.service. Pode não estar instalado."


    # Tuned
    log_info "Configurando tuned para performance de latência..."
    sudo systemctl enable --now tuned
    sudo tuned-adm profile latency-performance

    # Hostname
    local new_hostname="Martinez" # AJUSTE O HOSTNAME SE NECESSÁRIO
    log_info "Configurando hostname para ${new_hostname}..."
    sudo hostnamectl set-hostname "${new_hostname}"

    log_info "Cópia de arquivos e configuração de serviços concluída."
    echo "NOTA: Algumas alterações como o hostname podem requerer reinicialização para pleno efeito."
}

# --- Menu Principal ---
get_menu_choice() {
    # Imprime o menu para stderr (saída de erro padrão) adicionando >&2
    printf "\n%s\n" \
        "Escolha a função a executar:" \
        "1. Configurar Repositórios (Packman)" \
        "2. Instalar Programas (Zypper)" \
        "3. Instalar Pacotes (RPM, Flatpak, NPM)" \
        "4. Copiar Arquivos de Configuração e Serviços" \
        "5. EXECUTAR TODAS AS ETAPAS (1-4 em ordem)" \
        "0. Sair" >&2

    local user_choice
    read -rp "Entre sua escolha (0-5): " user_choice
    echo "$user_choice" # Isto vai para stdout e será capturado corretamente
}

# --- Fluxo Principal ---
while true; do
    choice=$(get_menu_choice)

    case "$choice" in
        1)
            setup_repositories
            ;;
        2)
            install_zypper_packages
            ;;
        3)
            install_rpm_flatpak_npm
            ;;
        4)
            copy_config_files_and_services
            ;;
        5)
            log_info "EXECUTANDO TODAS AS ETAPAS..."
            setup_repositories
            install_zypper_packages
            install_rpm_flatpak_npm
            copy_config_files_and_services
            log_info "TODAS AS ETAPAS CONCLUÍDAS!"
            ;;
        0)
            log_info "Saindo do script."
            exit 0
            ;;
        *)
            # Verifica se a escolha está vazia (usuário apenas pressionou Enter)
            if [ -z "$choice" ]; then
                log_info "Nenhuma escolha feita. Tente novamente."
            else
                log_info "Escolha inválida: '$choice'. Selecione uma opção de 0 a 5."
            fi
            ;;
    esac
    
    # Pausa apenas se uma ação foi tentada (evita pausa dupla para escolha vazia/inválida)
    if [[ "$choice" -ge 0 && "$choice" -le 5 ]] || [ -n "$choice" ] ; then
        read -rp "Pressione Enter para continuar para o menu..."
    fi
done
