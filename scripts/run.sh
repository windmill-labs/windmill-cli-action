#!/usr/bin/env bash
# Runs `wmill <command> [--workspace W --token T --base-url U]`.
# Inputs come from the environment (set by action.yml):
#   WMILL_COMMAND    arguments for wmill, split on whitespace, never evaluated
#   WMILL_TOKEN      optional API token; when set, WMILL_WORKSPACE is required
#   WMILL_WORKSPACE  workspace id
#   WMILL_BASE_URL   instance base URL
set -euo pipefail

command_text="${WMILL_COMMAND:-}"
token="${WMILL_TOKEN:-}"
workspace="${WMILL_WORKSPACE:-}"
base_url="${WMILL_BASE_URL:-}"

if [ -z "${command_text//[[:space:]]/}" ]; then
  echo "No command given: wmill is installed, nothing to run."
  exit 0
fi

# Word-split without a shell: no command substitution, variable expansion or globbing.
args=()
IFS=$' \t\n' read -r -d '' -a args <<< "$command_text" || true

if [ -n "$token" ]; then
  if [ -z "$workspace" ]; then
    echo "::error::The 'workspace' input is required when 'token' is set."
    exit 1
  fi
  if [ -z "$base_url" ]; then
    echo "::error::The 'base-url' input is empty."
    exit 1
  fi
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::add-mask::$token"
  fi
  # Explicit flags, so no stored CLI profile on the runner is used
  # (--base-url requires --token and --workspace).
  args+=(--workspace "$workspace" --token "$token" --base-url "$base_url")
fi

exec wmill "${args[@]}"
