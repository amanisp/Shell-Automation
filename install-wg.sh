#!/bin/bash

set -e

echo "🚀 Starting WireGuard installation..."

# =========================
# 1. Install WireGuard
# =========================
apt update -y
apt install wireguard -y

# =========================
# 2. Generate Key
# =========================
echo "🔑 Generating keys..."

mkdir -p /etc/wireguard
cd /etc/wireguard

wg genkey | tee server_private.key | wg pubkey > server_public.key

SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

echo "✅ Public Key:"
echo $SERVER_PUBLIC_KEY

# =========================
# 3. Enable IP Forwarding
# =========================
echo "🌐 Enabling IP Forwarding..."

sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# =========================
# 4. Detect Network Interface
# =========================
INTERFACE=$(ip route | grep default | awk '{print $5}')
echo "📡 Detected interface: $INTERFACE"

# =========================
# 5. Create wg0.conf
# =========================
echo "⚙️ Creating config..."

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.10.0.1/16
ListenPort = 51820
SaveConfig = true

PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -A FORWARD -o wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE

PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
EOF

# =========================
# 6. Start WireGuard
# =========================
echo "🚀 Starting WireGuard..."

wg-quick down wg0 2>/dev/null || true
wg-quick up wg0

systemctl enable wg-quick@wg0

# =========================
# 7. Firewall (Optional UFW)
# =========================
if command -v ufw >/dev/null 2>&1; then
    echo "🔥 Configuring UFW..."
    ufw allow 51820/udp || true
fi

# =========================
# 8. Done
# =========================
echo ""
echo "🎉 WireGuard Installed Successfully!"
echo "===================================="
echo "📡 Interface : wg0"
echo "🌐 IP        : 10.10.0.1/16"
echo "🔌 Port      : 51820"
echo "🔑 PublicKey : $SERVER_PUBLIC_KEY"
echo ""
