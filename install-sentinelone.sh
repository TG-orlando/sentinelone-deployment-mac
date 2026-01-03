#!/bin/bash
# SentinelOne Installation Script for macOS
# Version: 1.0
# For Rippling MDM Deployment

set -e

# ===== CONFIGURATION =====
# Download URL for SentinelOne PKG (from GitHub releases)
DOWNLOAD_URL="https://github.com/TG-orlando/sentinelone-deployment-mac/releases/download/v1.0.0/SentinelInstaller.pkg"

# Site token for SentinelOne activation
# Priority: Environment variable > Default token
# Get token from: SentinelOne Console > Sentinels > Site > Generate Token
DEFAULT_SITE_TOKEN="eyJ1cmwiOiAiaHR0cHM6Ly91c2VhMS0wMTcuc2VudGluZWxvbmUubmV0IiwgInNpdGVfa2V5IjogIjY5YWU3OWY4MDk3NjFlNmIifQ=="

SITE_TOKEN="${SENTINELONE_SITE_TOKEN:-$DEFAULT_SITE_TOKEN}"

# Optional: Expected SHA256 hash for verification
# Get this by running: shasum -a 256 SentinelInstaller.pkg
# EXPECTED_HASH="your_sha256_hash_here"
# ========================

# Paths
PKG_PATH="/tmp/SentinelInstaller.pkg"
LOG_PATH="/tmp/SentinelOne_Install.log"
INSTALL_LOG="/var/log/SentinelOne_Install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="$timestamp [$level] $message"

    echo "$log_entry" >> "$LOG_PATH"

    case "$level" in
        ERROR)
            echo -e "${RED}$message${NC}"
            ;;
        SUCCESS)
            echo -e "${GREEN}$message${NC}"
            ;;
        WARNING)
            echo -e "${YELLOW}$message${NC}"
            ;;
        INFO)
            echo -e "${CYAN}$message${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log ERROR "This script must be run as root or with sudo"
        log INFO "Attempting to elevate privileges..."
        exec sudo "$0" "$@"
    fi
    log SUCCESS "Running with root privileges"
}

