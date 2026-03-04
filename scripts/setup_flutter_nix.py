#!/usr/bin/env python3
"""
Flutter + Android için .idx/dev.nix dosyasını otomatik oluşturur.
Kullanım: python3 setup_flutter_nix.py
"""

import os

NIX_LINES = [
    '{pkgs}: {',
    '  channel = "stable-24.05";',
    '',
    '  packages = [',
    '    pkgs.jdk17',
    '    pkgs.unzip',
    '    pkgs.curl',
    '    pkgs.git',
    '    pkgs.which',
    '    pkgs.xz',
    '    pkgs.bash',
    '    (pkgs.python3.withPackages (ps: [',
    '      ps.pip',
    '      ps.pyyaml',
    '    ]))',
    '  ];',
    '',
    '  idx.extensions = [',
    '    "Dart-Code.flutter"',
    '    "Dart-Code.dart-code"',
    '  ];',
    '',
    '  idx.workspace.onCreate = {',
    '    setup-android-sdk = {',
    '      openFiles = [];',
    "      command = '''",
    '        set -e',
    '        ANDROID_SDK_ROOT="$HOME/android-sdk"',
    '        mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"',
    '        CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"',
    '        curl -o /tmp/cmdline-tools.zip "$CMDLINE_TOOLS_URL"',
    '        unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-tmp',
    '        mv /tmp/cmdline-tools-tmp/cmdline-tools "$ANDROID_SDK_ROOT/cmdline-tools/latest"',
    '        rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-tmp',
    '        export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"',
    '        yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses',
    '        sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \\',
    '          "platform-tools" \\',
    '          "platforms;android-34" \\',
    '          "build-tools;34.0.0" \\',
    '          "cmdline-tools;latest" \\',
    '          "emulator" \\',
    '          "system-images;android-34;google_apis;x86_64"',
    '        flutter config --android-sdk "$ANDROID_SDK_ROOT"',
    '        flutter config --no-analytics',
    '        echo "export ANDROID_SDK_ROOT=$HOME/android-sdk" >> "$HOME/.bashrc"',
    '        echo "export ANDROID_HOME=$HOME/android-sdk" >> "$HOME/.bashrc"',
    r'        echo "export PATH=\\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\\$ANDROID_SDK_ROOT/platform-tools:\\$PATH" >> "$HOME/.bashrc"',
    '        echo "Android SDK kurulumu tamamlandi!"',
    '        flutter doctor',
    "      '';",
    '    };',
    '  };',
    '',
    '  idx.previews = {',
    '    previews = {',
    '      web = {',
    '        command = [',
    '          "flutter"',
    '          "run"',
    '          "--machine"',
    '          "-d"',
    '          "web-server"',
    '          "--web-hostname"',
    '          "0.0.0.0"',
    '          "--web-port"',
    '          "$PORT"',
    '        ];',
    '        manager = "flutter";',
    '      };',
    '      android = {',
    '        command = [',
    '          "flutter"',
    '          "run"',
    '          "--machine"',
    '          "-d"',
    '          "android"',
    '          "-d"',
    '          "localhost:5555"',
    '        ];',
    '        manager = "flutter";',
    '      };',
    '    };',
    '  };',
    '}',
]

def main():
    idx_dir = os.path.join(os.getcwd(), ".idx")
    os.makedirs(idx_dir, exist_ok=True)

    nix_path = os.path.join(idx_dir, "dev.nix")

    if os.path.exists(nix_path):
        backup = nix_path + ".bak"
        with open(nix_path, "r") as f:
            old = f.read()
        with open(backup, "w") as f:
            f.write(old)
        print(f"Eski dev.nix yedeklendi: {backup}")

    with open(nix_path, "w") as f:
        f.write("\n".join(NIX_LINES) + "\n")

    print("OK: .idx/dev.nix olusturuldu")
    print()
    print("Kurulan paketler:")
    print("  jdk17, unzip, curl, git, xz, bash")
    print("  python3 + pip + pyyaml")
    print("  Flutter + Dart VSCode uzantilari")
    print("  Android SDK (platform-tools, android-34, build-tools, emulator)")
    print()
    print("Sonraki adim: IDX'te 'Rebuild Environment' sec")

if __name__ == "__main__":
    main()
