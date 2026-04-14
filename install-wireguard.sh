#!/bin/bash

# ==============================
# CONFIG
# ==============================
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"
SERVER_IP="103.203.233.235"
WG_PORT="51820"
WG_NET="10.10.0.0/24"

echo "=== Install WireGuard ==="
apt update -y
apt install wireguard qrencode -y

mkdir -p $WG_DIR
chmod 700 $WG_DIR

# ==============================
# GENERATE SERVER KEY
# ==============================
SERVER_PRIVATE=$(wg genkey)
SERVER_PUBLIC=$(echo $SERVER_PRIVATE | wg pubkey)

echo $SERVER_PRIVATE > $WG_DIR/server_private.key
echo $SERVER_PUBLIC > $WG_DIR/server_public.key

# ==============================
# CREATE CONFIG
# ==============================
cat > $WG_CONF <<EOF
[Interface]
Address = 10.10.0.1/24
PrivateKey = $SERVER_PRIVATE
ListenPort = $WG_PORT

PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

chmod 600 $WG_CONF

# ==============================
# ENABLE IP FORWARD
# ==============================
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# ==============================
# START SERVICE
# ==============================
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

echo "=== DONE INSTALL ==="
echo "Public Key:"
echo $SERVER_PUBLIC
