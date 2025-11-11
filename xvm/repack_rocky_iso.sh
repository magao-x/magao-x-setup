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
# isoinfo is optional but preferred for label reading
HAS_ISOINFO=true; command -v isoinfo >/dev/null 2>&1 || HAS_ISOINFO=false

# Optional (for BIOS hybrid MBR) – not needed for aarch64
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

# --- Get original Volume Label exactly ---
VOL_ID=""
if $HAS_ISOINFO; then
  VOL_ID="$(isoinfo -d -i "$ISO" 2>/dev/null | awk -F': ' '/Volume id:/ {print $2; exit}')"
fi
if [[ -z "$VOL_ID" ]]; then
  VOL_ID="$(xorriso -indev "$ISO" -pvd_info 2>/dev/null | sed -n "s/^Volume id[[:space:]]*:[[:space:]]*'\\{0,1\\}\\([^']*\\).*/\\1/p" | head -n1)"
fi
[[ -z "$VOL_ID" ]] && die "Could not read ISO volume label"

echo "Original volume label: '$VOL_ID'"

# --- Patch helpers ---
patch_isolinux() {
  local f="$1"; [[ -f "$f" ]] || return 0
  echo "Patching ISOLINUX: $f"
  # Ensure inst.stage2 points to LABEL and add inst.cmdline once
  sed -Ei '/^[[:space:]]*append /{
      s|(.*)inst\.stage2=[^[:space:]]*|\1|g
      s|^( *append .*)|\1 inst.stage2=hd:LABEL='"$VOL_ID"'|
      /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|$| inst.cmdline|
  }' "$f"
}

patch_grub_vars() {
  local f="$1"; [[ -f "$f" ]] || return 0
  echo "Patching GRUB (vars): $f"
  # Rocky aarch64 minimal sets args via: set kernelopts="..."
  # Some variants use: set kargs="..."
  # Normalize both:
  sed -Ei \
    -e 's/^( *set +(kernelopts|kargs)=)(["'\'']?)(.*)\3$/\1\3\4\3/' \
    -e '/^( *set +(kernelopts|kargs)=)/{
          s/(^ *set +(kernelopts|kargs)=["'\'']?)(.*)(["'\'']?$)/\1\3\4/
        }' "$f"

  # Replace any inst.stage2=... token; if missing, append ours.
  # Ensure inst.cmdline present exactly once.
  sed -Ei \
    -e '/^( *set +(kernelopts|kargs)=)/{
          s/(^ *set +(kernelopts|kargs)=["'\'']?)(.*)inst\.stage2=[^[:space:]"]*/\1\3/g
        }' \
    -e '/^( *set +(kernelopts|kargs)=)/{
          s/(^ *set +(kernelopts|kargs)=["'\'']?)(.*)/\1\3 inst.stage2=hd:LABEL='"$VOL_ID"'/ 
        }' \
    -e '/^( *set +(kernelopts|kargs)=)/{
          /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s/(^ *set +(kernelopts|kargs)=["'\'']?)(.*)/\1\3 inst.cmdline/
        }' "$f"
}

# For completeness, also patch any direct linux/linuxefi lines (x86_64 DVDs)
patch_grub_linux() {
  local f="$1"; [[ -f "$f" ]] || return 0
  echo "Patching GRUB (linux lines): $f"
  sed -Ei -e "/^( *linux(efi)? +)/{
      s|(.*)inst\.stage2=[^[:space:]]*|\1|g
      s|^( *linux(efi)? +.*)|\1 inst.stage2=hd:LABEL=${VOL_ID}|
    }" \
    -e "/^( *linux(efi)? +)/{
      /(^|[[:space:]])inst\.cmdline([[:space:]]|$)/! s|$| inst.cmdline|
    }" "$f"
}

# --- Apply patches across common locations ---
patch_isolinux "$EXTRACT/isolinux/isolinux.cfg"
patch_isolinux "$EXTRACT/isolinux/grub.conf"

for gf in \
  "$EXTRACT/EFI/BOOT/grub.cfg" \
  "$EXTRACT/EFI/rocky/grub.cfg" \
  "$EXTRACT/boot/grub2/grub.cfg"
do
  patch_grub_vars "$gf"
  patch_grub_linux "$gf"
done

# --- Show resulting kernel arg sources for CI logs ---
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

# --- Detect boot assets and rebuild with SAME label ---
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

NEW_VOL="$(xorriso -indev "$OUT_ISO" -pvd_info 2>/dev/null | sed -n "s/^Volume id[[:space:]]*:[[:space:]]*'\\{0,1\\}\\([^']*\\).*/\\1/p" | head -n1)"
echo "New ISO volume label: '$NEW_VOL'"

echo "Done. Rebuilt ISO at: $OUT_ISO"
