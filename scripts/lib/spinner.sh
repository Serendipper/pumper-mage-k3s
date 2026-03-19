# Reusable progress spinner + elapsed time for long-running steps.
# Source this from scripts:  . "$(dirname "$0")/lib/spinner.sh"
#
# Usage: run_with_spinner "Description of the step" -- command [args...]
# Example: run_with_spinner "Apt upgrade" -- sshpass -p "$P" ssh user@host "sudo apt upgrade -y"
# The command runs in the background; spinner and elapsed time (M:SS) are shown until it finishes.
# Output from the command is printed after "done." Exit code is preserved.

run_with_spinner() {
  local msg="$1"
  shift
  [ "$1" = "--" ] && shift
  [ $# -eq 0 ] && echo "run_with_spinner: no command" >&2 && return 1

  local out
  out=$(mktemp)
  trap "rm -f $out" RETURN

  "$@" > "$out" 2>&1 &
  local pid=$!
  local spinner='|/-\'
  local start
  start=$(date +%s)

  while kill -0 "$pid" 2>/dev/null; do
    local elapsed
    elapsed=$(($(date +%s) - start))
    printf "\r  %s ... %s  %d:%02d  " "$msg" "${spinner:$((elapsed % 4)):1}" "$((elapsed / 60))" "$((elapsed % 60))"
    sleep 1
  done
  wait "$pid"
  local exit=$?
  printf "\r  %s ... done.    \n" "$msg"
  cat "$out"
  return $exit
}
