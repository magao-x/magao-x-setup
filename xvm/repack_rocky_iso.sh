#!/usr/bin/env bash
set -euo pipefail

# Repack a Rocky/RHEL installer ISO so every linux/linuxefi line:
#   - has:  inst.stage2=hd:LABEL=<VOL>
#   - has:  inst.cmdline
#
# Works with UEFI-only (aarch64) and BIOS+UEFI (x86_64) layouts.

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing tool: $1"; }

[[ $# -eq 1 ]] || die "Usage: $0 /path/to/Rocky-*.iso"
ISO="$1"
[[ -r "$ISO" ]] || die "ISO not found/readable: $ISO"

need xorriso
need sed
need awk

# Optional (hybrid MBR for BIOS images)
ISOHYBRID_MBR=""
for p in \
  /usr/share/syslinux/isohdpfx.bin \
  /usr/lib/ISOLINUX/isohdpfx.bin \
  /usr/lib/syslinux/bios/isohdpfx.bin \
  /usr/lib/syslinux/isohdpfx.bin
do [[ -r "$p" ]] && { ISOHYBRID_MBR="$p"; break; }; done

ISO_DIR="$(cd "$(dirname "$ISO")" && pwd)"
ISO_BASE="$(basename "$ISO")"
OUT_ISO="${ISO_DIR}/${ISO_BASE%.iso}-cmdline.iso"

WORKDIR="$(mktemp -d -t rockyiso.XXXXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT
EXTRACT="$WORKDIR/extract"; mkdir -p "$EXTRACT"

echo "Extracting ISO..."
xorriso -osirrox on -indev "$ISO" -extract / "$EXTRACT" >/dev/null

VOL_ID="$(xorriso -indev "$ISO" -pvd_info 2>/dev/null | awk -F': ' '/Volume id/ {print $2; exit}')"
[[ -z "$VOL_ID" ]] && VOL_ID="ROCKY_CMDLINE"

# A helper that patches a GRUB file: ensure inst.stage2=hd:LABEL=<VOL> and inst.cmdline
patch_grubfile() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  echo "Patching GRUB: $f"

  # Do the patch in-place but only on linux/linuxefi lines.
  # 1) If the line lacks inst.stage2=, append inst.stage2=hd:LABEL=<VOL>
  # 2) If the line lacks inst.cmdline, append inst.cmdline
  # Note: keep everything on the same physical line to avoid GRUB continuation quirks.
  sed -Ei -e "/^( *linux(efi)? +)/{
    /inst\.stage2=/! s|$| inst.stage2=hd:LABEL=${VOL_ID}|
  }" -e "/^( *linux(efi)? +)/{
    /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|$| inst.cmdline|
  }" "$f"
}

# ISOLINUX (BIOS) file needs only inst.cmdline — stage2 is on 'append' there.
patch_isolinux() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  echo "Patching ISOLINUX: $f"
  sed -Ei '/^[[:space:]]*append /{
    /inst\.stage2=/! s|$| inst.stage2=hd:LABEL='"$VOL_ID"'|
    /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|$| inst.cmdline|
  }' "$f"
}

# Apply patches
patch_isolinux "$EXTRACT/isolinux/isolinux.cfg"
patch_isolinux "$EXTRACT/isolinux/grub.conf"     # some spins include this
patch_grubfile "$EXTRACT/EFI/BOOT/grub.cfg"
patch_grubfile "$EXTRACT/EFI/rocky/grub.cfg"
patch_grubfile "$EXTRACT/boot/grub2/grub.cfg"

# Sanity check: we expect at least one linux/linuxefi line with both tokens
found_lines=$(grep -Eho '^( *linux(efi)? +).*' \
  "$EXTRACT/EFI/BOOT/grub.cfg" \
  "$EXTRACT/EFI/rocky/grub.cfg" \
  "$EXTRACT/boot/grub2/grub.cfg" 2>/dev/null || true)

if [[ -n "$found_lines" ]]; then
  echo "$found_lines" | grep -q 'inst\.stage2=.*hd:LABEL='"$VOL_ID" || die "Patch sanity check failed: inst.stage2=hd:LABEL=${VOL_ID} not present on linux lines"
  echo "$found_lines" | grep -q '(^|[[:space:]])inst\.cmdline([[:space:]]|$)' -E || die "Patch sanity check failed: inst.cmdline not present on linux lines"
fi

# Detect boot assets
BIOS_BIN="isolinux/isolinux.bin"
BIOS_CAT="isolinux/boot.cat"
UEFI_IMG="images/efiboot.img"

have_bios=false; [[ -f "$EXTRACT/$BIOS_BIN" ]] && have_bios=true
have_uefi=false; [[ -f "$EXTRACT/$UEFI_IMG" ]] && have_uefi=true

echo "Rebuilding ISO -> $OUT_ISO"
if $have_bios && $have_uefi; then
  xorriso -as mkisofs \
    -V "$VOL_ID" \
    ${ISOHYBRID_MBR:+-isohybrid-mbr "$ISOHYBRID_MBR"} \
    -o "$OUT_ISO" \
    -J -R -l -iso-level 3 \
    -b "$BIOS_BIN" -c "$BIOS_CAT" \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
      -e "$UEFI_IMG" -no-emul-boot \
    -isohybrid-gpt-basdat \
    "$EXTRACT"
elif $have_uefi; then
  xorriso -as mkisofs \
    -V "$VOL_ID" \
    -o "$OUT_ISO" \
    -J -R -l -iso-level 3 \
    -eltorito-alt-boot \
      -e "$UEFI_IMG" -no-emul-boot \
    -isohybrid-gpt-basdat \
    "$EXTRACT"
elif $have_bios; then
  xorriso -as mkisofs \
    -V "$VOL_ID" \
    ${ISOHYBRID_MBR:+-isohybrid-mbr "$ISOHYBRID_MBR"} \
    -o "$OUT_ISO" \
    -J -R -l -iso-level 3 \
    -b "$BIOS_BIN" -c "$BIOS_CAT" \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
    "$EXTRACT"
else
  die "No recognizable boot assets found (no $UEFI_IMG and no $BIOS_BIN)."
fi

echo "Done. Rebuilt ISO at: $OUT_ISO"
