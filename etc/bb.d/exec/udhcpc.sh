#!/lib/bb/sh
# -*- mode: sh; -*-

# script for udhcpc
# Copyright (c) 2008 Natanael Copa <natanael.copa@gmail.com>

UDHCPC="/etc/udhcpc"
UDHCPC_CONF="$UDHCPC/udhcpc.conf"

RESOLV_CONF="/etc/resolv.conf"
[ -f $UDHCPC_CONF ] && . $UDHCPC_CONF

export broadcast
export dns
export domain
export interface
export ip
export mask
export metric
export router
export subnet

export PATH=/etc/bb.d/exec:/usr/bin:/bin:/usr/sbin:/sbin

run_scripts() {
  local dir=$1
  if [ -d $dir ]; then
    for i in $dir/*; do
      [ -f $i ] && $i
    done
  fi
}

deconfig() {
  ip -4 addr flush dev $interface
}

is_wifi() {
  test -e /sys/class/net/$interface/phy80211
}

if_index() {
  if [ -e  /sys/class/net/$interface/ifindex ]; then
    cat /sys/class/net/$interface/ifindex
  else
    ip -4 link show dev $interface | head -n1 | cut -d: -f1
  fi
}

calc_metric() {
  local base=
  if is_wifi; then
    base=300
  else
    base=200
  fi
  echo $(( $base + $(if_index) ))
}

routes() {
  [ -z "$router" ] && return
  for i in $NO_GATEWAY; do
    [ "$i" = "$interface" ] && return
  done
  local gw= num=
  while ip -4 route del default via dev $interface 2>/dev/null; do
    :
  done
  num=0
  for gw in $router; do
    ip -4 route add 0.0.0.0/0 via $gw dev $interface \
      metric $(( $num + ${IF_METRIC:-$(calc_metric)} ))
    num=$(( $num + 1 ))
  done
}

resolvconf() {
  local i
  [ -n "$IF_PEER_DNS" ] && [ "$IF_PEER_DNS" != "yes" ] && return
  if [ "$RESOLV_CONF" = "no" ] || [ "$RESOLV_CONF" = "NO" ] \
      || [ -z "$RESOLV_CONF" ]; then
    return
  fi
  for i in $NO_DNS; do
    [ "$i" = "$interface" ] && return
  done
  local resolv_tmp=$(mktemp /tmp/resolv_conf_XXXXXX)
  echo -n > "$resolv_tmp"
  if [ -n "$search" ]; then
    echo "search $search" >> "$resolv_tmp"
  elif [ -n "$domain" ]; then
    echo "search $domain" >> "$resolv_tmp"
  fi
  for i in $dns; do
    echo "nameserver $i" >> "$resolv_tmp"
  done
  cat "$resolv_tmp" > "$RESOLV_CONF"
  rm -f "$resolv_tmp"
}

bound() {
  ip -4 addr add $ip/$mask ${broadcast:+broadcast $broadcast} dev $interface
  ip -4 link set dev $interface up
  routes
  resolvconf
}

renew() {
  if ! ip -4 addr show dev $interface | grep $ip/$mask; then
    ip -4 addr flush dev $interface
    ip -4 addr add $ip/$mask ${broadcast:+broadcast $broadcast} dev $interface
  fi

  local i
  for i in $router; do
    if ! ip -4 route show | grep ^default | grep $i; then
      routes
      break
    fi
  done

  if ! grep "^search $domain"; then
    resolvconf
    return
  fi
  for i in $dns; do
    if ! grep "^nameserver $i"; then
      resolvconf
      return
    fi
  done
}

case "$1" in
  deconfig|renew|bound)
    run_scripts $UDHCPC/pre-$1
    $1
    run_scripts $UDHCPC/post-$1
    ;;
  leasefail)
    echo "udhcpc failed to get a DHCP lease" >&2
    ;;
  nak)
    echo "udhcpc received DHCP NAK" >&2
    ;;
  *)
    echo "Error: this script should be called from udhcpc" >&2
    exit 1
    ;;
esac
exit 0

