# NX709S NetHunter Kernel Modules Build

GitHub Actions build for the **REDMAGIC 7S Pro (NX709S, SM8475)** — it builds
the **external USB adapter drivers** the stock kernel is missing, as loadable
modules for the **stock kernel**. Nothing is flashed, ever.

## Verified device facts (2026-10-29, from the phone itself)

| Fact | Value |
|---|---|
| Stock kernel | `5.10.168-android12-9-00001-g61344663df42` — pristine Google GKI, clang 12.0.5 (r416183b) |
| Vendor drivers | all 282 as modules in `vendor_dlkm`, vermagic `5.10.168-gki-g886caca996e6` |
| **cfg80211 + mac80211** | **already loaded by the stock ROM at boot** (shipped via the vendor boot path; no `.ko` file exists in any mounted partition) |
| Bootloader | already unlocked; module signature OFF |
| Already in stock kernel | USB HID gadget, TUN, full netfilter, ax88179 USB ethernet (vendor module) |
| **Missing** | every external adapter driver chain (ath9k_htc, rt2800usb, mt7601u, rtl8187, ...) |

Because the WiFi stack core is already running, this repo builds **only the
adapter drivers** — that is the whole job. A replacement kernel is not needed
for external WiFi and is no longer part of this package (v1's kernel pass was
dropped in v2: flashing risk with zero added benefit for this goal).

Internal WiFi (`qca_cld3`, Qualcomm proprietary) cannot gain monitor mode or
injection from any kernel/module work — hardware-driver limit.

## Run it

GitHub repo → **Actions** → "NX709S NetHunter GKI Modules" → **Run workflow**
(branch + inputs can stay default) → download the `nx709s-nethunter-modules`
artifact when finished.

The source is pinned via kernel manifest branch `common-android12-5.10-2023-04`
(fallbacks: 2023-03, 2023-05, base) and the workflow **fails** if the checked
out kernel version is not exactly `5.10.168` — the pin is what keeps symbol
CRCs (KMI `android12-9`) compatible with the stock kernel.

Config safety notes: `USER_NS`/`PID_NS`/`SYSVIPC` and `MODULE_FORCE_LOAD` from
generic NetHunter fragments are **deliberately excluded** — the first group
changes core struct layouts and would break KMI CRCs for the 282 vendor
modules on any custom kernel; force-load bypasses the CRC safety check
entirely. Neither is needed: these modules are built to match.

## Use the modules (no flashing)

1. Unzip the artifact on the phone into `/data/local/nethunter/`
   (`modules/*.ko`, `fallback/`, the two scripts).
2. Firmware: inside the Kali chroot —
   `apt install firmware-atheros firmware-misc-nonfree firmware-mediatek firmware-realtek`
   then copy the firmware your adapter needs (`htc_9271.fw`, `carl9170-1.fw`,
   `rt2870.bin`, `mt7601u.bin`, `rtlwifi/*`) into `/data/local/nethunter/firmware/`.
3. Load: `su -c 'sh /data/local/nethunter/load-wifi-drivers.sh'`
4. Plug in the adapter (OTG) → `lsusb`, `iw dev`; inside Kali: `iwconfig`,
   `airmon-ng`.
5. Unload with `unload-wifi-drivers.sh`, or just reboot.

### If a driver fails with "disagrees about version of symbol" (dmesg)

That means the stock mac80211's CRCs differ from this build's. The stock
mac80211 has **zero users** (internal WiFi uses cfg80211 directly), so it can
be swapped safely:

```sh
su -c 'sh /data/local/nethunter/load-wifi-drivers.sh --swap-mac80211'
```

This unloads the stock mac80211, loads `fallback/mac80211.ko` from this
build, then loads the drivers. Stock WiFi is untouched; a reboot restores
everything. Send the `dmesg | tail -30` output if it still fails.

## Backup (good habit, independent of this package)

Modules never touch partitions, but keep a stock boot backup anyway:

```sh
su -c 'dd if=/dev/block/by-name/boot_a of=/sdcard/stock_boot_a.img'
```

## Files

- `.github/workflows/build.yml` — the whole build (pinned source, config, packaging)
- `scripts/load-wifi-drivers.sh` — dependency-ordered loader (+ `--swap-mac80211`)
- `scripts/unload-wifi-drivers.sh`
- `docs/running_defconfig.txt` — the phone's actual running kernel config
  (captured from `/proc/config.gz`)
