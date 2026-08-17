#!/bin/sh
set -eu

OPTIONS_FILE="/data/options.json"
SUPERVISOR_BASE="http://supervisor"

log() {
    printf '%s %s\n' "[YYB-Go Add-on]" "$*"
}

warn() {
    printf '%s %s\n' "[YYB-Go Add-on][WARN]" "$*" >&2
}

fatal() {
    printf '%s %s\n' "[YYB-Go Add-on][ERROR]" "$*" >&2
    exit 1
}

option() {
    key="$1"
    default_value="${2-}"

    if [ -f "${OPTIONS_FILE}" ]; then
        value="$(jq -r --arg key "${key}" '.[$key] // empty' "${OPTIONS_FILE}" 2>/dev/null || true)"
    else
        value=""
    fi

    if [ -n "${value}" ]; then
        printf '%s' "${value}"
    else
        printf '%s' "${default_value}"
    fi
}

supervisor_get() {
    path="$1"

    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        return 1
    fi

    curl -fsS \
        --connect-timeout 3 \
        --max-time 8 \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        "${SUPERVISOR_BASE}${path}"
}

slug_to_hostname() {
    printf '%s' "$1" | tr '_' '-'
}

detect_self_server() {
    self_json="$(supervisor_get /addons/self/info 2>/dev/null || true)"
    [ -n "${self_json}" ] || return 1

    self_slug="$(printf '%s' "${self_json}" | jq -r '.data.slug // empty' 2>/dev/null || true)"
    [ -n "${self_slug}" ] || return 1

    self_host="$(slug_to_hostname "${self_slug}")"
    printf '%s:8000' "${self_host}"
}

detect_qinglong_url() {
    addons_json="$(supervisor_get /addons 2>/dev/null || true)"
    [ -n "${addons_json}" ] || return 1

    ql_slug="$(
        printf '%s' "${addons_json}" \
        | jq -r '
            .data.addons[]?
            | select(
                ((.slug // "") | ascii_downcase | contains("qinglong"))
                or ((.name // "") | ascii_downcase | contains("qinglong"))
                or ((.name // "") | contains("青龙"))
            )
            | .slug
        ' 2>/dev/null \
        | head -n 1
    )"

    [ -n "${ql_slug}" ] || return 1

    ql_host="$(slug_to_hostname "${ql_slug}")"
    printf 'http://%s:5700' "${ql_host}"
}

prepare_persistent_data() {
    for name in db avatars qr; do
        persistent="/data/${name}"
        resource="/app/resource/${name}"

        mkdir -p "${persistent}"
        chown -R yyb:yyb "${persistent}"

        if [ -L "${resource}" ]; then
            rm -f "${resource}"
        elif [ -e "${resource}" ]; then
            # Preserve upstream seed files only when the HAOS data directory is
            # still empty. Existing user data always wins during upgrades.
            if [ -z "$(find "${persistent}" -mindepth 1 -print -quit 2>/dev/null)" ]; then
                cp -R "${resource}/." "${persistent}/" 2>/dev/null || true
                chown -R yyb:yyb "${persistent}"
            fi
            rm -rf "${resource}"
        fi

        ln -s "${persistent}" "${resource}"
    done
}

KEEPALIVE_INTERVAL="$(option keepalive_interval 30m)"
KEEPALIVE_AHEAD="$(option keepalive_ahead 45m)"
QL_URL="$(option ql_url '')"
QL_CLIENT_ID="$(option ql_client_id '')"
QL_CLIENT_SECRET="$(option ql_client_secret '')"
YYB_QINGLONG_SERVER="$(option yyb_qinglong_server '')"
YYB_QINGLONG_REPO="$(option yyb_qinglong_repo 'SuperNaiBA_YYB-GO-Script,525815266_YYB-Go-Enhanced/scripts')"
YYB_ADMIN_USER="$(option yyb_admin_user '')"
YYB_ADMIN_PASSWORD="$(option yyb_admin_password '')"
YYB_COOKIE_SECURE="$(option yyb_cookie_secure false)"

case "${YYB_COOKIE_SECURE}" in
    true|false) ;;
    *) fatal "yyb_cookie_secure 只能是 true 或 false" ;;
esac

if { [ -n "${YYB_ADMIN_USER}" ] && [ -z "${YYB_ADMIN_PASSWORD}" ]; } \
    || { [ -z "${YYB_ADMIN_USER}" ] && [ -n "${YYB_ADMIN_PASSWORD}" ]; }; then
    fatal "yyb_admin_user 和 yyb_admin_password 必须同时填写，或者同时留空"
fi

if [ -z "${QL_URL}" ]; then
    if QL_URL="$(detect_qinglong_url)"; then
        log "已自动发现青龙 Add-on：${QL_URL}"
    else
        QL_URL="http://qinglong:5700"
        warn "未能通过 Supervisor 自动发现青龙；暂用 ${QL_URL}。也可以在 YYB-Go Web 控制台中配置青龙连接。"
    fi
else
    log "使用手工配置的青龙地址：${QL_URL}"
fi

if [ -z "${YYB_QINGLONG_SERVER}" ]; then
    if YYB_QINGLONG_SERVER="$(detect_self_server)"; then
        log "YYB-Go HAOS 内网地址：${YYB_QINGLONG_SERVER}"
    else
        YYB_QINGLONG_SERVER=""
        warn "未能自动取得本 Add-on 的 HAOS DNS 名；若同步到青龙的 YYB_SERVER 地址不正确，请手工填写 yyb_qinglong_server。"
    fi
else
    log "使用手工配置的 YYB_QINGLONG_SERVER：${YYB_QINGLONG_SERVER}"
fi

prepare_persistent_data

# Supervisor manager access is needed only during startup discovery. Never pass
# this high-privilege token to the upstream YYB-Go process.
unset SUPERVISOR_TOKEN

export PANEL_TYPE="qinglong"
export QL_URL
export QL_CLIENT_ID
export QL_CLIENT_SECRET
export YYB_QINGLONG_SERVER
export YYB_QINGLONG_REPO

# Use upstream's native web authentication. SQLite is persisted through
# /app/resource/db -> /data/db, including auth.db.
export YYB_AUTH_DRIVER=sqlite
export YYB_AUTH_DSN=""
export YYB_ADMIN_USER
export YYB_ADMIN_PASSWORD
export YYB_COOKIE_SECURE

log "启动 YYB-Go：0.0.0.0:8000"
if [ -n "${YYB_ADMIN_USER}" ]; then
    log "已配置上游原生管理员初始化账号：${YYB_ADMIN_USER}"
else
    log "未预设管理员；首次在 Web 页面注册的账号将由上游设为管理员"
fi

exec su-exec yyb:yyb /app/yyb-go \
    -host 0.0.0.0 \
    -port 8000 \
    -resource-root /app/resource \
    -keepalive-interval "${KEEPALIVE_INTERVAL}" \
    -keepalive-ahead "${KEEPALIVE_AHEAD}"
