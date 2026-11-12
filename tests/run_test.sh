#!/usr/bin/env bash
# Unit tests for scripts/run.sh: a stub `wmill` on PATH records its argv,
# one argument per line, so each test asserts the exact command line.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/wmill" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$WMILL_ARGV_FILE"
STUB
chmod +x "$work/bin/wmill"
export PATH="$work/bin:$PATH"
export WMILL_ARGV_FILE="$work/argv"
unset GITHUB_ACTIONS

failures=0
run_case() { # name, expected argv (newline-separated), env assignments...
  local name="$1" expected="$2"; shift 2
  rm -f "$WMILL_ARGV_FILE"
  if ! (cd "$work" && env -u WMILL_COMMAND -u WMILL_TOKEN -u WMILL_WORKSPACE -u WMILL_BASE_URL "$@" bash "$root/scripts/run.sh" >/dev/null); then
    echo "FAIL $name: run.sh exited non-zero"; failures=$((failures+1)); return
  fi
  local actual; actual="$(cat "$WMILL_ARGV_FILE" 2>/dev/null || echo '<wmill not called>')"
  if [ "$actual" = "$expected" ]; then echo "ok   $name"; else
    echo "FAIL $name"; echo "  expected: $(printf '%q ' $expected)"; echo "  actual:   $(printf '%q ' $actual)"; failures=$((failures+1)); fi
}

run_case "command with token appends explicit flags" \
"sync
push
--yes
--workspace
my-ws
--token
t0k
--base-url
https://windmill.example.com" \
  WMILL_COMMAND="sync push --yes" WMILL_TOKEN=t0k WMILL_WORKSPACE=my-ws WMILL_BASE_URL=https://windmill.example.com

run_case "no token passes the command only" \
"version" \
  WMILL_COMMAND="version" WMILL_BASE_URL=https://app.windmill.dev

run_case "extra whitespace and newlines are separators" \
"sync
pull
--yes" \
  WMILL_COMMAND=$'  sync\tpull \n --yes  '

# Shell syntax must reach wmill as literal text and never run.
run_case "no shell evaluation" \
'$(touch
PWNED)
;
echo
`id`
*
$HOME' \
  WMILL_COMMAND='$(touch PWNED) ; echo `id` * $HOME'
if [ -e "$work/PWNED" ]; then echo "FAIL command substitution was executed"; failures=$((failures+1)); else echo "ok   no file created by command substitution"; fi

# Empty command: success, wmill not called.
rm -f "$WMILL_ARGV_FILE"
if (cd "$work" && WMILL_COMMAND="   " bash "$root/scripts/run.sh" >/dev/null) && [ ! -e "$WMILL_ARGV_FILE" ]; then
  echo "ok   empty command installs only"; else echo "FAIL empty command"; failures=$((failures+1)); fi

# Token without workspace: error, wmill not called.
rm -f "$WMILL_ARGV_FILE"
if out="$(cd "$work" && WMILL_COMMAND="sync push" WMILL_TOKEN=t0k WMILL_BASE_URL=https://x.example bash "$root/scripts/run.sh" 2>&1)"; then
  echo "FAIL token without workspace should exit non-zero"; failures=$((failures+1))
elif [ -e "$WMILL_ARGV_FILE" ]; then
  echo "FAIL token without workspace called wmill"; failures=$((failures+1))
elif [ "$out" != "::error::The 'workspace' input is required when 'token' is set." ]; then
  echo "FAIL token without workspace: unexpected message: $out"; failures=$((failures+1))
else echo "ok   token without workspace is rejected"; fi

# Exit code of wmill is propagated.
printf '#!/usr/bin/env bash\nexit 7\n' > "$work/bin/wmill"
set +e; (cd "$work" && WMILL_COMMAND="sync push" bash "$root/scripts/run.sh" >/dev/null 2>&1); code=$?; set -e
if [ "$code" = 7 ]; then echo "ok   wmill exit code is propagated"; else echo "FAIL exit code: expected 7, got $code"; failures=$((failures+1)); fi

if [ "$failures" -ne 0 ]; then echo "$failures failure(s)"; exit 1; fi
echo "all tests passed"
