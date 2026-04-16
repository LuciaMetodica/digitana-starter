#!/bin/bash
# UI utilities for terminal — colors, prompts, spinners

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No color

# Icons
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"
WARN="${YELLOW}!${NC}"

header() {
  echo ""
  echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${PURPLE}${BOLD}  $1${NC}"
  echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

step() {
  echo -e "${ARROW} ${BOLD}$1${NC}"
}

success() {
  echo -e "  ${CHECK} $1"
}

fail() {
  echo -e "  ${CROSS} $1"
}

warn() {
  echo -e "  ${WARN} $1"
}

info() {
  echo -e "  ${DIM}$1${NC}"
}

ask() {
  local prompt="$1"
  local var_name="$2"
  local default="$3"
  if [ -n "$default" ]; then
    echo -ne "${CYAN}${prompt}${NC} ${DIM}[${default}]${NC}: "
    read -r input
    eval "$var_name=\"${input:-$default}\""
  else
    echo -ne "${CYAN}${prompt}${NC}: "
    read -r input
    eval "$var_name=\"$input\""
  fi
}

ask_secret() {
  local prompt="$1"
  local var_name="$2"
  echo -ne "${CYAN}${prompt}${NC}: "
  read -rs input
  echo ""
  eval "$var_name=\"$input\""
}

ask_yn() {
  local prompt="$1"
  local default="${2:-n}"
  local hint="y/N"
  [ "$default" = "y" ] && hint="Y/n"
  echo -ne "${CYAN}${prompt}${NC} ${DIM}(${hint})${NC}: "
  read -r input
  input="${input:-$default}"
  [[ "$input" =~ ^[Yy] ]]
}

ask_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  echo -e "${CYAN}${prompt}${NC}"
  for i in "${!options[@]}"; do
    echo -e "  ${BOLD}$((i+1)))${NC} ${options[$i]}"
  done
  echo -ne "${DIM}Opcion${NC}: "
  read -r choice
  echo "$choice"
}

spinner() {
  local pid=$1
  local msg="$2"
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${PURPLE}${spin:i++%${#spin}:1}${NC} %s" "$msg"
    sleep 0.1
  done
  printf "\r"
}

pause_continue() {
  echo ""
  echo -ne "${DIM}Presiona Enter para continuar...${NC}"
  read -r
}
