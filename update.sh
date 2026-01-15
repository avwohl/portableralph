#!/bin/bash
#
# PortableRalph Update Script
# Handles self-updating, version management, and rollback
#
# Usage:
#   ralph update              Update to latest version
#   ralph update --check      Check for updates without installing
#   ralph update --list       List all available versions
#   ralph update <version>    Install specific version
#   ralph rollback            Rollback to previous version
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GITHUB_REPO="aaron777collins/portableralph"
API_URL="https://api.github.com/repos/${GITHUB_REPO}"
VERSION_HISTORY="$HOME/.ralph_version_history"
BACKUP_DIR="$HOME/.ralph_backup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Get current version from ralph.sh
get_current_version() {
    if [ -f "$SCRIPT_DIR/ralph.sh" ]; then
        grep -E '^VERSION=' "$SCRIPT_DIR/ralph.sh" | head -1 | sed 's/VERSION="\(.*\)"/\1/'
    else
        echo "unknown"
    fi
}

CURRENT_VERSION=$(get_current_version)

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

# ============================================
# DEPENDENCY CHECKS
# ============================================

check_dependencies() {
    local missing=()

    # Need curl or wget
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        missing+=("curl or wget")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
        echo ""
        echo "Please install the missing dependencies and try again."
        exit 1
    fi

    # Check for optional tools
    if command -v git &>/dev/null; then
        USE_GIT=true
    else
        USE_GIT=false
        info "git not found - will use tarball download method"
    fi

    if command -v jq &>/dev/null; then
        USE_JQ=true
    else
        USE_JQ=false
    fi
}

# ============================================
# API FUNCTIONS
# ============================================

# Fetch data from URL
fetch_url() {
    local url="$1"
    if command -v curl &>/dev/null; then
        curl -sf --connect-timeout 10 "$url" 2>/dev/null
    else
        wget -qO- --timeout=10 "$url" 2>/dev/null
    fi
}

# Fetch releases from GitHub API
fetch_releases() {
    local response
    response=$(fetch_url "${API_URL}/releases") || {
        error "Failed to connect to GitHub"
        echo ""
        echo "Please check your internet connection and try again."
        echo "If you're behind a proxy, set the http_proxy environment variable."
        return 1
    }
    echo "$response"
}

# Fetch tags from GitHub API (fallback if no releases)
fetch_tags() {
    local response
    response=$(fetch_url "${API_URL}/tags") || {
        error "Failed to fetch tags from GitHub"
        return 1
    }
    echo "$response"
}

# Parse version from string (remove 'v' prefix)
parse_version() {
    local ver="$1"
    echo "${ver#v}"
}

# Extract versions from API response
extract_versions() {
    local json="$1"

    if $USE_JQ; then
        echo "$json" | jq -r '.[].tag_name // .[].name' 2>/dev/null | sed 's/^v//'
    else
        # Fallback: basic grep/sed parsing
        echo "$json" | grep -oE '"tag_name"\s*:\s*"v?[0-9]+\.[0-9]+\.[0-9]+"' | \
            sed 's/"tag_name"\s*:\s*"v\?\([^"]*\)"/\1/' || \
        echo "$json" | grep -oE '"name"\s*:\s*"v?[0-9]+\.[0-9]+\.[0-9]+"' | \
            sed 's/"name"\s*:\s*"v\?\([^"]*\)"/\1/'
    fi
}

# Get latest version from GitHub
get_latest_version() {
    local releases
    releases=$(fetch_releases) || return 1

    local versions
    versions=$(extract_versions "$releases")

    if [ -z "$versions" ]; then
        # Fallback to tags if no releases
        local tags
        tags=$(fetch_tags) || return 1
        versions=$(extract_versions "$tags")
    fi

    if [ -z "$versions" ]; then
        error "No versions found on GitHub"
        return 1
    fi

    # Return first (latest) version
    echo "$versions" | head -1
}

# Get all available versions
get_all_versions() {
    local releases
    releases=$(fetch_releases) || return 1

    local versions
    versions=$(extract_versions "$releases")

    if [ -z "$versions" ]; then
        local tags
        tags=$(fetch_tags) || return 1
        versions=$(extract_versions "$tags")
    fi

    echo "$versions"
}

# Compare two versions
# Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
compare_versions() {
    local v1=$(parse_version "$1")
    local v2=$(parse_version "$2")

    if [[ "$v1" == "$v2" ]]; then
        echo 0
        return
    fi

    # Use sort -V for version comparison
    local lower
    lower=$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -1)

    if [[ "$lower" == "$v1" ]]; then
        echo -1
    else
        echo 1
    fi
}

# ============================================
# VERSION HISTORY
# ============================================

