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

# Load constants
if [ -f "$SCRIPT_DIR/lib/constants.sh" ]; then
    source "$SCRIPT_DIR/lib/constants.sh"
fi

# Load platform utilities for cross-platform support
if [ -f "$SCRIPT_DIR/lib/platform-utils.sh" ]; then
    source "$SCRIPT_DIR/lib/platform-utils.sh"
    USER_HOME=$(get_home_dir)
else
    USER_HOME="${HOME}"
fi

GITHUB_REPO="aaron777collins/portableralph"
API_URL="https://api.github.com/repos/${GITHUB_REPO}"
VERSION_HISTORY="${USER_HOME}/.ralph_version_history"
BACKUP_DIR="${USER_HOME}/.ralph_backups"
MAX_BACKUPS="${UPDATE_MAX_BACKUPS:-5}"  # Keep last N backups

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
        # Use parameter expansion instead of sed to prevent injection
        local version_line
        version_line=$(grep -E '^VERSION=' "$SCRIPT_DIR/ralph.sh" | head -1)
        # Extract value between quotes using bash parameter expansion
        version_line="${version_line#*\"}"  # Remove prefix up to first "
        version_line="${version_line%\"*}"  # Remove suffix from last "
        echo "$version_line"
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
    local connect_timeout="${HTTP_CONNECT_TIMEOUT:-10}"
    if command -v curl &>/dev/null; then
        curl -sf --connect-timeout "$connect_timeout" "$url" 2>/dev/null
    else
        wget -qO- --timeout="$connect_timeout" "$url" 2>/dev/null
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
        # Fallback: basic grep/awk parsing (safer than sed with untrusted input)
        # Extract tag_name or name fields and remove 'v' prefix
        echo "$json" | grep -oE '"(tag_name|name)"\s*:\s*"v?[0-9]+\.[0-9]+\.[0-9]+"' | \
            awk -F'"' '{
                # Extract the version value (4th field after splitting by ")
                version = $4
                # Remove v prefix if present
                sub(/^v/, "", version)
                print version
            }'
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

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Rotate existing backups (keep last MAX_BACKUPS)
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="backup_${CURRENT_VERSION}_${timestamp}"
    local backup_path="$BACKUP_DIR/$backup_name"

    # Create new backup
    mkdir -p "$backup_path"

    # Copy essential files
    local files_to_backup=(
        "ralph.sh"
        "install.sh"
        "notify.sh"
        "setup-notifications.sh"
        "update.sh"
        "monitor-progress.sh"
        "start-monitor.sh"
        "PROMPT_plan.md"
        "PROMPT_build.md"
    )

    for file in "${files_to_backup[@]}"; do
        if [ -f "$SCRIPT_DIR/$file" ]; then
            cp "$SCRIPT_DIR/$file" "$backup_path/"
        fi
    done

    # Record backup version and timestamp
    echo "$CURRENT_VERSION" > "$backup_path/.version"
    echo "$timestamp" > "$backup_path/.timestamp"

    # Create symlink to latest backup
    ln -sfn "$backup_name" "$BACKUP_DIR/latest"

    # Rotate old backups (keep only MAX_BACKUPS)
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" | wc -l)

    if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
        local to_remove=$((backup_count - MAX_BACKUPS))
        # Remove oldest backups
        find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" -printf '%T@ %p\n' | \
            sort -n | head -n "$to_remove" | cut -d' ' -f2- | \
            xargs rm -rf
        info "Removed $to_remove old backup(s), keeping last $MAX_BACKUPS"
    fi

    success "Backup complete (saved as $backup_name)"
}

