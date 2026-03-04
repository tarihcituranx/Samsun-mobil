#!/usr/bin/env python3
"""
Nix dosyalarındaki liste virgüllerini otomatik temizler.
Kullanım: python3 fix_nix.py dosya.nix
"""

import re
import sys

def fix_nix(content: str) -> str:
    lines = content.split("\n")
    fixed = []

    for line in lines:
        # Yorum kısmını koru
        comment_match = re.search(r'#.*$', line)
        comment = comment_match.group(0) if comment_match else ""
        code = line[:comment_match.start()] if comment_match else line

        # Satır sonundaki virgülü kaldır (noktalı virgül hariç)
        # Nix'te [ ] içindeki öğelerin sonundaki virgüller geçersiz
        code = re.sub(r',(\s*)$', r'\1', code)

        fixed.append(code + comment)

    return "\n".join(fixed)


def main():
    if len(sys.argv) < 2:
        print("Kullanım: python3 fix_nix.py <dosya.nix>")
        sys.exit(1)

    path = sys.argv[1]

    with open(path, "r") as f:
        original = f.read()

    fixed = fix_nix(original)

    if original == fixed:
        print("✅ Zaten temiz, değişiklik gerekmedi.")
        return

    # Yedeği kaydet
    backup_path = path + ".bak"
    with open(backup_path, "w") as f:
        f.write(original)
    print(f"📦 Yedek kaydedildi: {backup_path}")

    with open(path, "w") as f:
        f.write(fixed)

    # Kaç satır değişti?
    orig_lines = original.split("\n")
    fixed_lines = fixed.split("\n")
    changed = sum(1 for a, b in zip(orig_lines, fixed_lines) if a != b)
    print(f"✅ {changed} satır düzeltildi: {path}")


if __name__ == "__main__":
    main()