record_version_history() {
    local new_version="$1"
    local old_version="$2"
    local timestamp
    timestamp=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

    # Create history file if doesn't exist
    if [ ! -f "$VERSION_HISTORY" ]; then
        echo "# Ralph Version History" > "$VERSION_HISTORY"
        echo "# Format: VERSION|DATE|PREVIOUS_VERSION" >> "$VERSION_HISTORY"
    fi

    echo "${new_version}|${timestamp}|${old_version}" >> "$VERSION_HISTORY"
}

get_previous_version() {
    if [ -f "$VERSION_HISTORY" ]; then
        # Get the second-to-last version entry
        grep -v '^#' "$VERSION_HISTORY" | tail -2 | head -1 | cut -d'|' -f1
    elif [ -f "$BACKUP_DIR/.version" ]; then
        cat "$BACKUP_DIR/.version"
    else
        echo ""
    fi
}

# ============================================
# BACKUP AND RESTORE
# ============================================

backup_current() {
    log "Backing up current installation..."

    # Remove old backup, keep only one
    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    # Copy essential files
    local files_to_backup=(
        "ralph.sh"
        "install.sh"
        "notify.sh"
        "setup-notifications.sh"
        "update.sh"
        "PROMPT_plan.md"
        "PROMPT_build.md"
    )

    for file in "${files_to_backup[@]}"; do
        if [ -f "$SCRIPT_DIR/$file" ]; then
            cp "$SCRIPT_DIR/$file" "$BACKUP_DIR/"
        fi
    done

    # Record backup version
    echo "$CURRENT_VERSION" > "$BACKUP_DIR/.version"

    success "Backup complete"
}

