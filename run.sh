#!/bin/bash

# Debug mode
if [ ! -z "$DEBUG" ]; then set -x; fi

# Banner
echo "####"
echo "#### Telegram MTProxy"
echo "####"
echo

# Number of workers
if [ -z "$WORKERS" ]; then
  WORKERS=1
fi

# Generate secret
SECRET_FILE=/data/secret

function random_secret { dd if=/dev/urandom bs=16 count=1 2>&1 | od -tx1  | head -n1 | tail -c +9 | tr -d ' '; }

if [ ! -z "$SECRET" ]; then
  echo "[+] Using the explicitly passed secret: '$SECRET'."
elif [ -f $SECRET_FILE ]; then
  SECRET="$(cat $SECRET_FILE)"
  echo "[+] Using the secret in $SECRET_FILE: '$SECRET'."
else
  if [[ ! -z "$SECRET_COUNT" ]]; then
    if [[ ! ( "$SECRET_COUNT" -ge 1 &&  "$SECRET_COUNT" -le 16 ) ]]; then
      echo "[F] Can generate between 1 and 16 secrets."
      exit 5
    fi
  else
    SECRET_COUNT="1"
  fi
  echo "[+] No secret passed. Will generate $SECRET_COUNT random ones."
  SECRET="$(random_secret)"
  for pass in $(seq 2 $SECRET_COUNT); do
    SECRET="$SECRET,$(random_secret)"
  done
fi

SECRET_CMD=""
if echo "$SECRET" | grep -qE '^[0-9a-fA-F]{32}(,[0-9a-fA-F]{32}){,15}$'; then
  SECRET="$(echo "$SECRET" | tr '[:upper:]' '[:lower:]')"
  SECRET_CMD="-S $(echo "$SECRET" | sed 's/,/ -S /g')"
  echo "$SECRET" > $SECRET_FILE
else
  echo '[F] Bad secret format: should be 32 hex chars (for 16 bytes) for every secret; secrets should be comma-separated.'
  exit 1
fi

# Tag
TAG_CMD=""

if [ ! -z "$TAG" ]; then
  echo "[+] Using the explicitly passed tag: '$TAG'."
  if echo "$TAG" | grep -qE '^[0-9a-fA-F]{32}$'; then
    TAG="$(echo "$TAG" | tr '[:upper:]' '[:lower:]')"
    TAG_CMD="-P $TAG"
  else
    echo '[!] Bad tag format: should be 32 hex chars (for 16 bytes).'
    echo '[!] Continuing.'
  fi
fi

# Obtain a secret, used to connect to telegram servers
PROXY_SECRET_FILE=/data/proxy.secret
curl -s https://core.telegram.org/getProxySecret -o $PROXY_SECRET_FILE || {
  echo '[F] Cannot download proxy secret from Telegram servers.'
  exit 2
}

# Obtain current telegram configuration
# It can change (occasionally), so we encourage you to update it once per day
PROXY_CONFIG_FILE=/data/proxy.conf
curl -s https://core.telegram.org/getProxyConfig -o $PROXY_CONFIG_FILE || {
  echo '[F] Cannot download proxy configuration from Telegram servers.'
  exit 2
}

# Optain server private and public ip
if [[ -z "$IP" ]]; then
  IP="$(curl -s -4 "https://digitalresistance.dog/myIp")"
fi
if [[ -z "$IP" ]]; then
  echo "[F] Cannot determine external IP address."
  exit 3
fi

if [[ -z "$INTERNAL_IP" ]]; then
  INTERNAL_IP="$(ip -4 route get 8.8.8.8 | grep '^8\.8\.8\.8\s' | grep -Po 'src\s+\d+\.\d+\.\d+\.\d+' | awk '{print $2}')"
fi
if [[ -z "$INTERNAL_IP" ]]; then
  echo "[F] Cannot determine internal IP address."
  exit 4
fi

# PORTS
PORT=${PORT:-"443"}
INTERNAL_PORT=${INTERNAL_PORT:-"2398"}

# Report final configuration
echo
echo "[*] Final configuration:"
I=1
echo "$SECRET" | tr ',' '\n' | while read S; do
  echo "[*]   Secret $I: $S"
  echo "[*]   tg:// link for secret $I auto configuration: tg://proxy?server=${IP}&port=${PORT}&secret=dd${S}"
  echo "[*]   t.me link for secret $I: https://t.me/proxy?server=${IP}&port=${PORT}&secret=dd${S}"
  I=$(($I+1))
done

[ ! -z "$TAG" ] && echo "[*]   Tag: $TAG" || echo "[*]   Tag: no tag"

echo "[*]   External IP: $IP"
echo "[*]   Make sure to fix the links in case you run the proxy on a different port."
echo

echo '[+] Starting proxy...'
sleep 1

# Start mtproto-proxy
exec /bin/mtproto-proxy \
    -u root \
    -p "$INTERNAL_PORT" \
    -H "$PORT" \
    -M "$WORKERS" \
    -C 60000 \
    --aes-pwd "$PROXY_SECRET_FILE" \
    --allow-skip-dh \
    --nat-info "$INTERNAL_IP:$IP" \
    $SECRET_CMD \
    $TAG_CMD \
    $ARGS \
    "$PROXY_CONFIG_FILE"
