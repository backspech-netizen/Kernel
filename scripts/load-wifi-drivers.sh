#!/system/bin/sh
# ============================================================
# NetHunter external adapter driver loader v3 (NX709S, stock kernel)
#
# Stock ROM already loads cfg80211 + mac80211 at boot, so this script
# loads ONLY the adapter driver chains built by the GitHub workflow.
#
# চালানোর নিয়ম (root shell):
#   su -c 'sh /data/local/nethunter/load-wifi-drivers.sh'
#
# CRC mismatch হলে (dmesg-তে "disagrees about version of symbol"):
#   su -c 'sh /data/local/nethunter/load-wifi-drivers.sh --swap-mac80211'
#   -> stock mac80211 (user 0, নিরাপদ) নামিয়ে আমাদের fallback/mac80211.ko
#      বসায়, তারপর driver গুলো load করে। Reboot করলে stock অবস্থা ফিরে আসে।
# ============================================================

HERE=$(dirname "$0")
MODDIR=$HERE/modules
FBDIR=$HERE/fallback
FWDIR=/data/local/nethunter/firmware
SWAP=0
[ "$1" = "--swap-mac80211" ] && SWAP=1

echo "== NetHunter adapter driver loader v3 =="

if [ ! -d "$MODDIR" ]; then
  echo "ERROR: modules folder পাওয়া যায়নি: $MODDIR"
  exit 1
fi

if [ -d "$FWDIR" ] && [ -w /sys/module/firmware_class/parameters/path ]; then
  echo "$FWDIR" > /sys/module/firmware_class/parameters/path
  echo "Firmware path set: $FWDIR"
fi

loaded=""; skipped=""; failed=""
try_load() {
  name=$1; file=$2; dir=${3:-$MODDIR}
  if lsmod | grep -q "^${name} "; then
    skipped="$skipped $name(already)"
    return
  fi
  if [ ! -f "$dir/$file" ]; then
    failed="$failed $name(missing-file)"
    return
  fi
  if insmod "$dir/$file" 2>/dev/null; then
    loaded="$loaded $name"
  else
    failed="$failed $name(insmod-failed)"
  fi
}

# --- Compat shim FIRST (v11): re-provides the exports the stock GKI
# kernel trimmed (usb_init_urb, clk_get_sys, led_classdev_suspend, ...)
# plus crc-ccitt, which rt2800lib and mac802154 depend on. ---
try_load nethunter_compat nethunter_compat.ko
try_load crc_ccitt        crc-ccitt.ko

# --- Optional: swap stock mac80211 for ours (CRC fallback) ---
if [ "$SWAP" = "1" ]; then
  echo "-- mac80211 swap mode --"
  if lsmod | grep -q "^mac80211 "; then
    rmmod mac80211 2>/dev/null && echo "stock mac80211 unloaded" \
      || echo "WARNING: mac80211 নামানো যায়নি (busy?) — swap ছাড়াই চলবে"
  fi
  try_load mac80211 mac80211.ko "$FBDIR"
fi

# --- Atheros (AR9271, AR7010/AR9287 carl9170) ---
try_load ath           ath.ko
try_load ath9k_hw      ath9k_hw.ko
try_load ath9k_common  ath9k_common.ko
try_load ath9k_htc     ath9k_htc.ko
try_load carl9170      carl9170.ko

# --- Realtek (RTL8187, RTL8188EU/8192EU via rtl8xxxu) ---
try_load eeprom_93cx6  eeprom_93cx6.ko
try_load rtl8187       rtl8187.ko
try_load rtl8xxxu      rtl8xxxu.ko

# --- Ralink (RT2870/RT3070/RT5370...) ---
try_load rt2x00lib     rt2x00lib.ko
try_load rt2x00usb     rt2x00usb.ko
try_load rt2800lib     rt2800lib.ko
try_load rt2800usb     rt2800usb.ko

# --- MediaTek (MT7601U, MT76x0U, MT76x2U) ---
try_load mt76          mt76.ko
try_load mt76_usb      mt76-usb.ko
try_load mt76x02_lib   mt76x02-lib.ko
try_load mt76x02_usb   mt76x02-usb.ko
try_load mt76x0_common mt76x0-common.ko
try_load mt76x0u       mt76x0u.ko
try_load mt76x2_common mt76x2-common.ko
try_load mt76x2u       mt76x2u.ko
try_load mt7601u       mt7601u.ko

# --- Bluetooth USB adapters ---
try_load btintel       btintel.ko
try_load btbcm         btbcm.ko
try_load btrtl         btrtl.ko
try_load btusb         btusb.ko
try_load hci_vhci      hci_vhci.ko

# --- USB serial (FTDI / CP210x / CH341 / PL2303) ---
try_load usbserial     usbserial.ko
try_load ftdi_sio      ftdi_sio.ko
try_load cp210x        cp210x.ko
try_load ch341         ch341.ko
try_load pl2303        pl2303.ko

# --- USB ethernet ---
try_load usbnet        usbnet.ko
try_load asix          asix.ko
try_load cdc_ether     cdc_ether.ko
try_load rndis_host    rndis_host.ko
try_load r8152         r8152.ko
try_load smsc75xx      smsc75xx.ko
try_load smsc95xx      smsc95xx.ko
try_load dm9601        dm9601.ko

# --- v7 extra WiFi (zd1211, rt73/rt2500, rtl8192cu, ath10k-usb) ---
try_load zd1211rw      zd1211rw.ko
try_load rt73usb       rt73usb.ko
try_load rt2500usb     rt2500usb.ko
try_load rtlwifi       rtlwifi.ko
try_load rtl8192c_common rtl8192c-common.ko
try_load rtl_usb       rtl_usb.ko
try_load rtl8192cu     rtl8192cu.ko
try_load ath10k_core   ath10k_core.ko
try_load ath10k_usb    ath10k_usb.ko

# --- v7 CAN bus / NFC / 802.15.4 / RTL-SDR (best effort) ---
try_load can           can.ko
try_load can_raw       can-raw.ko
try_load can_dev       can-dev.ko
try_load gs_usb        gs_usb.ko
try_load slcan         slcan.ko
try_load nfc           nfc.ko
try_load pn533         pn533.ko
try_load pn533_usb     pn533_usb.ko
try_load ieee802154    ieee802154.ko
try_load mac802154     mac802154.ko
try_load atusb         atusb.ko
try_load dvb_core      dvb-core.ko
try_load dvb_usb_v2    dvb_usb_v2.ko
try_load rtl2830       rtl2830.ko
try_load rtl2832       rtl2832.ko
try_load r820t         r820t.ko
try_load dvb_usb_rtl28xxu dvb_usb_rtl28xxu.ko

echo ""
echo "Loaded :$loaded"
echo "Skipped:$skipped"
echo "Failed :$failed"
echo ""
echo "Adapter লাগিয়ে দেখুন:  lsusb   |   iw dev   |   Kali-তে: iwconfig, airmon-ng"
echo "কিছু fail করলে:  dmesg | tail -30   <- এই log টা পাঠিয়ে দিন"