main() {
    log INFO "========================================="
    log INFO "SentinelOne Installation Script v1.0"
    log INFO "For macOS Rippling MDM Deployment"
    log INFO "========================================="
    log INFO "Computer: $(hostname)"
    log INFO "User: $(whoami)"
    log INFO "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    log INFO "macOS Version: $(sw_vers -productVersion)"
    log INFO "========================================="
    echo ""

    # Check root privileges
    check_root "$@"
    echo ""

    # Validate site token
    if [ -z "$SITE_TOKEN" ]; then
        log ERROR "========================================="
        log ERROR "SITE TOKEN NOT CONFIGURED!"
        log ERROR "========================================="
        log ERROR "You must configure the site token before installation."
        log ERROR "Get your site token from: SentinelOne Console > Sentinels > Site > Generate Token"
        log ERROR "Set as environment variable: export SENTINELONE_SITE_TOKEN='your_token_here'"
        log ERROR "Or update DEFAULT_SITE_TOKEN in this script"
        log ERROR "========================================="
        exit 1
    fi

    local token_source="default in script"
    if [ -n "$SENTINELONE_SITE_TOKEN" ]; then
        token_source="environment variable"
    fi
    log SUCCESS "Site token configured: ${SITE_TOKEN:0:20}... (source: $token_source)"
    echo ""

    # Check for existing SentinelOne installation
    log INFO "Checking for existing SentinelOne installation..."
    if [ -d "/Library/Sentinel" ] || [ -d "/Applications/SentinelOne" ]; then
        log WARNING "Found existing SentinelOne installation"

        # Check if agent is running
        if pgrep -x "SentinelAgent" > /dev/null; then
            log WARNING "SentinelOne agent is currently running"
            log INFO "Stopping SentinelOne agent..."
            launchctl unload /Library/LaunchDaemons/com.sentinelone.* 2>/dev/null || true
            sleep 3
        fi

        # Note: SentinelOne pkg installer handles upgrades
        log INFO "Installer will upgrade existing installation"
    else
        log SUCCESS "No existing installation found"
    fi
    echo ""

    # Download installer
    log INFO "Downloading SentinelOne installer..."
    log INFO "URL: $DOWNLOAD_URL"

    if command -v curl >/dev/null 2>&1; then
        curl -L -f -o "$PKG_PATH" "$DOWNLOAD_URL" --connect-timeout 60 --max-time 600
    else
        log ERROR "curl command not found"
        exit 1
    fi

    if [ ! -f "$PKG_PATH" ]; then
        log ERROR "Download failed - installer not found at $PKG_PATH"
        exit 1
    fi

    local file_size=$(du -h "$PKG_PATH" | cut -f1)
    log SUCCESS "Download completed"
    log INFO "PKG File: $file_size"
    echo ""

    # Calculate hash if expected hash is configured
    if [ -n "${EXPECTED_HASH:-}" ]; then
        log INFO "Calculating SHA256 hash..."
        local actual_hash=$(shasum -a 256 "$PKG_PATH" | awk '{print $1}')
        log INFO "SHA256: $actual_hash"

        if [ "$actual_hash" != "$EXPECTED_HASH" ]; then
            log ERROR "Hash mismatch!"
            log ERROR "Expected: $EXPECTED_HASH"
            log ERROR "Got: $actual_hash"
            exit 1
        fi
        log SUCCESS "Hash verification passed"
    else
        local actual_hash=$(shasum -a 256 "$PKG_PATH" | awk '{print $1}')
        log INFO "SHA256: $actual_hash"
        log WARNING "Note: Hash verification skipped (no expected hash configured)"
    fi
    echo ""

    # Install SentinelOne
    log INFO "========================================="
    log INFO "Starting Installation"
    log INFO "========================================="
    log INFO "Using site token for automatic activation"
    echo ""

    # Install the package with site token
    log INFO "Running installer..."
    log INFO "Command: installer -pkg \"$PKG_PATH\" -target / -applyChoiceChangesXML /dev/stdin"

    # Create ChoiceChangesXML with site token
    cat > /tmp/sentinelone_choices.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>choiceAttribute</key>
        <string>customLocation</string>
        <key>attributeSetting</key>
        <string>/</string>
        <key>choiceIdentifier</key>
        <string>default</string>
    </dict>
</array>
</plist>
EOF

    # Install with site token as environment variable
    SITE_TOKEN="$SITE_TOKEN" installer -pkg "$PKG_PATH" -target / -verbose -dumplog > "$INSTALL_LOG" 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log SUCCESS "Installation completed successfully!"
    else
        log ERROR "========================================="
        log ERROR "INSTALLATION FAILED - Exit Code: $exit_code"
        log ERROR "========================================="
        log ERROR "Check logs at: $INSTALL_LOG"

        if [ -f "$INSTALL_LOG" ]; then
            log ERROR "Last 20 lines of install log:"
            tail -20 "$INSTALL_LOG" | while read line; do
                log ERROR "  $line"
            done
        fi

        exit $exit_code
    fi
    echo ""

    # Configure site token
    log INFO "Configuring site token..."
    if [ -f "/Library/Sentinel/sentinel-agent.bundle/Contents/MacOS/sentinelctl" ]; then
        /Library/Sentinel/sentinel-agent.bundle/Contents/MacOS/sentinelctl management token set "$SITE_TOKEN" 2>&1 | tee -a "$LOG_PATH"
        log SUCCESS "Site token configured"
    else
        log WARNING "sentinelctl not found - token will be configured on first run"
    fi
    echo ""

    # Verify installation
    log INFO "========================================="
    log INFO "Verifying installation..."
    log INFO "========================================="

    if [ -d "/Library/Sentinel" ]; then
        log SUCCESS "SentinelOne installed at: /Library/Sentinel"

        # Check version
        if [ -f "/Library/Sentinel/sentinel-agent.bundle/Contents/Info.plist" ]; then
            local version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Library/Sentinel/sentinel-agent.bundle/Contents/Info.plist 2>/dev/null)
            if [ -n "$version" ]; then
                log SUCCESS "Version: $version"
            fi
        fi

        # Check if agent is running
        sleep 5
        if pgrep -x "SentinelAgent" > /dev/null; then
            log SUCCESS "SentinelOne agent is running"
        else
            log WARNING "Agent not running yet - may start after reboot"
            log INFO "Loading agent..."
            launchctl load /Library/LaunchDaemons/com.sentinelone.* 2>/dev/null || true
            sleep 3

            if pgrep -x "SentinelAgent" > /dev/null; then
                log SUCCESS "SentinelOne agent started"
            fi
        fi
    else
        log ERROR "Installation verification failed - /Library/Sentinel not found"
        exit 1
    fi
    echo ""

    # Check Full Disk Access
    log INFO "Checking Full Disk Access..."
    log WARNING "Full Disk Access (FDA) is required for complete protection"
    log INFO ""
    log INFO "For automatic FDA deployment, use a PPPC profile via Rippling MDM"
    log INFO "Profile provided in: SentinelOne-PPPC-Profile.mobileconfig"
    log INFO ""
    log INFO "Or grant manually:"
    log INFO "  1. System Settings > Privacy & Security > Full Disk Access"
    log INFO "  2. Click '+' and add: /Library/Sentinel/sentinel-agent.bundle"
    log INFO "  3. Enable the toggle"
    echo ""

    # Cleanup
    log INFO "Cleaning up temporary files..."
    rm -f "$PKG_PATH" /tmp/sentinelone_choices.xml 2>/dev/null || true
    log SUCCESS "Cleanup completed"
    echo ""

    log INFO "========================================="
    log SUCCESS "INSTALLATION COMPLETED SUCCESSFULLY"
    log INFO "========================================="
    log INFO "Log file: $LOG_PATH"
    log INFO "Install log: $INSTALL_LOG"
    log INFO ""
    log INFO "Next steps:"
    log INFO "1. Deploy PPPC profile for Full Disk Access (via Rippling)"
    log INFO "2. Verify agent in SentinelOne console"
    log INFO "3. Check agent status: https://usea1-017.sentinelone.net"
    log INFO "4. Agent should auto-activate with the site token"
    log INFO "========================================="

    # Copy log to system log location
    cp "$LOG_PATH" "$INSTALL_LOG" 2>/dev/null || true

    exit 0
}

# Run main function
main "$@"
