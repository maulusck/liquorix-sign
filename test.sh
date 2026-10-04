#!/bin/sh
# unprivileged via `unshare -r` (see Makefile). needs openssl, sbsigntools and any PE/EFI binary: EFI=/path ./test.sh
set -eu
efi=${EFI:-$(ls /usr/lib/systemd/boot/efi/*.efi /boot/efi/EFI/*/*.efi 2>/dev/null | head -1)}
[ -f "$efi" ] || { echo "set EFI=/some/binary.efi"; exit 1; }
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
s=$(dirname "$0")/liquorix-sign
fail() { echo "FAIL: $*"; exit 1; }
key() { openssl req -new -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=t/ \
	-keyout "$d/$1.key" -out "$d/$1.crt" 2>/dev/null; chmod 600 "$d/$1.key"; }
key a; key b
k=$d/vmlinuz-6.9-liquorix-amd64
cp "$efi" "$k"; cp "$efi" "$d/vmlinuz-6.9-generic"; ln -s "$k" "$d/link-lqx"
export BOOT=$d SYSEFI=$d/no-efi  # throwaway keys are never enrolled

KEY=$d/a.key "$s" "$k" 2>/dev/null && fail "half a key pair accepted"
KEY=$d/a.key CERT=$d/b.crt "$s" "$k" 2>/dev/null && fail "mismatched key accepted"
cmp -s "$efi" "$k" || fail "original touched on failure"
chmod 644 "$d/a.key"
KEY=$d/a.key CERT=$d/a.crt "$s" 2>/dev/null && fail "world-readable key accepted"
chmod 600 "$d/a.key"
export KEY=$d/a.key CERT=$d/a.crt
"$s" | grep -q "signed $k" || fail "glob sign"
sbverify --cert "$d/a.crt" "$k" >/dev/null 2>&1 || fail "not verifiable"
"$s" "$d/link-lqx" | grep -q "ok     $k" || fail "symlink not resolved / not idempotent"
[ -L "$d/link-lqx" ] || fail "symlink clobbered"
"$s" "$d/vmlinuz-6.9-generic"; cmp -s "$efi" "$d/vmlinuz-6.9-generic" || fail "non-liquorix touched"
[ -z "$(ls -A "$d" | grep '^\.')" ] || fail "temp file left"
openssl x509 -in "$d/a.crt" -outform DER -out "$d/a.der"
CERT=$d/a.der "$s" "$k" | grep -q ok || fail "DER cert"
rm "$k"; "$s" 2>/dev/null && fail "empty /boot accepted"
sh "$(dirname "$0")/hooks/debian" 6.9 || fail "debian hook without image"
echo PASS
