#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing tool: $1"; }

[[ $# -eq 1 ]] || die "Usage: $0 /path/to/Rocky-*.iso"
ISO="$1"
[[ -r "$ISO" ]] || die "ISO not readable: $ISO"

need xorriso
need sed
need awk
need grep

ISO_DIR="$(cd "$(dirname "$ISO")" && pwd)"
ISO_BASE="$(basename "$ISO")"
OUT_ISO="${ISO_DIR}/${ISO_BASE%.iso}-cmdline.iso"

# -------- Volume label (preserve EXACTLY) --------
get_label() {
  local in="$1" lbl=""
  if command -v isoinfo >/dev/null 2>&1; then
    lbl="$(isoinfo -d -i "$in" 2>/dev/null | sed -n 's/^Volume id: //p' | head -n1)"
  fi
  if [[ -z "$lbl" ]]; then
    # xorriso -pvd_info prints:  Volume id    : 'Rocky-...'
    # Extract between single quotes if present; otherwise after colon.
    lbl="$(xorriso -indev "$in" -pvd_info 2>/dev/null \
      | awk '
        /Volume id/{
          if (match($0, /'\''([^'\'']+)'\'')/) { print substr($0, RSTART+1, RLENGTH-2); exit }
          sub(/^.*Volume id[[:space:]]*:[[:space:]]*/, "", $0); print; exit
        }')"
  fi
  echo "$lbl"
}

VOL_ID="$(get_label "$ISO")"
[[ -z "$VOL_ID" ]] && die "Could not read ISO volume label"
echo "Original volume label: '$VOL_ID'"

# -------- Extract --------
WORKDIR="$(mktemp -d -t rockyiso.XXXXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT
EXTRACT="$WORKDIR/extract"; mkdir -p "$EXTRACT"

echo "Extracting ISO..."
xorriso -osirrox on -indev "$ISO" -extract / "$EXTRACT" >/dev/null

# -------- Patchers (append ONLY inst.cmdline) --------
append_cmdline_to_isolinux() {
  local f="$1"; [[ -f "$f" ]] || return 0
  echo "Patching ISOLINUX: $f"
  sed -Ei '/^[[:space:]]*append /{
    /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|$| inst.cmdline|
  }' "$f"
}

append_cmdline_to_grub_vars() {
  local f="$1"; [[ -f "$f" ]] || return 0
  echo "Patching GRUB (kernelopts/kargs): $f"
  # Ensure quoting is preserved; just append inst.cmdline once.
  sed -Ei '/^[[:space:]]*set[[:space:]]+(kernelopts|kargs)=/{
    /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|(^( *set +(kernelopts|kargs)=)(["'\'']?)(.*)(\4)$)|\1\4\5 inst.cmdline\4|
  }' "$f"
}

append_cmdline_to_grub_linux() {
  local f="$1"; [[ -f "$f" ]] || return 0
  echo "Patching GRUB (linux lines): $f"
  sed -Ei '/^( *linux(efi)? +)/{
    /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|$| inst.cmdline|
  }' "$f"
}

# Apply to common locations
append_cmdline_to_isolinux "$EXTRACT/isolinux/isolinux.cfg"
append_cmdline_to_isolinux "$EXTRACT/isolinux/grub.conf"

for gf in \
  "$EXTRACT/EFI/BOOT/grub.cfg" \
  "$EXTRACT/EFI/rocky/grub.cfg" \
  "$EXTRACT/boot/grub2/grub.cfg"
do
  append_cmdline_to_grub_vars "$gf"
  append_cmdline_to_grub_linux "$gf"
done

# Show results for CI logs
echo "---- GRUB kernelopts/kargs after patch ----"
grep -Eh '^[[:space:]]*set +(kernelopts|kargs)=' \
  "$EXTRACT/EFI/BOOT/grub.cfg" \
  "$EXTRACT/EFI/rocky/grub.cfg" \
  "$EXTRACT/boot/grub2/grub.cfg" 2>/dev/null || true
echo "---- Direct linux lines (if any) ----"
grep -Eho '^( *linux(efi)? +).*' \
  "$EXTRACT/EFI/BOOT/grub.cfg" \
  "$EXTRACT/EFI/rocky/grub.cfg" \
  "$EXTRACT/boot/grub2/grub.cfg" 2>/dev/null || true
echo "-------------------------------------------"

# -------- Rebuild (preserve label) --------
BIOS_BIN="isolinux/isolinux.bin"
BIOS_CAT="isolinux/boot.cat"
UEFI_IMG="images/efiboot.img"
have_bios=false; [[ -f "$EXTRACT/$BIOS_BIN" ]] && have_bios=true
have_uefi=false; [[ -f "$EXTRACT/$UEFI_IMG" ]] && have_uefi=true

echo "Rebuilding ISO -> $OUT_ISO"
if $have_bios && $have_uefi; then
  # Optional isohybrid MBR (only matters for BIOS/x86_64)
  ISOHYBRID_MBR=""
  for p in /usr/share/syslinux/isohdpfx.bin /usr/lib/ISOLINUX/isohdpfx.bin /usr/lib/syslinux/bios/isohdpfx.bin /usr/lib/syslinux/isohdpfx.bin; do
    [[ -r "$p" ]] && { ISOHYBRID_MBR="$p"; break; }
  done
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
    -o "$OUT_ISO" \
    -J -R -l -iso-level 3 \
    -b "$BIOS_BIN" -c "$BIOS_CAT" \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
    "$EXTRACT"
else
  die "No recognizable boot assets found (no $UEFI_IMG and no $BIOS_BIN)."
fi

NEW_VOL="$(get_label "$OUT_ISO")"
echo "New ISO volume label: '$NEW_VOL'"

echo "Done. Rebuilt ISO at: $OUT_ISO"
