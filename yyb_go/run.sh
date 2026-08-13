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
            # Preserve any upstream seed files only on first migration.
            if [ -z "$(find "${persistent}" -mindepth 1 -print -quit 2>/dev/null)" ]; then
                cp -R "${resource}/." "${persistent}/" 2>/dev/null || true
                chown -R yyb:yyb "${persistent}"
            fi
            rm -rf "${resource}"
        fi

        ln -s "${persistent}" "${resource}"
    done
}

WEB_USER="$(option web_user admin)"
WEB_PASSWORD="$(option web_password '')"
KEEPALIVE_INTERVAL="$(option keepalive_interval 30m)"
KEEPALIVE_AHEAD="$(option keepalive_ahead 45m)"
QL_URL="$(option ql_url '')"
QL_CLIENT_ID="$(option ql_client_id '')"
QL_CLIENT_SECRET="$(option ql_client_secret '')"
YYB_QINGLONG_SERVER="$(option yyb_qinglong_server '')"
YYB_QINGLONG_REPO="$(option yyb_qinglong_repo 'SuperNaiBA_YYB-GO-Script,525815266_YYB-Go-Enhanced/scripts')"

[ -n "${WEB_USER}" ] || fatal "web_user 不能为空"
[ -n "${WEB_PASSWORD}" ] || fatal "首次启动前请在 Add-on 配置中设置 web_password"

if [ -z "${QL_URL}" ]; then
    if QL_URL="$(detect_qinglong_url)"; then
        log "已自动发现青龙 Add-on：${QL_URL}"
    else
        QL_URL="http://qinglong:5700"
        warn "未能通过 Supervisor 自动发现青龙；暂用 ${QL_URL}。可在 Web 控制台或 Add-on 的 ql_url 中手工配置。"
    fi
else
    log "使用手工配置的青龙地址：${QL_URL}"
fi

if [ -z "${YYB_QINGLONG_SERVER}" ]; then
    if YYB_QINGLONG_SERVER="$(detect_self_server)"; then
        log "YYB-Go HAOS 内网地址：${YYB_QINGLONG_SERVER}"
    else
        YYB_QINGLONG_SERVER=""
        warn "未能自动取得本 Add-on 的 HAOS DNS 名。YYB-Go 本身仍可启动；若一键同步到青龙时地址不正确，请填写 yyb_qinglong_server。"
    fi
else
    log "使用手工配置的 YYB_QINGLONG_SERVER：${YYB_QINGLONG_SERVER}"
fi

prepare_persistent_data

# Supervisor manager access is needed only for startup discovery. Do not pass
# the high-privilege token to the upstream YYB-Go process or Nginx.
unset SUPERVISOR_TOKEN

mkdir -p /etc/nginx/auth
htpasswd -Bbc /etc/nginx/auth/htpasswd "${WEB_USER}" "${WEB_PASSWORD}" >/dev/null
chown root:nginx /etc/nginx/auth/htpasswd
chmod 0640 /etc/nginx/auth/htpasswd

export QL_URL
export QL_CLIENT_ID
export QL_CLIENT_SECRET
export YYB_QINGLONG_SERVER
export YYB_QINGLONG_REPO

log "启动 YYB-Go 后端：0.0.0.0:8000"
su-exec yyb:yyb /app/yyb-go \
    -host 0.0.0.0 \
    -port 8000 \
    -resource-root /app/resource \
    -keepalive-interval "${KEEPALIVE_INTERVAL}" \
    -keepalive-ahead "${KEEPALIVE_AHEAD}" &
YYB_PID=$!

# Give the backend a short opportunity to fail fast before Nginx starts.
sleep 1
if ! kill -0 "${YYB_PID}" 2>/dev/null; then
    if wait "${YYB_PID}"; then status=0; else status=$?; fi
    fatal "YYB-Go 后端启动失败（退出码 ${status}）"
fi

log "启动 Nginx Web UI：0.0.0.0:8080"
nginx -g 'daemon off;' &
NGINX_PID=$!

cleanup() {
    trap - INT TERM EXIT
    kill "${NGINX_PID}" "${YYB_PID}" 2>/dev/null || true
    wait "${NGINX_PID}" 2>/dev/null || true
    wait "${YYB_PID}" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

while :; do
    if ! kill -0 "${YYB_PID}" 2>/dev/null; then
        if wait "${YYB_PID}"; then status=0; else status=$?; fi
        warn "YYB-Go 后端已退出（退出码 ${status}），停止 Add-on"
        exit "${status}"
    fi

    if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
        if wait "${NGINX_PID}"; then status=0; else status=$?; fi
        warn "Nginx 已退出（退出码 ${status}），停止 Add-on"
        exit "${status}"
    fi

    sleep 2
done
