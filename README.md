
Warning: vibe-coded but works on my system.
Temp fix until Virtualmin get Debian Trixie compability.

# Virtualmin Dovecot Compatibility Fix

This script automatically fixes Dovecot configuration on systems where Virtualmin generates outdated settings for newer Dovecot versions, such as those found in Debian 13 "Trixie" and other modern Linux distributions.

## The Problem

When managing mail for a domain (e.g., creating a domain, updating an SSL certificate), Virtualmin may write a `dovecot.conf` file with deprecated parameters. This will cause the Dovecot service to fail to start or reload.

This script detects and fixes the following common issues:
- `mail_location` is corrected to `mail_path`
- `disable_plaintext_auth = no` is corrected to `auth_allow_cleartext = yes`
- `ssl_cert = </path/to/cert` is corrected to `ssl_server_cert_file = /path/to/cert`
- `ssl_key = </path/to/key` is corrected to `ssl_server_key_file = /path/to/key`

## One-Time Manual Fix (Required)

Before automating the fix, you should perform one manual configuration change. Newer Dovecot versions have a different default `pop3_uidl_format`. If this is not updated, POP3 clients may re-download all emails after the Dovecot upgrade. This setting is not touched by Virtualmin, so you only need to fix it once.

1.  Open the POP3 configuration file:
    ```sh
    nano /etc/dovecot/conf.d/20-pop3.conf
    ```

2.  Find the `pop3_uidl_format` line. If it is commented out or missing, add it with the new default value:
    ```ini
    pop3_uidl_format = %{uid | hex(8)}%{uidvalidity | hex(8)}
    ```

3.  Save the file and restart Dovecot to apply:
    ```sh
    systemctl restart dovecot
    ```

## Automated Fix Installation

This script should be run automatically after Virtualmin makes changes. Follow these steps to install the script.

1.  **Download the Script**
    Download the `fix_dovecot_config.sh` script to your server.
    ```sh
    wget https://raw.githubusercontent.com/your-username/virtualmin-dovecot-trixie-fix/main/fix_dovecot_config.sh
    ```

2.  **Move and Make Executable**
    Place the script in a standard location for system binaries and make it executable.
    ```sh
    sudo mv fix_dovecot_config.sh /usr/local/sbin/
    sudo chmod +x /usr/local/sbin/fix_dovecot_config.sh
    ```

## Choose Your Automation Method

Select one of the following methods to trigger the script automatically.

### Method 1: Virtualmin Post-Change Hook (Recommended)

This is the cleanest method, as it hooks directly into Virtualmin's workflow.

1.  Log into Virtualmin as `root`.
2.  Navigate to **System Settings** -> **Server Templates**.
3.  Select your default template (e.g., **Default Settings**) and click **Mail for domain**.
4.  Find the field **Command to run after making changes**.
5.  Enter the full path to the script:
    ```
    /usr/local/sbin/fix_dovecot_config.sh
    ```
6.  Click **Save**.

### Method 2: Systemd/inotify Watcher (Most Robust)

This method watches the configuration file for any changes and runs the script instantly. It's a great failsafe.

1.  **Install `inotify-tools`**:
    ```sh
    # Debian/Ubuntu
    sudo apt-get update && sudo apt-get install inotify-tools
    # CentOS/RHEL/Fedora
    sudo yum install inotify-tools
    ```

2.  **Create a systemd service file**:
    ```sh
    sudo nano /etc/systemd/system/dovecot-config-watcher.service
    ```
    Paste the following content:
    ```ini
    [Unit]
    Description=Dovecot Config Watcher for Virtualmin Fixes
    After=network.target

    [Service]
    Type=simple
    ExecStart=/bin/sh -c 'while inotifywait -e modify,close_write /etc/dovecot/dovecot.conf; do /usr/local/sbin/fix_dovecot_config.sh; done'
    Restart=always
    User=root

    [Install]
    WantedBy=multi-user.target
    ```

3.  **Enable and start the service**:
    ```sh
    sudo systemctl daemon-reload
    sudo systemctl enable --now dovecot-config-watcher.service
    ```

### Method 3: Cron Job (Simple)

A simple, time-based approach that runs the script every minute.

1.  Open the root crontab for editing:
    ```sh
    sudo crontab -e
    ```
2.  Add the following line to run the script every minute:
    ```crontab
    * * * * * /usr/local/sbin/fix_dovecot_config.sh > /dev/null 2>&1
    ```

## How the Script Works

The script is designed to be safe and efficient:
1.  It uses `grep` to quickly check if any of the outdated parameters exist in `/etc/dovecot/dovecot.conf`.
2.  If an old parameter is found, it uses `sed` to replace it with the modern equivalent.
3.  If any changes were made, it runs `dovecot -n` to test the new configuration syntax.
4.  Only if the test is successful, it proceeds to restart the Dovecot service using `systemctl`.
5.  If no changes are needed, the script exits silently without doing anything.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
