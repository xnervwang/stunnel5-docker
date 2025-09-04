#!/usr/bin/env sh
set -eu

# —— 基本 ENV（按需覆盖；证书默认 /app/etc/stunnel.pem）——
: "${SERVICE_NAME:=service}"
: "${CLIENT:=no}"                 # yes/no
: "${ACCEPT:=0.0.0.0:443}"
: "${CONNECT:=127.0.0.1:8386}"

: "${CERT:=/app/etc/stunnel.pem}"
: "${KEY:=${CERT}}"
: "${CAFILE:=${CERT}}"

: "${STUNNEL_VERIFY:=2}"                  # 0..4
: "${STUNNEL_FIPS:=no}"                   # yes/no
: "${STUNNEL_DEBUG:=info}"                # emerg..debug
: "${STUNNEL_LOGID:=sequential}"          # none|sequential|unique|thread(,process*)
: "${STUNNEL_OUTPUT:=/dev/stdout}"        # 输出目标：stdout/stderr/文件路径
: "${STUNNEL_OPTIONS:=}"                  # 逗号分隔 e.g. NO_SSLv3,NO_TLSv1
: "${STUNNEL_CIPHERS:=}"
: "${STUNNEL_CURVES:=}"
: "${STUNNEL_EXTRA:=}"
: "${STUNNEL_FOREGROUND:=yes}"
: "${RUN_AS_ROOT:=no}"

CONF="/app/etc/stunnel.conf"

# —— 基础校验 ——
[ -n "${ACCEPT}" ]  || { echo "ERROR: ACCEPT required" >&2; exit 1; }
[ -n "${CONNECT}" ] || { echo "ERROR: CONNECT required" >&2; exit 1; }

# 服务端模式必须有证书与私钥（由外部挂载提供）
if [ "${CLIENT}" = "no" ]; then
  [ -s "${CERT}" ] || { echo "ERROR: missing CERT file: ${CERT}" >&2; exit 1; }
  [ -s "${KEY}" ]  || { echo "ERROR: missing KEY file: ${KEY}"   >&2; exit 1; }
fi

# —— 生成配置（stdout 日志；不写 pid/log 文件）——
{
  echo "foreground = ${STUNNEL_FOREGROUND}"
  echo "debug = ${STUNNEL_DEBUG}"
  echo "output = ${STUNNEL_OUTPUT}"      # 日志输出到 stdout/stderr/文件
  echo "logId = ${STUNNEL_LOGID}"        # 给每个连接编号，方便排障
  [ "${STUNNEL_FIPS}" = "yes" ] && echo "fips = yes"

  [ -n "${CERT}" ]   && echo "cert = ${CERT}"
  [ -n "${KEY}" ]    && echo "key = ${KEY}"
  [ -n "${CAFILE}" ] && echo "CAfile = ${CAFILE}"
  [ -n "${STUNNEL_VERIFY}" ] && echo "verify = ${STUNNEL_VERIFY}"

  [ -n "${STUNNEL_CIPHERS}" ] && echo "ciphers = ${STUNNEL_CIPHERS}"
  [ -n "${STUNNEL_CURVES}" ]  && echo "curves = ${STUNNEL_CURVES}"

  if [ -n "${STUNNEL_OPTIONS}" ]; then
    IFS=','; for opt in ${STUNNEL_OPTIONS}; do echo "options = ${opt}"; done; unset IFS
  fi

  echo
  echo "[${SERVICE_NAME}]"
  echo "client  = ${CLIENT}"
  echo "accept  = ${ACCEPT}"
  echo "connect = ${CONNECT}"

  if [ -n "${STUNNEL_EXTRA}" ]; then
    echo
    printf "%s\n" "${STUNNEL_EXTRA}"
  fi
} > "${CONF}"

echo "=== /app/etc/stunnel.conf ==="
sed 's/^key = .*/key = ****/' "${CONF}" || true
echo "================================="

# —— 运行身份：默认降权到 stunnel 用户；需要 root 时可开关 —— 
if [ "${RUN_AS_ROOT}" = "yes" ]; then
  exec "$@"
else
  exec su-exec stunnel:stunnel "$@"
fi
