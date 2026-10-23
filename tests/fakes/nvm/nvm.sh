# The fake nvm (D92): what scripts get when they load $NVM_DIR/nvm.sh in a test. Never installs or switches anything.
# FAKE_NVM_MISSING="18.20.8 20.1.0": versions "nvm use" says aren't installed (exit 3) · FAKE_NVM_INSTALL_RC: the exit code
# of "nvm install" · FAKE_NVM_LS: what "nvm ls" prints · FAKE_NVM_CURRENT: "nvm current".
nvm() {
  printf 'nvm %s\n' "$*" >> "${FAKE_LOG:-/dev/null}"
  case "${1:-}" in
    use)
      case " ${FAKE_NVM_MISSING:-} " in *" ${2#v} "*) echo "N/A: version \"v${2#v}\" is not yet installed." >&2; return 3 ;; esac
      echo "Now using node v${2#v}"; return 0 ;;
    install) return "${FAKE_NVM_INSTALL_RC:-0}" ;;
    ls|list) echo "${FAKE_NVM_LS:-v22.14.0}"; return 0 ;;
    current) echo "${FAKE_NVM_CURRENT:-v22.14.0}"; return 0 ;;
    which) echo "$NVM_DIR/versions/node/v${2#v}/bin/node"; return 0 ;;
    version) echo "${FAKE_NVM_CURRENT:-v22.14.0}"; return 0 ;;
    *) return 0 ;;
  esac
}
