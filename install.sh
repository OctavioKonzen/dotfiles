#!/bin/bash

# Obter o diretório onde o script está localizado
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Variáveis Globais usando o diretório do script como base
USER_HOME="$HOME"
RPM_BASE_PATH="${SCRIPT_DIR}/pacotes"
DOTFILES_SOURCE_HOME="${SCRIPT_DIR}/home"
DOTFILES_SOURCE_MISC="${SCRIPT_DIR}/misc"

# Variável global para armazenar o perfil do sistema (Desktop/Laptop)
SYSTEM_PROFILE=""

# Atualizar o timestamp do sudo para que não peça senha para cada comando
sudo -v
echo "Privilégios de root atualizados."

# --- Funções ---

log_info() {
    printf "\n%s\n" "--------------------------------------------------"
    printf "%s\n" "$1"
    printf "%s\n" "--------------------------------------------------"
}

# Função para determinar o perfil do sistema (Desktop/Laptop) uma única vez
determine_system_profile() {
    if [ -z "$SYSTEM_PROFILE" ]; then # Só pergunta se o perfil ainda não foi definido
        local profile_choice
        while true; do
            read -rp "Esta configuração é para Desktop ou Laptop? (d para Desktop / l para Laptop): " profile_choice
            case "$profile_choice" in
                [Dd]* )
                    SYSTEM_PROFILE="Desktop"
                    break
                    ;;
                [Ll]* )
                    SYSTEM_PROFILE="Laptop"
                    break
                    ;;
                * )
                    echo "Resposta inválida. Por favor, digite 'd' para Desktop ou 'l' para Laptop."
                    ;;
            esac
        done
        log_info "Perfil do sistema definido como: $SYSTEM_PROFILE"
    fi
}

setup_repositories() {
    log_info "Configurando Repositórios (Packman)..."
    sudo zypper ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman
    sudo env ZYPP_CURL2=1 zypper --gpg-auto-import-keys ref
    sudo zypper dup --from packman --allow-vendor-change
    log_info "Repositórios configurados e sistema atualizado com Packman."
}

install_zypper_packages() {
    determine_system_profile # Garante que o perfil do sistema seja conhecido
    log_info "Iniciando seleção de pacotes via Zypper para: $SYSTEM_PROFILE..."

    local PACOTES_COMUNS=(
        nautilus pavucontrol gnome-system-monitor gnome-text-editor
        gnome-disk-utility gamemoded gamemode flatpak
        slurp grim hyprland kitty polkit-gnome xwayland xorg-x11-server
        pamixer
        yarn jq zsh socat wl-clipboard ripgrep fd # ImageMagick foi removido desta lista por você
        nodejs npm
        lutris steam
        nwg-displays nwg-look
        hyprlock
        neowofetch
    )

    local PACOTES_DESKTOP_ESPECIFICOS=(
        easyeffects
        wine
        sysconfig-netconfig
        bleachbit
        peazip
        mangohud
        xdg-user-dirs
        qbittorrent
        xdg-desktop-portal-hyprland # Específico para Desktop
        kernel-firmware-amdgpu
        libdrm_amdgpu1 libdrm_amdgpu1-32bit libdrm_radeon1 libdrm_radeon1-32bit
        libvulkan_radeon libvulkan_radeon-32bit libvulkan1 libvulkan1-32bit
        htop unrar rar playerctl gh libgamemode0-32bit
        ImageMagick # ImageMagick movido para cá
    )

    local PACOTES_LAPTOP_ESPECIFICOS=(
        nvidia-video-G06 nvidia-compute-utils-G06 nvidia-gl-G06
        bluez blueman
        swww # swww é instalado via zypper para Laptop
        git
        vulkan-tools
        suse-prime brightnessctl power-profiles-daemon
    )

    local packages_to_install=()

    if [ "$SYSTEM_PROFILE" == "Desktop" ]; then
        packages_to_install=("${PACOTES_DESKTOP_ESPECIFICOS[@]}" "${PACOTES_COMUNS[@]}")
    elif [ "$SYSTEM_PROFILE" == "Laptop" ]; then
        packages_to_install=("${PACOTES_LAPTOP_ESPECIFICOS[@]}" "${PACOTES_COMUNS[@]}")
    else
        log_info "ERRO: Perfil do sistema desconhecido: $SYSTEM_PROFILE. Pulando instalação de pacotes Zypper."
        return 1
    fi

    log_info "Iniciando instalação de pacotes para $SYSTEM_PROFILE..."
    sudo env ZYPP_PCK_PRELOAD=1 zypper install "${packages_to_install[@]}"
    log_info "Programas via Zypper para $SYSTEM_PROFILE instalados."

    if [ "$SYSTEM_PROFILE" == "Laptop" ]; then
        log_info "Executando 'zypper dup --from packman --allow-vendor-change' adicional para Laptop..."
        log_info "Nota: Esta operação já pode ter sido realizada pela Opção 1 (Configurar Repositórios)."
        sudo zypper dup --from packman --allow-vendor-change
        log_info "'zypper dup' adicional para Laptop concluído."

        log_info "Configurando NVIDIA como GPU de boot para Laptop..."
        if command -v prime-select > /dev/null; then
            sudo prime-select boot nvidia
            log_info "NVIDIA configurada como GPU de boot."
            log_info "NOTA: Uma reinicialização é necessária para que a seleção da GPU de boot tenha efeito."
        else
            log_info "AVISO: Comando 'prime-select' não encontrado. Pulando configuração da GPU de boot."
        fi
    fi
}

