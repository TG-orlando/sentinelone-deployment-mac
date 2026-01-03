# SentinelOne Deployment for macOS

Enterprise deployment script for SentinelOne EDR on macOS endpoints via Rippling MDM and other deployment tools.

## Quick Deploy

### One-Liner Installation (Rippling MDM)

```bash
curl -fsSL https://raw.githubusercontent.com/TG-orlando/sentinelone-deployment-mac/main/install-sentinelone.sh | sudo bash
```

### Manual Installation

```bash
# Download the installation script
curl -fsSL https://raw.githubusercontent.com/TG-orlando/sentinelone-deployment-mac/main/install-sentinelone.sh -o install-sentinelone.sh

# Make executable
chmod +x install-sentinelone.sh

# Run with sudo
sudo ./install-sentinelone.sh
```

## Configuration

### Site Token

The script supports multiple methods for providing the SentinelOne site token:

**Option 1: Environment Variable (Most Secure)**
```bash
# Set environment variable before running
export SENTINELONE_SITE_TOKEN="your_site_token_here"
sudo -E ./install-sentinelone.sh

# Or inline
sudo SENTINELONE_SITE_TOKEN="your_token" bash -c "$(curl -fsSL https://raw.githubusercontent.com/TG-orlando/sentinelone-deployment-mac/main/install-sentinelone.sh)"
```

**Option 2: Edit Default Token in Script**
- Update the `DEFAULT_SITE_TOKEN` variable in `install-sentinelone.sh`
- Commit and push to your repository
- Use the one-liner deployment

**Option 3: Rippling MDM Environment Variable**
- Set `SENTINELONE_SITE_TOKEN` as an environment variable in Rippling
- Script will automatically use it

### Get Your Site Token

1. Login to SentinelOne Console: https://usea1-017.sentinelone.net
2. Navigate to: **Sentinels** > **Site** > **Generate Token**
3. Copy the site token (base64 encoded string)

## Full Disk Access

SentinelOne requires Full Disk Access (FDA) for complete endpoint protection.

### ✅ Automatic FDA Installation

**The installation script automatically installs the PPPC profile!**

When you run the one-liner, the script will:
1. Download the PPPC profile from GitHub
2. Install it using `profiles install` command
3. Grant Full Disk Access automatically
4. No manual steps or separate MDM profile deployment needed

### Manual FDA Grant (Fallback)

If automatic installation fails (rare):
1. System Settings > Privacy & Security > Full Disk Access
2. Click '+' and add: `/Library/Sentinel/sentinel-agent.bundle`
3. Enable the toggle

### Alternative: Deploy PPPC Profile via MDM

You can also deploy the profile separately via Rippling MDM:
1. Download: [SentinelOne-PPPC-Profile.mobileconfig](https://github.com/TG-orlando/sentinelone-deployment-mac/blob/main/SentinelOne-PPPC-Profile.mobileconfig)
2. Upload to Rippling MDM
3. Deploy before running installation script

## Prerequisites

1. **Upload SentinelOne Installer to GitHub Releases:**
   - Download installer from SentinelOne Console
   - Go to: [Releases](https://github.com/TG-orlando/sentinelone-deployment-mac/releases)
   - Create new release tagged `v1.0.0`
   - Upload installer as `SentinelInstaller.pkg`

2. **Configure Site Token** (see Configuration section above)

✅ **That's it!** The PPPC profile installs automatically during the installation.

## Features

The installation script includes:

- **Automatic privilege elevation** (prompts for sudo if needed)
- **Environment variable support** for secure token management
- **Pre-installation checks**
  - macOS version detection
  - Existing installation detection
  - Service status verification
- **Download timeout protection** (10 minutes)
- **Optional SHA256 hash verification**
- **Existing installation handling**
  - Stops running agent before upgrade
  - PKG installer handles upgrades automatically
- **Comprehensive logging**
  - Color-coded output (ERROR/WARNING/SUCCESS/INFO)
  - Detailed installation logs
  - Shows error details on failure
- **Installation verification**
  - Version detection
  - Agent process check
  - Service status verification
- **Site token configuration**
  - Sets token via sentinelctl
  - Auto-activation on first run
- **Automatic cleanup** of temporary files

## Files

- **install-sentinelone.sh** - Automated installation script with comprehensive error handling
- **SentinelOne-PPPC-Profile.mobileconfig** - Configuration profile for Full Disk Access
- **SentinelInstaller.pkg** - SentinelOne agent installer (uploaded to GitHub releases)

## Common Issues

### Exit Code Non-Zero
**Cause:** Installation failed
**Solution:**
1. Check logs at `/var/log/SentinelOne_Install.log`
2. Verify site token is correct
3. Ensure sufficient disk space
4. Check macOS version compatibility

### Agent Not Appearing in Console
**Cause:** Incorrect site token or network connectivity
**Solution:**
1. Verify site token matches your SentinelOne site
2. Check firewall allows outbound HTTPS to *.sentinelone.net
3. Review logs at `/tmp/SentinelOne_Install.log`

### Full Disk Access Not Granted
**Cause:** PPPC profile not deployed or manually denied
**Solution:**
1. Deploy PPPC profile via Rippling MDM
2. Or manually grant in System Settings > Privacy & Security
3. Restart SentinelOne agent after granting

## Supported Deployment Methods

- **Rippling MDM** (one-liner bash command)
- **Jamf Pro**
- **Kandji**
- **Mosyle**
- **SimpleMDM**
- **Other MDM tools**
- **Manual deployment**

## Security Best Practices

1. **Protect Site Token:**
   - Use environment variables when possible
   - Limit access to repository if token is hardcoded
   - Rotate tokens periodically in SentinelOne Console

2. **Verify Downloads:**
   - Enable SHA256 hash verification
   - Use HTTPS for all downloads
   - Download installers only from SentinelOne Console

3. **Monitor Deployments:**
   - Check SentinelOne Console for new agents
   - Review installation logs for errors
   - Verify agent policy application

4. **Use PPPC Profiles:**
   - Deploy via MDM for automatic FDA
   - Don't rely on manual user grants
   - Verify profile deployment status

## Updating the Installer

When SentinelOne releases a new agent version:

1. Download new installer from SentinelOne Console
2. Go to repository [Releases](https://github.com/TG-orlando/sentinelone-deployment-mac/releases)
3. Create new release (e.g., `v1.0.1`)
4. Upload new installer as `SentinelInstaller.pkg`
5. Update `DOWNLOAD_URL` in script if release tag changed
6. Optionally: Update `EXPECTED_HASH` with new installer's SHA256

## Logs

Installation logs are saved to:
- **Install log:** `/tmp/SentinelOne_Install.log`
- **System log:** `/var/log/SentinelOne_Install.log`

Review these logs if installation fails.

## Support

- **SentinelOne Console:** https://usea1-017.sentinelone.net
- **SentinelOne Support:** https://support.sentinelone.com
- **Deployment Issues:** Open an issue in this repository

## macOS Compatibility

- **Minimum:** macOS 10.15 (Catalina)
- **Recommended:** macOS 12+ (Monterey or later)
- **Full Disk Access:** Required for complete protection
- **System Integrity Protection:** Must be enabled

## License

This deployment script is provided as-is for enterprise use with SentinelOne.
