# Maintainer: Victor Coscrato <vcoscrato@users.noreply.github.com>

pkgname=speshell-git
pkgver=0
pkgrel=1
pkgdesc="A desktop shell built with Quickshell: a bar and its panels, a launcher, and animated themes"
arch=('any')
url="https://github.com/vcoscrato/speshell"
license=('MIT')
depends=(
  'bash'
  'bluez'
  'coreutils'
  'libnotify'
  'networkmanager'
  'pipewire'
  'procps-ng'
  'polkit'
  'quickshell>=0.3.0'
  'systemd'
  'upower'
  'util-linux'
  'which'
  'wireplumber'
)
makedepends=('git' 'just' 'qt6-shadertools')
optdepends=(
  'hyprland: workspaces in the bar and the Displays panel'
  'curl: downloading the dictation model'
  'brightnessctl: brightness and keyboard backlight controls, and dimming on idle'
  'power-profiles-daemon: the system power profile following the power mode'
  'cliphist: clipboard history'
  'hyprlock: default screen locker for power actions and locking on idle'
  'matugen: theming other apps from the Speshell palette'
  'openconnect: OpenConnect VPN logins'
  'libsecret: remembering VPN passwords in the keyring'
  'grim: screenshot, copy text, and scan code tools'
  'hyprpicker: pick color tool'
  'slurp: area selection for the screenshot, copy text, record, and scan code tools'
  'swappy: annotating screenshots'
  'tesseract: copy text tool (with a tesseract-data package per language)'
  'wf-recorder: record tool'
  'pipewire-audio: dictation tool, recording the microphone'
  'whisper-cpp: dictation tool'
  'wl-clipboard: clipboard capture, copy actions, and the tools'
  'wtype: dictation tool, typing the text'
  'zbar: scan code tool'
  'xdg-utils: opening the config when VISUAL and EDITOR are unset or no terminal is found'
)
provides=('speshell')
conflicts=('speshell')
source=("speshell::git+${url}.git")
sha256sums=('SKIP')

pkgver() {
  if [ -d speshell ]; then
    cd speshell
  fi
  printf 'r%s.g%s' \
    "$(git rev-list --count HEAD)" \
    "$(git rev-parse --short=7 HEAD)"
}

build() {
  cd speshell
  just shaders
}

package() {
  cd speshell

  install -d "$pkgdir/usr/share/speshell"
  install -m644 shell.qml config.example.ini "$pkgdir/usr/share/speshell/"
  cp -r assets bar components core panels services theme tools "$pkgdir/usr/share/speshell/"
  # Shipped themes and effects; each effect reaches lib/ through a relative symlink.
  install -d "$pkgdir/usr/share/speshell/extras"
  cp -r extras/effects extras/lib extras/themes "$pkgdir/usr/share/speshell/extras/"

  install -Dm644 README.md "$pkgdir/usr/share/doc/speshell/README.md"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 assets/icons/tabler/LICENSE \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE.tabler-icons"

  install -Dm755 bin/speshell "$pkgdir/usr/bin/speshell"

  # Qt portals identify the process through its desktop ID. Keep the metadata
  # entry hidden from launchers: Speshell starts with the session.
  install -Dm644 /dev/stdin \
    "$pkgdir/usr/share/applications/speshell.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Speshell
Comment=Desktop shell: a bar, its panels, and a launcher
Exec=speshell --no-duplicate
TryExec=speshell
Terminal=false
NoDisplay=true
Categories=Utility;
EOF

  # The user at the seat sets the battery's charge limit without a password, as
  # UPower lets them turn its own charge threshold on and off.
  install -Dm644 /dev/stdin \
    "$pkgdir/usr/share/polkit-1/actions/io.github.vcoscrato.speshell.policy" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <vendor>Speshell</vendor>
  <vendor_url>https://github.com/vcoscrato/speshell</vendor_url>
  <action id="io.github.vcoscrato.speshell.charge-limit">
    <description>Set the battery charge limit</description>
    <message>Authentication is required to set the battery charge limit</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/share/speshell/tools/charge-limit</annotate>
  </action>
</policyconfig>
EOF
}