install_rpm_flatpak_npm() {
    determine_system_profile # Garante que o perfil do sistema seja conhecido
    log_info "Instalando Pacotes RPM, Flatpak e NPM para o perfil: $SYSTEM_PROFILE..."

    log_info "Instalando pacotes NPM globais: sass, bun..."
    if command -v npm > /dev/null; then
        sudo npm install -g sass bun
    else
        log_info "AVISO: npm não encontrado. Pulando instalação de pacotes NPM."
    fi

    log_info "Instalando pacotes RPM locais de ${RPM_BASE_PATH}..."
    # RPMs que são sempre instalados, independente do perfil
    local rpms_always_install=(
        "umu-launcher-1.2.6-2.7.x86_64.rpm"
        "aylurs-gtk-shell-1.8.2-5.8.x86_64.rpm"
        "acpi_call-kmp-default-1.2.2_k6.14.6_1-2.660.x86_64.rpm"
    )

    # RPMs a serem instalados apenas no perfil Desktop
    local rpms_desktop_only=(
        "gconf2-3.2.6-1.31.x86_64.rpm"
        "swww-0.9.1-33.3.x86_64.rpm" # swww via RPM para Desktop
        "triggercmdagent-1.0.1.x86_64.rpm"
    )

    local final_rpms_to_install=("${rpms_always_install[@]}")

    if [ "$SYSTEM_PROFILE" == "Desktop" ]; then
        log_info "Adicionando RPMs específicos para Desktop à lista de instalação..."
        final_rpms_to_install+=("${rpms_desktop_only[@]}")
    fi

    if [ ${#final_rpms_to_install[@]} -gt 0 ]; then
        for rpm_file in "${final_rpms_to_install[@]}"; do
            if [ -f "${RPM_BASE_PATH}/${rpm_file}" ]; then
                log_info "Instalando RPM: ${rpm_file}"
                sudo zypper install -y "${RPM_BASE_PATH}/${rpm_file}"
            else
                log_info "AVISO: Arquivo RPM ${RPM_BASE_PATH}/${rpm_file} não encontrado. Pulando."
            fi
        done
    else
        log_info "Nenhum pacote RPM selecionado para instalação nesta configuração."
    fi

    if [ "$SYSTEM_PROFILE" == "Desktop" ]; then
        log_info "Bloqueando versões dos pacotes para Desktop (se instalados)..."
        # gconf2 é instalado via RPM apenas no Desktop
        if rpm -q gconf2 &>/dev/null; then
            log_info "Bloqueando gconf2..."
            sudo zypper al gconf2
        else
            log_info "AVISO: Pacote gconf2 (RPM Desktop) não instalado, não é possível bloquear."
        fi

        # swww é instalado via RPM apenas no Desktop.
        # Bloqueia apenas se o RPM foi instalado (e estamos no Desktop).
        # Nota: Laptop instala swww via zypper, que não será bloqueado por esta lógica.
        if rpm -q swww &>/dev/null; then
            log_info "Bloqueando swww (RPM Desktop)..."
            sudo zypper al swww
        else
            # Isso pode acontecer se o arquivo RPM do swww não foi encontrado, mesmo sendo Desktop.
            log_info "AVISO: Pacote swww (RPM Desktop) não instalado, não é possível bloquear."
        fi
    else
        log_info "Pulando bloqueio de gconf2 e swww (configuração de Laptop)."
    fi

    log_info "Configurando Flatpak e instalando aplicações (nível sistema)..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    local flatpaks_to_install=(
        "com.vysp3r.ProtonPlus"
        "org.videolan.VLC"
        "com.obsproject.Studio"
        "dev.vencord.Vesktop"
        "com.visualstudio.code"
    )
    for flatpak_app in "${flatpaks_to_install[@]}"; do
        sudo flatpak install -y flathub "$flatpak_app"
    done

    log_info "Configurando permissões do Flatpak para temas e ícones (nível sistema)..."
    sudo flatpak override --filesystem="${USER_HOME}/.themes"
    sudo flatpak override --filesystem="${USER_HOME}/.icons"
    log_info "Instalação de RPMs, Flatpaks e pacotes NPM concluída."
}

copy_config_files_and_services() {
    determine_system_profile # Garante que o perfil do sistema seja conhecido
    log_info "Copiando Arquivos de Configuração e Configurando Serviços para o perfil: $SYSTEM_PROFILE..."

    log_info "Copiando dotfiles de ${DOTFILES_SOURCE_HOME} para ${USER_HOME}..."
    if [ -d "${DOTFILES_SOURCE_HOME}" ]; then
        cp -r "${DOTFILES_SOURCE_HOME}/." "${USER_HOME}/"
    else
        log_info "AVISO: Diretório de origem dos dotfiles ${DOTFILES_SOURCE_HOME} não encontrado. Pulando cópia."
    fi

    if [ "$SYSTEM_PROFILE" == "Desktop" ]; then
        log_info "Configurando serviço Wake on Lan para Desktop..."
        if [ -f "${DOTFILES_SOURCE_MISC}/wol.service" ]; then
            sudo cp -r "${DOTFILES_SOURCE_MISC}/wol.service" /etc/systemd/system/
            sudo chmod 644 /etc/systemd/system/wol.service
            sudo systemctl enable wol.service
            sudo systemctl start wol.service
        else
            log_info "AVISO: Arquivo wol.service não encontrado em ${DOTFILES_SOURCE_MISC}. Pulando configuração."
        fi

        log_info "Iniciando e habilitando portal XDG para Hyprland para Desktop..."
        # xdg-desktop-portal-hyprland está na lista de pacotes específicos do desktop
        if zypper se --installed-only xdg-desktop-portal-hyprland &>/dev/null; then
            sudo systemctl enable --now xdg-desktop-portal-hyprland.service || log_info "AVISO: Falha ao habilitar/iniciar xdg-desktop-portal-hyprland.service."
        else
            log_info "AVISO: Pacote xdg-desktop-portal-hyprland não instalado. Pulando configuração do serviço."
        fi
    else
        log_info "Pulando configuração do serviço Wake on Lan (configuração de Laptop)."
        log_info "Pulando configuração do portal XDG para Hyprland (configuração de Laptop)."
    fi

    log_info "Configurando tuned para performance de latência..."
    sudo systemctl enable --now tuned
    sudo tuned-adm profile latency-performance

    local new_hostname="Martinez" # AJUSTE O HOSTNAME SE NECESSÁRIO
    log_info "Configurando hostname para ${new_hostname}..."
    sudo hostnamectl set-hostname "${new_hostname}"

    # Verificando e configurando o shell padrão para Zsh
    log_info "Verificando e configurando o shell padrão para Zsh..."
    if command -v zsh > /dev/null; then
        ZSH_PATH=$(which zsh)
        USER_DEFAULT_SHELL=$(getent passwd "$USER" | cut -d: -f7)

        if [ "$USER_DEFAULT_SHELL" != "$ZSH_PATH" ]; then
            log_info "Shell padrão atual ('$USER_DEFAULT_SHELL') não é Zsh ('$ZSH_PATH'). Alterando para Zsh para o usuário $USER..."
            if sudo chsh -s "$ZSH_PATH" "$USER"; then
                log_info "Shell padrão alterado para Zsh. Faça logout e login novamente para aplicar a alteração."
            else
                log_info "AVISO: Falha ao alterar o shell padrão para Zsh."
            fi
        else
            log_info "Shell padrão já é Zsh ('$USER_DEFAULT_SHELL')."
        fi
    else
        log_info "AVISO: Zsh não encontrado. Não é possível definir como shell padrão (Zsh está na lista de pacotes comuns)."
    fi

    log_info "Cópia de arquivos, configuração de serviços e shell concluída."
    echo "NOTA: Algumas alterações (hostname, shell padrão, GPU de boot) podem requerer reinicialização ou novo login para pleno efeito."
}

# --- Menu Principal ---
get_menu_choice() {
    printf "\n%s\n" \
        "Escolha a função a executar:" \
        "1. Configurar Repositórios (Packman)" \
        "2. Instalar Programas (Zypper - Desktop/Laptop)" \
        "3. Instalar Pacotes (RPM, Flatpak, NPM)" \
        "4. Copiar Arquivos de Configuração e Serviços" \
        "0. Sair" >&2

    local user_choice
    read -rp "Entre sua escolha (0-4): " user_choice
    echo "$user_choice"
}

# --- Fluxo Principal ---
while true; do
    choice=$(get_menu_choice)
    case "$choice" in
        1) setup_repositories ;;
        2) install_zypper_packages ;;
        3) install_rpm_flatpak_npm ;;
        4) copy_config_files_and_services ;;
        0)
            log_info "Saindo do script."
            exit 0
            ;;
        *)
            if [ -z "$choice" ]; then
                log_info "Nenhuma escolha feita. Tente novamente."
            else
                log_info "Escolha inválida: '$choice'. Selecione uma opção de 0 a 4."
            fi
            ;;
    esac
    
    if [[ "$choice" -ge 0 && "$choice" -le 4 ]] || [ -n "$choice" ] ; then
        read -rp "Pressione Enter para continuar para o menu..."
    fi
done
