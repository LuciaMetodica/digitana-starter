#!/bin/bash
# OS detection and dependency installation

detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
  elif [[ "$OSTYPE" == "linux"* ]]; then
    echo "linux"
  else
    echo "unknown"
  fi
}

check_command() {
  command -v "$1" >/dev/null 2>&1
}

check_node_version() {
  if ! check_command node; then
    return 1
  fi
  local version
  version=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
  [ "$version" -ge 18 ] 2>/dev/null
}

install_node() {
  local os="$1"
  step "Instalando Node.js 18+..."

  if check_command fnm; then
    fnm install 22 && fnm use 22
  elif check_command nvm; then
    nvm install 22 && nvm use 22
  else
    case "$os" in
      macos)
        if check_command brew; then
          brew install node@22
        else
          info "Instalando fnm (Fast Node Manager)..."
          curl -fsSL https://fnm.vercel.app/install | bash
          export PATH="$HOME/.local/share/fnm:$PATH"
          eval "$(fnm env)"
          fnm install 22 && fnm use 22
        fi
        ;;
      linux|wsl)
        info "Instalando fnm (Fast Node Manager)..."
        curl -fsSL https://fnm.vercel.app/install | bash
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env)"
        fnm install 22 && fnm use 22
        ;;
    esac
  fi

  if check_node_version; then
    success "Node.js $(node --version) instalado"
  else
    fail "No se pudo instalar Node.js. Instalalo manualmente: https://nodejs.org"
    return 1
  fi
}

install_jq() {
  local os="$1"
  step "Instalando jq..."
  case "$os" in
    macos)
      if check_command brew; then
        brew install jq
      else
        fail "Necesitas Homebrew para instalar jq en Mac: https://brew.sh"
        return 1
      fi
      ;;
    linux|wsl)
      if check_command apt; then
        sudo apt update -qq && sudo apt install -y jq
      elif check_command yum; then
        sudo yum install -y jq
      else
        fail "Instala jq manualmente: https://stedolan.github.io/jq/download/"
        return 1
      fi
      ;;
  esac
  check_command jq && success "jq instalado"
}

check_claude_cli() {
  check_command claude
}

guide_claude_install() {
  echo ""
  warn "Claude Code CLI no esta instalado."
  echo ""
  echo -e "  Para instalarlo:"
  echo -e "  ${BOLD}npm install -g @anthropic-ai/claude-code${NC}"
  echo ""
  echo -e "  Despues de instalarlo, corré ${BOLD}claude${NC} y logueate con tu cuenta Claude Pro."
  echo ""
}

check_all_dependencies() {
  local os
  os=$(detect_os)
  local errors=0

  header "Paso 1: Verificando sistema"
  step "Sistema operativo: $os"

  # Node.js
  if check_node_version; then
    success "Node.js $(node --version)"
  else
    warn "Node.js 18+ no encontrado"
    install_node "$os" || ((errors++))
  fi

  # Git
  if check_command git; then
    success "Git $(git --version | cut -d' ' -f3)"
  else
    fail "Git no encontrado. Instalalo: https://git-scm.com"
    ((errors++))
  fi

  # jq
  if check_command jq; then
    success "jq $(jq --version 2>/dev/null)"
  else
    warn "jq no encontrado"
    install_jq "$os" || ((errors++))
  fi

  # curl
  if check_command curl; then
    success "curl presente"
  else
    fail "curl no encontrado (raro). Instalalo con tu package manager."
    ((errors++))
  fi

  # python3
  if check_command python3; then
    success "Python $(python3 --version 2>/dev/null | cut -d' ' -f2)"
  else
    fail "Python 3 no encontrado. Instalalo: https://python.org"
    ((errors++))
  fi

  # Claude Code CLI
  if check_claude_cli; then
    success "Claude Code CLI presente"
  else
    guide_claude_install
    echo -ne "  Ya lo instalaste? (Enter para verificar de nuevo, 's' para saltar): "
    read -r skip
    if [ "$skip" != "s" ]; then
      if check_claude_cli; then
        success "Claude Code CLI presente"
      else
        warn "Claude Code no detectado. Podes instalarlo despues y volver a correr el setup."
        ((errors++))
      fi
    fi
  fi

  return $errors
}