restore_backup() {
    local latest_backup="$BACKUP_DIR/latest"

    if [[ ! -L "$latest_backup" ]] && [[ ! -d "$latest_backup" ]]; then
        error "No backup found. Cannot rollback."
        echo "" >&2
        echo "Rollback is only available after an update." >&2
        echo "" >&2
        echo "Available backups:"
        if [ -d "$BACKUP_DIR" ]; then
            find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" -exec basename {} \; | sort -r | head -5
        else
            echo "  (none)"
        fi
        exit 1
    fi

    # Resolve symlink to actual backup directory
    local backup_path
    if [ -L "$latest_backup" ]; then
        backup_path=$(readlink -f "$latest_backup")
    else
        backup_path="$latest_backup"
    fi

    if [[ ! -f "$backup_path/.version" ]]; then
        error "Backup is corrupted (missing .version file)"
        exit 1
    fi

    local backup_version
    backup_version=$(cat "$backup_path/.version")

    log "Restoring backup (v$backup_version)..."
    info "Backup location: $backup_path"

    # Restore files
    local restored_count=0
    for file in "$backup_path"/*.sh "$backup_path"/*.md; do
        if [ -f "$file" ]; then
            cp "$file" "$SCRIPT_DIR/"
            ((restored_count++))
        fi
    done

    if [ $restored_count -eq 0 ]; then
        error "No files found in backup directory"
        exit 1
    fi

    # Make scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

    success "Restored v$backup_version ($restored_count files)"

    echo "$backup_version"
}

# ============================================
# SECURITY: SIGNATURE VERIFICATION
# ============================================

# Verify GPG signature for git tags (if gpg is available)
verify_git_tag_signature() {
    local tag="$1"

    # Skip if GPG not available
    if ! command -v gpg &>/dev/null; then
        warn "GPG not found - skipping signature verification"
        warn "Install gpg for enhanced security: apt-get install gnupg"
        return 0
    fi

    # Check if tag is signed
    if ! git tag -v "$tag" &>/dev/null; then
        warn "Tag $tag is not signed or signature cannot be verified"
        warn "This may be a security risk. Proceeding anyway..."
        return 0  # Don't fail, just warn
    fi

    info "GPG signature verified for $tag"
    return 0
}

# Verify checksum of downloaded tarball
verify_tarball_checksum() {
    local tarball_path="$1"
    local version="$2"

    # Try to download checksum file from GitHub releases
    local checksum_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/checksums.txt"
    local checksums
    checksums=$(fetch_url "$checksum_url" 2>/dev/null)

    if [ -z "$checksums" ]; then
        warn "No checksums file found for $version - skipping verification"
        return 0
    fi

    # Calculate SHA256 of tarball
    local calculated_sha256
    if command -v sha256sum &>/dev/null; then
        calculated_sha256=$(sha256sum "$tarball_path" | awk '{print $1}')
    elif command -v shasum &>/dev/null; then
        calculated_sha256=$(shasum -a 256 "$tarball_path" | awk '{print $1}')
    else
        warn "sha256sum/shasum not found - skipping checksum verification"
        return 0
    fi

    # Look for matching checksum in checksums file
    local tarball_name
    tarball_name=$(basename "$tarball_path")

    if echo "$checksums" | grep -q "$calculated_sha256"; then
        info "Checksum verified for $tarball_name"
        return 0
    else
        error "Checksum verification FAILED for $tarball_name"
        error "This may indicate a corrupted or tampered download"
        return 1
    fi
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
    local skip_confirmation="${2:-false}"
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

    # Ask for confirmation unless skipped (for automation)
    if [ "$skip_confirmation" != "true" ]; then
        echo ""
        echo -e "${YELLOW}This will update Ralph from v$CURRENT_VERSION to v$target_version${NC}"
        echo "A backup will be created automatically for rollback."
        echo ""
        read -p "Continue with update? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Update cancelled"
            exit 0
        fi
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

            # Verify signature if GPG is available
            verify_git_tag_signature "$tag" || {
                warn "Signature verification had issues, but continuing..."
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
        tmp_dir=$(mktemp -d) || {
            error "Failed to create temporary directory"
            warn "Restoring backup..."
            restore_backup >/dev/null
            exit 1
        }
        chmod 700 "$tmp_dir"
        trap 'rm -rf "$tmp_dir" 2>/dev/null' RETURN
        local tarball_file="$tmp_dir/release.tar.gz"

        # Download tarball to file first (for checksum verification)
        if command -v curl &>/dev/null; then
            curl -sL "$tarball_url" -o "$tarball_file" 2>/dev/null
        else
            wget -qO "$tarball_file" "$tarball_url" 2>/dev/null
        fi

        if [ $? -ne 0 ] || [ ! -f "$tarball_file" ]; then
            error "Failed to download version $tag"
            rm -rf "$tmp_dir"
            warn "Restoring backup..."
            restore_backup >/dev/null
            exit 1
        fi

        # Verify checksum if available
        if ! verify_tarball_checksum "$tarball_file" "$tag"; then
            error "Checksum verification failed - aborting installation"
            rm -rf "$tmp_dir"
            warn "Restoring backup..."
            restore_backup >/dev/null
            exit 1
        fi

        # Extract verified tarball
        tar xzf "$tarball_file" -C "$tmp_dir" 2>/dev/null

        if [ $? -ne 0 ] || [ ! -d "$tmp_dir"/portableralph-* ]; then
            error "Failed to extract version $tag"
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

    # Check if backup exists first
    local latest_backup="$BACKUP_DIR/latest"
    if [[ ! -L "$latest_backup" ]] && [[ ! -d "$latest_backup" ]]; then
        error "No backup found. Cannot rollback."
        echo ""
        echo "Backups are created automatically when you run 'ralph update'."
        exit 1
    fi

    # Get backup version for display
    local backup_info=""
    if [ -f "$BACKUP_DIR/latest/ralph.sh" ]; then
        local backup_ver
        local version_line
        version_line=$(grep -E '^VERSION=' "$BACKUP_DIR/latest/ralph.sh" | head -1 2>/dev/null || echo "")
        if [ -n "$version_line" ]; then
            # Use parameter expansion instead of sed to prevent injection
            version_line="${version_line#*\"}"  # Remove prefix up to first "
            backup_ver="${version_line%\"*}"    # Remove suffix from last "
        else
            backup_ver="unknown"
        fi
        backup_info=" to v$backup_ver"
    fi

    # Ask for confirmation
    echo -e "${YELLOW}This will rollback Ralph from v$CURRENT_VERSION$backup_info${NC}"
    echo "Your current version will be lost unless you have a backup."
    echo ""
    read -p "Continue with rollback? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Rollback cancelled"
        exit 0
    fi

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