restore_backup() {
    if [[ ! -d "$BACKUP_DIR" ]] || [[ ! -f "$BACKUP_DIR/.version" ]]; then
        error "No backup found. Cannot rollback."
        echo "" >&2
        echo "Rollback is only available after an update." >&2
        exit 1
    fi

    local backup_version
    backup_version=$(cat "$BACKUP_DIR/.version")

    log "Restoring backup (v$backup_version)..."

    # Restore files
    for file in "$BACKUP_DIR"/*.sh "$BACKUP_DIR"/*.md; do
        if [ -f "$file" ]; then
            cp "$file" "$SCRIPT_DIR/"
        fi
    done

    # Make scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh

    success "Restored v$backup_version"

    echo "$backup_version"
}

# ============================================
# UPDATE FUNCTIONS
# ============================================

check_for_updates() {
    echo -e "${BOLD}PortableRalph${NC} v${CURRENT_VERSION}"
    echo ""
    log "Checking for updates..."

    local latest
    latest=$(get_latest_version) || exit 1

    echo -e "  Current version: ${YELLOW}$CURRENT_VERSION${NC}"
    echo -e "  Latest version:  ${GREEN}$latest${NC}"
    echo ""

    local cmp
    cmp=$(compare_versions "$CURRENT_VERSION" "$latest")

    if [ "$cmp" -eq 0 ]; then
        success "You're on the latest version!"
    elif [ "$cmp" -lt 0 ]; then
        echo -e "${GREEN}A new version is available!${NC}"
        echo ""
        echo -e "Run ${CYAN}ralph update${NC} to upgrade."
    else
        info "You're ahead of the latest release (development version?)"
    fi
}

list_versions() {
    echo -e "${BOLD}Available PortableRalph versions:${NC}"
    echo ""

    local versions
    versions=$(get_all_versions) || exit 1

    local latest
    latest=$(echo "$versions" | head -1)

    while IFS= read -r ver; do
        if [ -z "$ver" ]; then
            continue
        fi

        local prefix="   "
        local suffix=""

        if [ "$ver" = "$latest" ]; then
            suffix=" ${GREEN}(latest)${NC}"
        fi

        if [ "$ver" = "$CURRENT_VERSION" ]; then
            prefix=" ${GREEN}*${NC} "
            suffix="$suffix ${BLUE}(installed)${NC}"
        fi

        echo -e "${prefix}v${ver}${suffix}"
    done <<< "$versions"

    echo ""
    echo -e "Use ${CYAN}ralph update <version>${NC} to install a specific version."
}

install_version() {
    local target_version="$1"
    target_version=$(parse_version "$target_version")

    local tag="v${target_version}"

    # Verify version exists
    local versions
    versions=$(get_all_versions) || exit 1

    if ! echo "$versions" | grep -qx "$target_version"; then
        error "Version '$target_version' not found"
        echo ""
        echo "Available versions:"
        list_versions
        exit 1
    fi

    # Check if already on this version
    if [ "$target_version" = "$CURRENT_VERSION" ]; then
        info "Already on version $target_version"
        exit 0
    fi

    log "Installing version $tag..."

    # Backup current version
    backup_current

    if $USE_GIT && [ -d "$SCRIPT_DIR/.git" ]; then
        # Git method (preferred)
        log "Fetching version $tag..."
        (
            cd "$SCRIPT_DIR"
            git fetch --tags --quiet 2>/dev/null || git fetch --quiet
            git checkout "$tag" --quiet 2>/dev/null || {
                # If tag checkout fails, try fetching and checking out
                git fetch origin "refs/tags/$tag:refs/tags/$tag" --quiet 2>/dev/null
                git checkout "$tag" --quiet
            }
        ) || {
            error "Failed to checkout version $tag"
            warn "Restoring backup..."
            restore_backup >/dev/null
            exit 1
        }
    else
        # Tarball method (fallback)
        log "Downloading version $tag..."
        local tarball_url="https://github.com/${GITHUB_REPO}/archive/refs/tags/${tag}.tar.gz"
        local tmp_dir
        tmp_dir=$(mktemp -d)

        if command -v curl &>/dev/null; then
            curl -sL "$tarball_url" | tar xz -C "$tmp_dir" 2>/dev/null
        else
            wget -qO- "$tarball_url" | tar xz -C "$tmp_dir" 2>/dev/null
        fi

        if [ $? -ne 0 ] || [ ! -d "$tmp_dir"/portableralph-* ]; then
            error "Failed to download version $tag"
            rm -rf "$tmp_dir"
            warn "Restoring backup..."
            restore_backup >/dev/null
            exit 1
        fi

        # Copy files from extracted archive
        cp -r "$tmp_dir"/portableralph-*/* "$SCRIPT_DIR/" 2>/dev/null || \
        cp -r "$tmp_dir"/*/* "$SCRIPT_DIR/" 2>/dev/null

        rm -rf "$tmp_dir"
    fi

    # Make scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

    # Record in history
    record_version_history "$target_version" "$CURRENT_VERSION"

    success "Successfully installed v$target_version"
    echo ""
    echo -e "Run ${CYAN}ralph rollback${NC} to revert to v$CURRENT_VERSION"
}

update_to_latest() {
    echo -e "${BOLD}PortableRalph${NC} v${CURRENT_VERSION}"
    echo ""

    log "Checking for updates..."

    local latest
    latest=$(get_latest_version) || exit 1

    local cmp
    cmp=$(compare_versions "$CURRENT_VERSION" "$latest")

    if [ "$cmp" -eq 0 ]; then
        success "You're already on the latest version (v$CURRENT_VERSION)"
        exit 0
    elif [ "$cmp" -gt 0 ]; then
        info "You're ahead of the latest release (v$CURRENT_VERSION > v$latest)"
        echo ""
        echo "Use 'ralph update $latest' to downgrade to the latest release."
        exit 0
    fi

    echo -e "  Updating: ${YELLOW}v$CURRENT_VERSION${NC} → ${GREEN}v$latest${NC}"
    echo ""

    install_version "$latest"
}

rollback() {
    echo -e "${BOLD}PortableRalph${NC} Rollback"
    echo ""

    local backup_version
    backup_version=$(restore_backup)

    if [ -n "$backup_version" ]; then
        # Record in history
        record_version_history "$backup_version" "$CURRENT_VERSION"

        echo ""
        success "Successfully rolled back to v$backup_version"
    fi
}

# ============================================
# USAGE
# ============================================

usage() {
    echo -e "${BOLD}PortableRalph Update${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ralph update              Update to latest version"
    echo "  ralph update --check      Check for updates without installing"
    echo "  ralph update --list       List all available versions"
    echo "  ralph update <version>    Install specific version (e.g., 1.4.0)"
    echo "  ralph rollback            Rollback to previous version"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ralph update              # Update to latest"
    echo "  ralph update --check      # Check if updates available"
    echo "  ralph update 1.4.0        # Install version 1.4.0"
    echo "  ralph update v1.4.0       # Also works with 'v' prefix"
    echo "  ralph rollback            # Revert to previous version"
    echo ""
    echo -e "${YELLOW}Version History:${NC}"
    echo "  Stored in ~/.ralph_version_history"
    echo ""
    echo -e "${YELLOW}Backup:${NC}"
    echo "  Previous version is backed up to ~/.ralph_backup/"
    echo "  Use 'ralph rollback' to restore"
}

# ============================================
# MAIN
# ============================================

main() {
    check_dependencies

    case "${1:-}" in
        --help|-h|help)
            usage
            ;;
        --check|-c|check)
            check_for_updates
            ;;
        --list|-l|list)
            list_versions
            ;;
        --rollback|-r|rollback)
            rollback
            ;;
        "")
            update_to_latest
            ;;
        --*)
            error "Unknown option: $1"
            echo ""
            usage
            exit 1
            ;;
        *)
            # Assume it's a version number
            install_version "$1"
            ;;
    esac
}

main "$@"
