# Shared closio-agent settings: the same for everyone (D46).
# This file is committed, so it must never hold secrets.
# Scripts load it with:  . config/project-settings.sh
# Each value can be overridden from outside (used for testing).

# Jira
JIRA_SITE="${JIRA_SITE:-productclosio.atlassian.net}"
JIRA_PROJECT_KEY="${JIRA_PROJECT_KEY:-SCRUM}"

# GitLab (only reachable over the VPN)
GITLAB_HOST="${GITLAB_HOST:-jcvs.japfacomfeed.co.id}"

# VPN (D14, D27)
VPN_GATEWAY="${VPN_GATEWAY:-vpnwm.japfacomfeed.co.id}"
VPN_PORT="${VPN_PORT:-443}"
VPN_REALM="${VPN_REALM:-sso}"
VPN_CERT_SHA256="${VPN_CERT_SHA256:-142458260b4b0b96bad1fd65db4a58b24d02da43be05620efe476bcff71bfa5e}"
VPN_CERT_EXPIRES="${VPN_CERT_EXPIRES:-2027-02-03}"
VPN_INTERFACE="${VPN_INTERFACE:-ppp0}"
VPN_DNS_DOMAIN="${VPN_DNS_DOMAIN:-japfacomfeed.co.id}"
VPN_DNS_SERVERS="${VPN_DNS_SERVERS:-10.90.0.53 10.190.0.55}"
VPN_RESOLVER_FILE="${VPN_RESOLVER_FILE:-/etc/resolver/japfacomfeed.co.id}"
VPN_OLD_RESOLVER_FILE="${VPN_OLD_RESOLVER_FILE:-/etc/resolver/jcvs.japfacomfeed.co.id}"

# macOS Keychain (D33): items are named <prefix>.<name>, account = your Mac username
KEYCHAIN_PREFIX="${KEYCHAIN_PREFIX:-closio-agent}"
KEYCHAIN_PERSONAL_ITEMS="${KEYCHAIN_PERSONAL_ITEMS:-gitlab-token fe-login-id fe-login-password ws1-login-userid ws1-login-password}"

# Node (D41)
NODE_MAJOR="${NODE_MAJOR:-22}"
