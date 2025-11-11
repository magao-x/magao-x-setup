#!/usr/bin/env bash
set -euo pipefail

# Make installer boot lines consistent:
#   - Replace any inst.stage2=... with inst.stage2=hd:LABEL=<VOL>
#   - Ensure inst.cmdline present (once)
#   - Preserve original volume label exactly
#
# Works for UEFI-only (aarch64) and BIOS+UEFI (x86_64).

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing tool: $1"; }

[[ $# -eq 1 ]] || die "Usage: $0 /path/to/Rocky-*.iso"
ISO="$1"
[[ -r "$ISO" ]] || die "ISO not readable: $ISO"

need xorriso
need sed
need awk
need grep

# Optional (BIOS hybrid MBR blob). Not needed for aarch64.
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

# Original volume label (preserve EXACTLY)
VOL_ID="$(xorriso -indev "$ISO" -pvd_info 2>/dev/null | awk -F': ' '/Volume id/ {print $2; exit}')"
[[ -z "$VOL_ID" ]] && VOL_ID="ROCKY_CMDLINE"
echo "Original volume label: '$VOL_ID'"

# Patching helpers
patch_grubfile() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  echo "Patching GRUB: $f"
  # Replace any existing inst.stage2=... token; if none, append ours.
  # Then ensure inst.cmdline is present exactly once.
  sed -Ei -e "/^( *linux(efi)? +)/{
      s|(.*)inst\.stage2=[^[:space:]]*|\1|g
      s|^( *linux(efi)? +.*)|\1 inst.stage2=hd:LABEL=${VOL_ID}|
    }" \
    -e "/^( *linux(efi)? +)/{
      /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|$| inst.cmdline|
    }" "$f"
}

patch_isolinux() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  echo "Patching ISOLINUX: $f"
  sed -Ei '/^[[:space:]]*append /{
      s|(.*)inst\.stage2=[^[:space:]]*|\1|g
      s|^( *append .*initrd=[^[:space:]]+.*)|\1 inst.stage2=hd:LABEL='"$VOL_ID"'|
      /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|$| inst.cmdline|
  }' "$f"
}

# Apply patches
patch_isolinux "$EXTRACT/isolinux/isolinux.cfg"
patch_isolinux "$EXTRACT/isolinux/grub.conf"     # uncommon but harmless
patch_grubfile "$EXTRACT/EFI/BOOT/grub.cfg"
patch_grubfile "$EXTRACT/EFI/rocky/grub.cfg"
patch_grubfile "$EXTRACT/boot/grub2/grub.cfg"

# Show the resulting linux lines for CI logs (sanity check)
echo "---- Patched linux lines (for verification) ----"
grep -Eho '^( *linux(efi)? +).*' \
  "$EXTRACT/EFI/BOOT/grub.cfg" \
  "$EXTRACT/EFI/rocky/grub.cfg" \
  "$EXTRACT/boot/grub2/grub.cfg" 2>/dev/null || true
echo "------------------------------------------------"

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

# Final verification: confirm the OUT_ISO label and show linux lines again
NEW_VOL="$(xorriso -indev "$OUT_ISO" -pvd_info 2>/dev/null | awk -F': ' '/Volume id/ {print $2; exit}')"
echo "New ISO volume label: '$NEW_VOL'"
if [[ "$NEW_VOL" != "$VOL_ID" ]]; then
  echo "WARNING: New volume label differs from original!"
fi

echo "Done. Rebuilt ISO at: $OUT_ISO"
