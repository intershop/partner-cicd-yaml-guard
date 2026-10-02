#!/usr/bin/env bash
#
# HAProxy check: validates ACL allowlist files, haproxy-aux.cfg
# userlist files, and full HAProxy config syntax.
#
# Depends on: get_changed_files() from common.sh, and the MODE,

find_haproxy_allowlist_targets() {
  if [[ "$MODE" == "changed" ]]; then
    local files
    files="$(get_changed_files)"
    if [[ -n "$files" ]]; then
      printf '%s\n' "$files" \
        | grep -E '(^|/)acls/ip[^/]*\.txt$|^clusters/global-acls/ip[^/]*\.txt$|^clusters/global-acls/global-block-list\.txt$' \
        || true
    else
      find_haproxy_allowlist_targets_all
    fi
  else
    find_haproxy_allowlist_targets_all
  fi
}

find_haproxy_allowlist_targets_all() {
  find . \
    \( -path './.git' -o -path './.local' -o -path './.vscode' \) -prune -o \
    -type f \( \
      -path '*/acls/ip*.txt' -o \
      -path './clusters/global-acls/ip*.txt' -o \
      -path './clusters/global-acls/global-block-list.txt' \
    \) -print \
    | sed 's#^\./##' | sort -u
}

find_haproxy_aux_targets() {
  if [[ "$MODE" == "changed" ]]; then
    local files
    files="$(get_changed_files)"
    if [[ -n "$files" ]]; then
      printf '%s\n' "$files" | grep -E '(^|/)haproxy-aux\.cfg$' || true
    else
      find_haproxy_aux_targets_all
    fi
  else
    find_haproxy_aux_targets_all
  fi
}

find_haproxy_aux_targets_all() {
  find . \
    \( -path './.git' -o -path './.local' -o -path './.vscode' \) -prune -o \
    -type f -name 'haproxy-aux.cfg' -print \
    | sed 's#^\./##' | sort -u
}

