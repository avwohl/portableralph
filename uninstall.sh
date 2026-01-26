#!/bin/bash
#
# PortableRalph Uninstaller
# https://github.com/aaron777collins/portableralph
#
# Usage:
#   ./uninstall.sh [--force] [--keep-config]
#
# Options:
#   --force         Skip confirmation prompts
#   --keep-config   Keep ~/.ralph.env configuration file
#   --help          Show this help
#

set -euo pipefail

# ============================================
# CONFIGURATION
# ============================================

VERSION="1.6.0"

# Load platform utilities if available
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/platform-utils.sh" ]; then
    source "$SCRIPT_DIR/lib/platform-utils.sh"
    USER_HOME=$(get_home_dir)
else
    USER_HOME="${HOME}"
fi

DEFAULT_INSTALL_DIR="${USER_HOME}/ralph"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================
# ARGUMENT PARSING
# ============================================

FORCE=false
KEEP_CONFIG=false
INSTALL_DIR="$DEFAULT_INSTALL_DIR"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f)
                FORCE=true
                shift
                ;;
            --keep-config|-k)
                KEEP_CONFIG=true
                shift
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
PortableRalph Uninstaller

Usage:
  ./uninstall.sh [options]

Options:
  --force           Skip confirmation prompts
  --keep-config     Keep ~/.ralph.env configuration file
  --install-dir     Custom install directory (default: ~/ralph)
  --help            Show this help

Examples:
  # Interactive uninstall with confirmation
  ./uninstall.sh

  # Force uninstall without prompts
  ./uninstall.sh --force

  # Uninstall but keep configuration
  ./uninstall.sh --keep-config
EOF
}

# ============================================
# UTILITIES
# ============================================

log() {
    echo -e "${GREEN}▸${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✖${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✔${NC} $1"
}

prompt_yn() {
    local prompt_text="$1"
    local default="${2:-n}"

    if [[ "$FORCE" == "true" ]]; then
        [[ "$default" =~ ^[Yy] ]] && return 0 || return 1
    fi

    local yn_hint
    if [[ "$default" =~ ^[Yy] ]]; then
        yn_hint="Y/n"
    else
        yn_hint="y/N"
    fi

    echo -en "${CYAN}?${NC} ${prompt_text} ${BOLD}[$yn_hint]${NC}: "
    read -r answer < /dev/tty
    answer="${answer:-$default}"

    [[ "$answer" =~ ^[Yy] ]]
}

# ============================================
# UNINSTALLATION
# ============================================

print_banner() {
    echo ""
    echo -e "${RED}"
    cat << 'EOF'
    ____             __        __    __     ____        __      __
   / __ \____  _____/ /_____ _/ /_  / /__  / __ \____ _/ /___  / /_
  / /_/ / __ \/ ___/ __/ __ `/ __ \/ / _ \/ /_/ / __ `/ / __ \/ __ \
 / ____/ /_/ / /  / /_/ /_/ / /_/ / /  __/ _, _/ /_/ / / /_/ / / / /
/_/    \____/_/   \__/\__,_/_.___/_/\___/_/ |_|\__,_/_/ .___/_/ /_/
                                                      /_/
                        UNINSTALLER
EOF
    echo -e "${NC}"
    echo -e "  Version $VERSION"
    echo ""
}

confirm_uninstall() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    warn "This will remove PortableRalph from your system."
    echo ""
    echo "The following will be removed:"
    echo "  - Installation directory: $INSTALL_DIR"
    if [[ "$KEEP_CONFIG" != "true" ]]; then
        echo "  - Configuration file: ~/.ralph.env"
    fi
    echo "  - Shell configuration (aliases in ~/.bashrc or ~/.zshrc)"
    echo "  - Running monitor processes"
    echo ""

    if ! prompt_yn "Are you sure you want to uninstall PortableRalph?" "n"; then
        error "Uninstallation cancelled."
        exit 0
    fi
}

