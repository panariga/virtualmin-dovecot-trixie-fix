#!/bin/bash

# Path to the main Dovecot configuration file
CONF_FILE="/etc/dovecot/dovecot.conf"

# A flag to track if we made any changes
CONFIG_CHANGED=0

# --- Check and Replace Logic ---

# 1. mail_location => mail_path
if grep -q "^\s*mail_location\s*=" "$CONF_FILE"; then
  sed -i 's/^\(\s*\)mail_location\s*=\s*\(.*\)/\1mail_path = \2/' "$CONF_FILE"
  echo "Updated mail_location to mail_path in $CONF_FILE"
  CONFIG_CHANGED=1
fi

# 2. disable_plaintext_auth = no => auth_allow_cleartext = yes
if grep -q "^\s*disable_plaintext_auth\s*=\s*no" "$CONF_FILE"; then
  sed -i 's/^\(\s*\)disable_plaintext_auth\s*=\s*no/\1auth_allow_cleartext = yes/' "$CONF_FILE"
  echo "Updated disable_plaintext_auth to auth_allow_cleartext in $CONF_FILE"
  CONFIG_CHANGED=1
fi

# 3. ssl_cert => ssl_server_cert_file (and remove leading '<' from value)
# The -E flag enables extended regex, and <? matches an optional '<' character.
if grep -q "^\s*ssl_cert\s*=" "$CONF_FILE"; then
  sed -i -E 's/^(\s*)ssl_cert\s*=\s*<?(.*)/\1ssl_server_cert_file = \2/' "$CONF_FILE"
  echo "Updated ssl_cert to ssl_server_cert_file and fixed value in $CONF_FILE"
  CONFIG_CHANGED=1
fi

# 4. ssl_key => ssl_server_key_file (and remove leading '<' from value)
if grep -q "^\s*ssl_key\s*=" "$CONF_FILE"; then
  sed -i -E 's/^(\s*)ssl_key\s*=\s*<?(.*)/\1ssl_server_key_file = \2/' "$CONF_FILE"
  echo "Updated ssl_key to ssl_server_key_file and fixed value in $CONF_FILE"
  CONFIG_CHANGED=1
fi


# --- Restart Service if Needed ---

if [ "$CONFIG_CHANGED" -eq 1 ]; then
  echo "Dovecot configuration updated. Restarting service."
  
  # First, test the configuration to prevent a failed restart
  if dovecot -n > /dev/null; then
    echo "Dovecot config test successful."
    # Use systemctl to restart the service
    systemctl restart dovecot.service
    logger "Dovecot config automatically updated and restarted due to Virtualmin changes."
  else
    echo "ERROR: Dovecot config test failed after modification! Not restarting." >&2
    logger "ERROR: Dovecot auto-update script created a bad configuration. SERVICE NOT RESTARTED." >&2
    exit 1
  fi
fi

exit 0
