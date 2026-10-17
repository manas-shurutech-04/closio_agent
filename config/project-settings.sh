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
VPN_CONNECT_TIMEOUT="${VPN_CONNECT_TIMEOUT:-180}"   # seconds to finish the SSO login

# macOS Keychain (D33): items are named <prefix>.<name>, account = your Mac username
KEYCHAIN_PREFIX="${KEYCHAIN_PREFIX:-closio-agent}"
KEYCHAIN_PERSONAL_ITEMS="${KEYCHAIN_PERSONAL_ITEMS:-gitlab-token fe-login-id fe-login-password ws1-login-userid ws1-login-password}"

# Node (D41)
NODE_MAJOR="${NODE_MAJOR:-22}"

# Branch names (D50, rule A12): SCRUM-<number>/<short-description>, the same name in every repo of a card.
# The description: lowercase words joined by "-", only a-z and 0-9, at most BRANCH_DESC_MAX_WORDS words.
BRANCH_DESC_MAX_WORDS="${BRANCH_DESC_MAX_WORDS:-5}"

# Repo setup (F6, D54): flow-setup-repo
SETUP_INSTALL_TIMEOUT="${SETUP_INSTALL_TIMEOUT:-900}"   # seconds for installing a repo's packages
SETUP_TEST_TIMEOUT="${SETUP_TEST_TIMEOUT:-900}"         # seconds for running a repo's tests once (15 minutes)
DOCKER_START_TIMEOUT="${DOCKER_START_TIMEOUT:-90}"      # seconds to wait for Docker Desktop to start
SERVICE_START_TIMEOUT="${SERVICE_START_TIMEOUT:-30}"    # seconds to wait for a local Redis / RabbitMQ to answer
# Local Redis and RabbitMQ ports (must match config/local-services.yml)
LOCAL_REDIS_PORT="${LOCAL_REDIS_PORT:-6379}"
LOCAL_RABBITMQ_PORT="${LOCAL_RABBITMQ_PORT:-5672}"

# Running a repo's own commands (C3, D65): scripts/repo-run.sh (checks, tests + coverage gate, migrate, seed)
REPO_RUN_TIMEOUT="${REPO_RUN_TIMEOUT:-900}"   # seconds for one command (15 minutes)

# Verifying a card (C4, D67): scripts/repo-run.sh start, scripts/api-call.sh, scripts/api-check.sh, scripts/db-run.sh, scripts/e2e.sh
SERVER_START_TIMEOUT="${SERVER_START_TIMEOUT:-120}"   # seconds for a repo's server to answer on its health URL
API_CALL_TIMEOUT="${API_CALL_TIMEOUT:-30}"             # seconds for one API call
WS1_REPO="${WS1_REPO:-nodejs-ws1closio}"               # the BFF: calls to it are made logged in as the user
WS1_APP_VERSION="${WS1_APP_VERSION:-1.0.0+1}"          # X-Application-Version for WS1 calls (architecture.md, Phase 6)
WS1_NAPP_PK="${WS1_NAPP_PK:-4}"                        # the WS1 login's napp_pk and client_type: the same for everyone
WS1_CLIENT_TYPE="${WS1_CLIENT_TYPE:-web}"
WEB_REPO="${WEB_REPO:-closio-web-v2}"                  # the web app the Playwright tests open
E2E_TIMEOUT="${E2E_TIMEOUT:-900}"                      # seconds for one Playwright run, and for its setup

# Card run folders (C1, D61): committed and pushed on a branch of closio-agent per card, never main
RUN_BRANCH_PREFIX="${RUN_BRANCH_PREFIX:-runs/}"   # the card's branch is runs/<CARD-KEY>
GIT_REMOTE="${GIT_REMOTE:-origin}"

# The ruleset for every card (D64, rule A19): kept by the closio-agent builders, never by a command.
# Backend repos follow all of it; the web app follows its common practices until a frontend ruleset exists.
RULESET_FILE="${RULESET_FILE:-rulesets/story-implementation-workflow.md}"   # relative to the closio-agent folder
