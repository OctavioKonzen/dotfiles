PROMPT="%F{#FFFFFF}╭─%F{#af00d1}%n %{%F{#808080}%}em %F{#008000}%B%~%b%f
%F{#FFFFFF}╰─%{%F{#FFFFFF}%}o %f"

/home/jake/.pokemon-colorscripts/pokemon-colorscripts.py -r --no-title

if [ "$(tty)" = "/dev/tty1" ]; then
    Hyprland
fi

_sudo_wrapper() {
  if [[ "$1" == zypper && ( "$2" == install || "$2" == dup ) ]]; then
    command sudo env ZYPP_PCK_PRELOAD=1 "$@"
  else
    command sudo "$@"
  fi
}

alias sudo="_sudo_wrapper"

alias bateria="upower -i /org/freedesktop/UPower/devices/DisplayDevice"

alias reboot="/sbin/reboot"

alias shutdown="/sbin/shutdown -h now"

function jogos() {
  local DISPOSITIVO="/dev/sda1"
  local PONTO_MONTAGEM_DESEJADO="/run/media/$USER/Jogos"

  # Verifica se já está montado
  if mount | grep -q "$DISPOSITIVO"; then
    local MONTADO_EM=$(mount | grep "$DISPOSITIVO" | awk '{print $3}')
    cd "$MONTADO_EM" || echo "Erro ao acessar $MONTADO_EM"
  else
    echo "$DISPOSITIVO não está montado."

    if [ ! -d "$PONTO_MONTAGEM_DESEJADO" ]; then
      mkdir -p "$PONTO_MONTAGEM_DESEJADO"
    fi

    # Tenta montar sem sudo
    if mount "$DISPOSITIVO" "$PONTO_MONTAGEM_DESEJADO" 2>/dev/null; then
      echo "Montado manualmente em $PONTO_MONTAGEM_DESEJADO"
      cd "$PONTO_MONTAGEM_DESEJADO" || echo "Erro ao acessar $PONTO_MONTAGEM_DESEJADO"
    else
      echo "Tentando montagem automática com udisksctl..."
      local MONTAGEM_SAIDA=$(udisksctl mount -b "$DISPOSITIVO" 2>/dev/null)
      local CAMINHO=$(echo "$MONTAGEM_SAIDA" | grep -oP "(?<=at ).*")

      if [ -n "$CAMINHO" ] && [ -d "$CAMINHO" ]; then
        echo "Montado automaticamente em $CAMINHO"
        cd "$CAMINHO" || echo "Erro ao acessar $CAMINHO"
      else
        echo "Erro: não foi possível montar o dispositivo."
      fi
    fi
  fi
}

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
