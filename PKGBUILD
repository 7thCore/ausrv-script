# Maintainer: 7thCore

pkgname=ausrv-script
pkgver=1.0
pkgrel=4
pkgdesc='Among Us Impostor server script for running the server on linux.'
arch=('x86_64')
license=('GPL3')
depends=('bash'
         'coreutils'
         'sudo'
         'grep'
         'sed'
         'awk'
         'curl'
         'rsync'
         'wget'
         'findutils'
         'tmux'
         'zip'
         'unzip'
         'p7zip'
         'postfix')
install=ausrv-script.install
source=('ausrv-script.bash'
        'ausrv-send-notification@.service'
        'ausrv@.service'
        'ausrv-timer-1.service'
        'ausrv-timer-1.timer'
        'ausrv-timer-2.service'
        'ausrv-timer-2.timer'
        'bash_profile')
sha256sums=('4d3d23aaa0a61c195894e044f4b6a32aeaa67b1022390f83487e82ddcf7aa5c6'
            'e94f4da0e2fd7d4533839d7ffb1ed63ce3dd703524db4311a1c285eccc8eb677'
            'b9155bd9754c905e6b1821f24468eb11532d76ac52a7a740b8a8124527541ddd'
            '98d21b496553e0039aef53e1be7ec9af7f045027257874afeea767fa4a050e87'
            '410e7ba6be21f4d1576ef5cf3afefe4892469852ad188c430b2bcb1a6e7e46fe'
            'e7a157aa21ce2578a61bbbc4a43806c99d0e4e476d0c2991cf76039b53425226'
            'f95522bdb6bc1195b5ccf6fc7ed0100c1704e5d9160bf5cf3d82385e22dff520'
            'f1e2f643b81b27d16fe79e0563e39c597ce42621ae7c2433fd5b70f1eeab5d63')

package() {
  install -d -m0755 "${pkgdir}/usr/bin"
  install -d -m0755 "${pkgdir}/srv/ausrv"
  install -d -m0755 "${pkgdir}/srv/ausrv/config"
  install -d -m0755 "${pkgdir}/srv/ausrv/backups"
  install -d -m0755 "${pkgdir}/srv/ausrv/logs"
  install -d -m0755 "${pkgdir}/srv/ausrv/.config"
  install -d -m0755 "${pkgdir}/srv/ausrv/.config/systemd"
  install -d -m0755 "${pkgdir}/srv/ausrv/.config/systemd/user"
  install -D -Dm755 "${srcdir}/ausrv-script.bash" "${pkgdir}/usr/bin/ausrv-script"
  install -D -Dm755 "${srcdir}/ausrv-timer-1.timer" "${pkgdir}/srv/ausrv/.config/systemd/user/ausrv-timer-1.timer"
  install -D -Dm755 "${srcdir}/ausrv-timer-1.service" "${pkgdir}/srv/ausrv/.config/systemd/user/ausrv-timer-1.service"
  install -D -Dm755 "${srcdir}/ausrv-timer-2.timer" "${pkgdir}/srv/ausrv/.config/systemd/user/ausrv-timer-2.timer"
  install -D -Dm755 "${srcdir}/ausrv-timer-2.service" "${pkgdir}/srv/ausrv/.config/systemd/user/ausrv-timer-2.service"
  install -D -Dm755 "${srcdir}/ausrv-send-notification@.service" "${pkgdir}/srv/ausrv/.config/systemd/user/ausrv-send-notification@.service"
  install -D -Dm755 "${srcdir}/ausrv@.service" "${pkgdir}/srv/ausrv/.config/systemd/user/ausrv@.service"
  install -D -Dm755 "${srcdir}/bash_profile" "${pkgdir}/srv/ausrv/.bash_profile"
}
