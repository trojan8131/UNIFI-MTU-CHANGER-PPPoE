#!/bin/bash
sleep 60
# Path to the configuration file
FILE="/etc/ppp/peers/ppp0"

# Extract the interface from the file (e.g. eth1.35)
INTERFACE=$(grep '^plugin rp-pppoe.so' "$FILE" | awk '{print $3}')

# Check if argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <number>"
  echo "Please provide an MTU value as a number, for example: 1500"
  exit 1
fi

# Check if the argument is a number
if ! [[ "$1" =~ ^[0-9]+$ ]]; then
  echo "Error: argument must be an integer."
  exit 1
fi

MTU=$1
TCP_MSS=$((MTU - 40))
WAN_MTU=$((MTU + 8))

# Display the results in a table format
printf "\n%-15s | %-10s\n" "PARAMETER" "VALUE"
printf "-----------------+------------\n"
printf "%-15s | %-10s\n" "Interface" "$INTERFACE"
printf "%-15s | %-10s\n" "MTU" "$MTU"
printf "%-15s | %-10s\n" "TCP_MSS" "$TCP_MSS"
printf "%-15s | %-10s\n" "WAN_MTU" "$WAN_MTU"

# Modify the configuration file - update MTU
sed -i "s/ 1492/ $MTU/g" "$FILE"

# Update iptables rules
iptables -t mangle -D UBIOS_FORWARD_TCPMSS 1 2>/dev/null
iptables -t mangle -D UBIOS_FORWARD_TCPMSS 1 2>/dev/null
iptables -t mangle -A UBIOS_FORWARD_TCPMSS -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $TCP_MSS

# Set MTU on the physical interface
ifconfig $INTERFACE mtu $WAN_MTU
ifconfig $INTERFACE down
ifconfig $INTERFACE up

# Restart pppd
killall pppd
sleep 1 
# Start PPPoE only if ppp0 does NOT exist
if ! ip a | grep -q "ppp0"; then
  echo "🔁 ppp0 interface inactive — starting pppd..."
  pppd file /etc/ppp/peers/ppp0
else
  echo "✅ ppp0 interface is already active — no need to start pppd again."
fi

echo -e "\n✅ Configuration complete."