is_valid_ipv4_cidr() {
  local value="$1"
  local ip prefix octet
  local -a octets

  if [[ "$value" == */* ]]; then
    ip="${value%/*}"
    prefix="${value##*/}"
    [[ "$prefix" =~ ^([0-9]|[1-2][0-9]|3[0-2])$ ]] || return 1
  else
    ip="$value"
  fi

  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    (( 10#$octet <= 255 )) || return 1
  done
  return 0
}

is_valid_haproxy_password_hash() {
  local value="$1"

  [[ "$value" =~ ^\$2[aby]\$(0[4-9]|[12][0-9]|3[01])\$[./A-Za-z0-9]{53}$ ]] && return 0
  [[ "$value" =~ ^\$5\$(rounds=[1-9][0-9]{3,8}\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{43}$ ]] && return 0
  [[ "$value" =~ ^\$6\$(rounds=[1-9][0-9]{3,8}\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}$ ]]
}

validate_haproxy_allowlist_file() {
  local file="$1"
  local line line_no=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="${line%$'\r'}"

    if [[ "$line" =~ ^[[:space:]] || "$line" =~ [[:space:]]$ ]]; then
      echo "HAProxy allowlist validation failed for: $file:$line_no" >&2
      echo "Line must not have leading or trailing whitespace." >&2
      status=1
      continue
    fi

    [[ -z "$line" ]] && continue

    if [[ "$line" == \#* ]]; then
      if [[ ! "$line" =~ ^#($| ) ]]; then
        echo "HAProxy allowlist validation failed for: $file:$line_no" >&2
        echo "Comment text must be preceded by a space after #." >&2
        status=1
      fi
      continue
    fi

    if ! is_valid_ipv4_cidr "$line"; then
      echo "HAProxy allowlist validation failed for: $file:$line_no" >&2
      echo "Line must be an IPv4 address with an optional /0-/32 subnet, or a comment starting with #." >&2
      status=1
    fi
  done < "$file"
}

validate_haproxy_aux_file() {
  local file="$1"
  local line line_no=0
  local state="expect_userlist"
  local block_has_user=0
  local password_hash

  [[ -s "$file" ]] || return 0

  if [[ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]]; then
    echo "HAProxy aux validation failed for: $file" >&2
    echo "File must end with a newline." >&2
    status=1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="${line%$'\r'}"

    [[ -z "$line" ]] && continue

    if [[ "$line" == \#* ]]; then
      if [[ ! "$line" =~ ^#($| ) ]]; then
        echo "HAProxy aux validation failed for: $file:$line_no" >&2
        echo "Comment text must be preceded by a space after #." >&2
        status=1
      fi
      continue
    fi

    case "$state" in
      expect_userlist)
        if [[ "$line" =~ ^userlist[[:space:]][^[:space:]]+$ ]]; then
          state="expect_group"
          block_has_user=0
        else
          echo "HAProxy aux validation failed for: $file:$line_no" >&2
          echo "Expected 'userlist <name>'." >&2
          status=1
        fi
        ;;
      expect_group)
        if [[ "$line" == "  group authenticated-users" ]]; then
          state="expect_user"
        else
          echo "HAProxy aux validation failed for: $file:$line_no" >&2
          echo "Expected '  group authenticated-users'." >&2
          status=1
        fi
        ;;
      expect_user)
        if [[ "$line" =~ ^\ \ user[[:space:]][^[:space:]]+[[:space:]]password[[:space:]]([^[:space:]]+)[[:space:]]groups[[:space:]]authenticated-users$ ]]; then
          password_hash="${BASH_REMATCH[1]}"
          if is_valid_haproxy_password_hash "$password_hash"; then
            block_has_user=1
          else
            echo "HAProxy aux validation failed for: $file:$line_no" >&2
            echo "Password must be a valid bcrypt, SHA-256 crypt, or SHA-512 crypt hash." >&2
            status=1
          fi
        elif [[ "$line" =~ ^userlist[[:space:]][^[:space:]]+$ ]]; then
          if [[ "$block_has_user" -eq 0 ]]; then
            echo "HAProxy aux validation failed for: $file:$line_no" >&2
            echo "Previous userlist block must contain at least one user." >&2
            status=1
          fi
          state="expect_group"
          block_has_user=0
        else
          echo "HAProxy aux validation failed for: $file:$line_no" >&2
          echo "Expected '  user <username> password <passwordhash> groups authenticated-users'." >&2
          status=1
        fi
        ;;
    esac
  done < "$file"

  if [[ "$state" == "expect_group" ]]; then
    echo "HAProxy aux validation failed for: $file" >&2
    echo "Last userlist block is missing '  group authenticated-users'." >&2
    status=1
  elif [[ "$state" == "expect_user" && "$block_has_user" -eq 0 ]]; then
    echo "HAProxy aux validation failed for: $file" >&2
    echo "Last userlist block must contain at least one user." >&2
    status=1
  fi
}

run_haproxy_validation() {
  while IFS= read -r acl; do
    [[ -f "$acl" ]] || continue
    validate_haproxy_allowlist_file "$acl"
  done < <(find_haproxy_allowlist_targets)

  while IFS= read -r aux; do
    [[ -f "$aux" ]] || continue
    validate_haproxy_aux_file "$aux"
  done < <(find_haproxy_aux_targets)

  while IFS= read -r cfg; do
    if [[ -s "$cfg" ]] && [[ "$(tail -c 1 "$cfg" | wc -l)" -eq 0 ]]; then
      echo "HAProxy validation failed for: $cfg" >&2
      echo "File must end with a newline to avoid HAProxy reload issues." >&2
      status=1
    fi
  done < <(find . \
    \( -path './.git' -o -path './.local' -o -path './.vscode' \) -prune -o \
    -type f -name '*.cfg' -print \
    | sed 's#^\./##' | sort -u)

  if command -v haproxy >/dev/null 2>&1; then
    local syntax_test_cfg
    syntax_test_cfg="$(mktemp)" || {
      echo "HAProxy validation failed: could not create a temporary syntax-check config." >&2
      status=1
      return
    }

    while IFS= read -r cfg; do
      if [[ "$cfg" == "haproxy-aux.cfg" || "$cfg" == */haproxy-aux.cfg ]]; then
        {
          printf '%s\n' \
            'global' \
            '  maxconn 10' \
            'defaults' \
            '  mode http' \
            '  timeout connect 1s' \
            '  timeout client 1s' \
            '  timeout server 1s'
          cat "$cfg"
          printf '\n%s\n' \
            'frontend validation_frontend' \
            '  bind 127.0.0.1:10080' \
            '  default_backend validation_backend' \
            'backend validation_backend' \
            '  server validation_server 127.0.0.1:10081'
        } > "$syntax_test_cfg"
        if ! haproxy -c -f "$syntax_test_cfg" >/tmp/haproxy-check.out 2>&1; then
          echo "HAProxy validation failed for: $cfg" >&2
          cat /tmp/haproxy-check.out >&2 || true
          status=1
        fi
      elif ! haproxy -c -f "$cfg" >/tmp/haproxy-check.out 2>&1; then
        echo "HAProxy validation failed for: $cfg" >&2
        cat /tmp/haproxy-check.out >&2 || true
        status=1
      fi
    done < <(find . \
      \( -path './.git' -o -path './.local' -o -path './.vscode' \) -prune -o \
      -type f -name '*.cfg' -print \
      | sed 's#^\./##' | sort -u)
    rm -f "$syntax_test_cfg"
  else
    echo "HAProxy validation failed: haproxy is required for syntax validation." >&2
    status=1
  fi
}

status=0
run_haproxy_validation
exit "$status"