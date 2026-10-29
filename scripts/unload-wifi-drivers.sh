#!/system/bin/sh
# ============================================================
# Unload NetHunter adapter driver modules (reverse order, best effort)
#   su -c 'sh /data/local/nethunter/unload-wifi-drivers.sh'
# Reboot করলেও সব এমনিতেই চলে যায়। mac80211 swap করে থাকলে reboot-এ
# stock mac80211 ফিরে আসবে; এই script আমাদের mac80211 নামাবে না।
# ============================================================

for m in ath9k_htc carl9170 ath9k_common ath9k_hw ath \
         rtl8187 rtl8xxxu eeprom_93cx6 \
         rt2800usb rt2800lib rt2x00usb rt2x00lib \
         mt7601u mt76x2u mt76x2_common mt76x0u mt76x0_common \
         mt76x02_usb mt76x02_lib mt76_usb mt76 \
         btusb btrtl btbcm btintel hci_vhci \
         ftdi_sio cp210x ch341 pl2303 usbserial \
         rndis_host cdc_ether asix usbnet; do
  if lsmod | grep -q "^${m} "; then
    rmmod "$m" 2>/dev/null && echo "unloaded: $m" || echo "busy (skip): $m"
  fi
done
echo "Done."