stop_running_processes() {
    log "Stopping running Ralph monitor processes..."

    local pids
    pids=$(pgrep -f "ralph.*monitor-progress" 2>/dev/null || true)

    if [[ -n "$pids" ]]; then
        info "Found running monitor processes: $pids"
        echo "$pids" | while read -r pid; do
            if kill "$pid" 2>/dev/null; then
                success "Stopped process $pid"
            else
                warn "Could not stop process $pid (may require sudo)"
            fi
        done

        # Wait a bit for graceful shutdown
        sleep 2

        # Force kill any remaining processes
        pids=$(pgrep -f "ralph.*monitor-progress" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            warn "Force stopping remaining processes..."
            echo "$pids" | while read -r pid; do
                kill -9 "$pid" 2>/dev/null || true
            done
        fi
    else
        info "No running monitor processes found"
    fi
}

remove_shell_config() {
    log "Removing shell configuration..."

    local modified=false

    # Get shell config file if platform utils are available
    if command -v get_shell_config &>/dev/null; then
        local shell_config=$(get_shell_config)
        if [[ -f "$shell_config" ]]; then
            if grep -q "PortableRalph\|ralph.env\|alias ralph=" "$shell_config" 2>/dev/null; then
                cp "$shell_config" "${shell_config}.ralph-backup"
                sed -i.tmp '/# PortableRalph/,/alias ralph=/d' "$shell_config" 2>/dev/null || \
                    sed -i.bak '/# PortableRalph/,/alias ralph=/d' "$shell_config" 2>/dev/null || true
                rm -f "${shell_config}.tmp" "${shell_config}.bak" 2>/dev/null || true
                success "Removed configuration from $shell_config (backup: ${shell_config}.ralph-backup)"
                modified=true
            fi
        fi
    else
        # Fallback to checking standard Unix shell configs
        # Check and modify .bashrc
        if [[ -f "${USER_HOME}/.bashrc" ]]; then
            if grep -q "PortableRalph\|ralph.env\|alias ralph=" "${USER_HOME}/.bashrc" 2>/dev/null; then
                cp "${USER_HOME}/.bashrc" "${USER_HOME}/.bashrc.ralph-backup"
                sed -i.tmp '/# PortableRalph/,/alias ralph=/d' "${USER_HOME}/.bashrc" 2>/dev/null || \
                    sed -i.bak '/# PortableRalph/,/alias ralph=/d' "${USER_HOME}/.bashrc" 2>/dev/null || true
                rm -f "${USER_HOME}/.bashrc.tmp" "${USER_HOME}/.bashrc.bak" 2>/dev/null || true
                success "Removed configuration from ~/.bashrc (backup: ~/.bashrc.ralph-backup)"
                modified=true
            fi
        fi

        # Check and modify .zshrc
        if [[ -f "${USER_HOME}/.zshrc" ]]; then
            if grep -q "PortableRalph\|ralph.env\|alias ralph=" "${USER_HOME}/.zshrc" 2>/dev/null; then
                cp "${USER_HOME}/.zshrc" "${USER_HOME}/.zshrc.ralph-backup"
                sed -i.tmp '/# PortableRalph/,/alias ralph=/d' "${USER_HOME}/.zshrc" 2>/dev/null || \
                    sed -i.bak '/# PortableRalph/,/alias ralph=/d' "${USER_HOME}/.zshrc" 2>/dev/null || true
                rm -f "${USER_HOME}/.zshrc.tmp" "${USER_HOME}/.zshrc.bak" 2>/dev/null || true
                success "Removed configuration from ~/.zshrc (backup: ~/.zshrc.ralph-backup)"
                modified=true
            fi
        fi
    fi

    if ! $modified; then
        info "No shell configuration found"
    fi
}

remove_config_file() {
    local config_file="${USER_HOME}/.ralph.env"

    if [[ "$KEEP_CONFIG" == "true" ]]; then
        info "Keeping configuration file: $config_file"
        return
    fi

    if [[ -f "$config_file" ]]; then
        log "Removing configuration file..."
        if rm "$config_file"; then
            success "Removed $config_file"
        else
            warn "Could not remove $config_file (check permissions)"
        fi
    else
        info "No configuration file found"
    fi
}

remove_installation_dir() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        info "Installation directory not found: $INSTALL_DIR"
        return
    fi

    log "Removing installation directory: $INSTALL_DIR"

    if rm -rf "$INSTALL_DIR"; then
        success "Removed $INSTALL_DIR"
    else
        error "Could not remove $INSTALL_DIR (check permissions)"
        exit 1
    fi
}

remove_portableralph_dir() {
    local pr_dir="${USER_HOME}/.portableralph"

    if [[ -d "$pr_dir" ]]; then
        log "Removing PortableRalph data directory..."

        if [[ "$FORCE" == "true" ]] || prompt_yn "Remove ~/.portableralph (contains logs and state)?" "y"; then
            if rm -rf "$pr_dir"; then
                success "Removed ~/.portableralph"
            else
                warn "Could not remove ~/.portableralph (check permissions)"
            fi
        else
            info "Keeping ~/.portableralph"
        fi
    else
        info "No data directory found"
    fi
}

print_completion_message() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  PortableRalph has been uninstalled${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ "$KEEP_CONFIG" == "true" ]]; then
        info "Your configuration was preserved at: ~/.ralph.env"
    fi

    echo -e "  ${BOLD}Next steps:${NC}"
    echo ""
    echo -e "    ${CYAN}# Reload your shell to remove ralph alias${NC}"
    echo -e "    source ~/.bashrc  ${BOLD}# or ~/.zshrc${NC}"
    echo ""

    if [[ -f "${USER_HOME}/.bashrc.ralph-backup" ]] || [[ -f "${USER_HOME}/.zshrc.ralph-backup" ]]; then
        info "Shell configuration backups created:"
        [[ -f "${USER_HOME}/.bashrc.ralph-backup" ]] && echo "  - ~/.bashrc.ralph-backup"
        [[ -f "${USER_HOME}/.zshrc.ralph-backup" ]] && echo "  - ~/.zshrc.ralph-backup"
        echo ""
    fi

    echo -e "  To reinstall PortableRalph:"
    echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash${NC}"
    echo ""
    echo "  Thanks for using PortableRalph!"
    echo ""
}

# ============================================
# MAIN
# ============================================

main() {
    parse_args "$@"

    print_banner
    confirm_uninstall

    echo ""
    stop_running_processes
    remove_shell_config
    remove_config_file
    remove_installation_dir
    remove_portableralph_dir

    print_completion_message
}

main "$@"
