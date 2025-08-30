#!/usr/bin/env sh
set -eu

# —— 基本 ENV（按需覆盖；证书默认 /etc/stunnel/stunnel.pem）——
: "${STUNNEL_SERVICE_NAME:=service}"
: "${STUNNEL_CLIENT:=no}"                 # yes/no
: "${STUNNEL_ACCEPT:=0.0.0.0:443}"
: "${STUNNEL_CONNECT:=127.0.0.1:8371}"

: "${STUNNEL_CERT:=/etc/stunnel/stunnel.pem}"
: "${STUNNEL_KEY:=${STUNNEL_CERT}}"
: "${STUNNEL_CAFILE:=${STUNNEL_CERT}}"

: "${STUNNEL_VERIFY:=2}"                  # 0..4
: "${STUNNEL_FIPS:=no}"                   # yes/no
: "${STUNNEL_DEBUG:=info}"                # emerg..debug
: "${STUNNEL_OPTIONS:=}"                  # 逗号分隔 e.g. NO_SSLv3,NO_TLSv1
: "${STUNNEL_CIPHERS:=}"
: "${STUNNEL_CURVES:=}"
: "${STUNNEL_EXTRA:=}"
: "${STUNNEL_FOREGROUND:=yes}"
: "${STUNNEL_RUN_AS_ROOT:=no}"

CONF="/etc/stunnel/stunnel.conf"

# —— 基础校验 ——
[ -n "${STUNNEL_ACCEPT}" ]  || { echo "ERROR: STUNNEL_ACCEPT required" >&2; exit 1; }
[ -n "${STUNNEL_CONNECT}" ] || { echo "ERROR: STUNNEL_CONNECT required" >&2; exit 1; }

# 服务端模式必须有证书与私钥（由外部挂载提供）
if [ "${STUNNEL_CLIENT}" = "no" ]; then
  [ -s "${STUNNEL_CERT}" ] || { echo "ERROR: missing STUNNEL_CERT file: ${STUNNEL_CERT}" >&2; exit 1; }
  [ -s "${STUNNEL_KEY}" ]  || { echo "ERROR: missing STUNNEL_KEY file: ${STUNNEL_KEY}"   >&2; exit 1; }
fi

# —— 生成配置（stdout 日志；不写 pid/log 文件）——
{
  echo "foreground = ${STUNNEL_FOREGROUND}"
  echo "debug = ${STUNNEL_DEBUG}"
  [ "${STUNNEL_FIPS}" = "yes" ] && echo "fips = yes"

  [ -n "${STUNNEL_CERT}" ]   && echo "cert = ${STUNNEL_CERT}"
  [ -n "${STUNNEL_KEY}" ]    && echo "key = ${STUNNEL_KEY}"
  [ -n "${STUNNEL_CAFILE}" ] && echo "CAfile = ${STUNNEL_CAFILE}"
  [ -n "${STUNNEL_VERIFY}" ] && echo "verify = ${STUNNEL_VERIFY}"

  [ -n "${STUNNEL_CIPHERS}" ] && echo "ciphers = ${STUNNEL_CIPHERS}"
  [ -n "${STUNNEL_CURVES}" ]  && echo "curves = ${STUNNEL_CURVES}"

  if [ -n "${STUNNEL_OPTIONS}" ]; then
    IFS=','; for opt in ${STUNNEL_OPTIONS}; do echo "options = ${opt}"; done; unset IFS
  fi

  echo
  echo "[${STUNNEL_SERVICE_NAME}]"
  echo "client  = ${STUNNEL_CLIENT}"
  echo "accept  = ${STUNNEL_ACCEPT}"
  echo "connect = ${STUNNEL_CONNECT}"

  if [ -n "${STUNNEL_EXTRA}" ]; then
    echo
    printf "%s\n" "${STUNNEL_EXTRA}"
  fi
} > "${CONF}"

echo "=== /etc/stunnel/stunnel.conf ==="
sed 's/^key = .*/key = ****/' "${CONF}" || true
echo "================================="

# —— 运行身份：默认降权到 stunnel 用户；需要 root 时可开关 —— 
if [ "${STUNNEL_RUN_AS_ROOT}" = "yes" ]; then
  exec "$@"
else
  exec su-exec stunnel:stunnel "$@"
fi
