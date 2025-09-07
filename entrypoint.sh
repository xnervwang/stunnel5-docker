#!/usr/bin/env sh
set -eu

# ===== 必填 =====
: "${MODE:?ERROR: MODE is required (mtls-server|https-proxy)}"
: "${SERVICE_NAME:?ERROR: SERVICE_NAME is required}"
: "${ACCEPT:?ERROR: ACCEPT is required (e.g., 0.0.0.0:443)}"
: "${CONNECT:?ERROR: CONNECT is required (e.g., 127.0.0.1:8080)}"
: "${CERT:?ERROR: CERT is required (path to server certificate)}"
: "${KEY:?ERROR: KEY is required (path to private key)}"

# 只有 mTLS 模式才要求 CAFILE
if [ "${MODE}" = "mtls-server" ]; then
  : "${CAFILE:?ERROR: CAFILE is required in mtls-server mode (path to CA for client cert validation)}"
fi

# ===== 可选 =====
: "${DEBUG:=info}"
: "${LOGID:=sequential}"
: "${OUTPUT:=/dev/stdout}"
: "${FOREGROUND:=yes}"
: "${RUN_AS_ROOT:=no}"

: "${OPTIONS:=}"   # e.g. NO_SSLv3,NO_TLSv1
: "${CIPHERS:=}"
: "${CURVES:=}"
: "${EXTRA:=}"

CONF="/app/etc/stunnel.conf"

# ===== 检查文件 =====
[ -s "${CERT}" ] || { echo "ERROR: missing CERT: ${CERT}" >&2; exit 1; }
[ -s "${KEY}"  ] || { echo "ERROR: missing KEY: ${KEY}"   >&2; exit 1; }
if [ "${MODE}" = "mtls-server" ]; then
  [ -s "${CAFILE}" ] || { echo "ERROR: missing CAFILE: ${CAFILE}" >&2; exit 1; }
fi

# ===== 模板选择 =====
case "${MODE}" in
  mtls-server) TEMPLATE="/app/etc/stunnel5-mtls-server.conf.template" ;;
  https-proxy) TEMPLATE="/app/etc/stunnel5-https-proxy.conf.template" ;;
  *) echo "ERROR: unknown MODE='${MODE}'" >&2; exit 1 ;;
esac

# ===== 渲染 =====
TMP="$(mktemp)"
sed \
  -e "s|{{FOREGROUND}}|${FOREGROUND}|g" \
  -e "s|{{DEBUG}}|${DEBUG}|g" \
  -e "s|{{OUTPUT}}|${OUTPUT}|g" \
  -e "s|{{LOGID}}|${LOGID}|g" \
  -e "s|{{SERVICE_NAME}}|${SERVICE_NAME}|g" \
  -e "s|{{ACCEPT}}|${ACCEPT}|g" \
  -e "s|{{CONNECT}}|${CONNECT}|g" \
  -e "s|{{CERT}}|${CERT}|g" \
  -e "s|{{KEY}}|${KEY}|g" \
  -e "s|{{CAFILE}}|${CAFILE:-}|g" \
  "${TEMPLATE}" > "${TMP}"

# 追加可选调优项
{
  [ -n "${OPTIONS}" ] && { IFS=','; for o in ${OPTIONS}; do echo "options = ${o}"; done; unset IFS; }
  [ -n "${CIPHERS}" ] && echo "ciphers = ${CIPHERS}"
  [ -n "${CURVES}"  ] && echo "curves = ${CURVES}"
  [ -n "${EXTRA}"   ] && printf "%s\n" "${EXTRA}"
} >> "${TMP}"

mv "${TMP}" "${CONF}"

echo "=== /app/etc/stunnel.conf (MODE=${MODE}) ==="
sed 's/^\(\s*key\s*=\s*\).*/\1****/' "${CONF}" || true
echo "==========================================="

if [ "${RUN_AS_ROOT}" = "yes" ]; then
  exec "$@"
else
  exec su-exec stunnel:stunnel "$@"
fi
