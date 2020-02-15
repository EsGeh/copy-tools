pkgname=copy-tools
pkgver=0.3
pkgrel=1
pkgdesc="Experimental scripts for copying directories and making incremental backups"
arch=("any")
url="https://github.com/EsGeh/copy-tools"
license=('GPL')
depends=( \
	'fishshell-cmd-opts=0.2' \
	'rsync>=3.1.3' \
)
optdepends=( \
	'openssh>=8.1p1' \
)
checkdepends=(
	'tree>=1.8.0' \
)
source=(ct-copy.fish ct-backup.fish ct-test-copy.fish ct-test-backup.fish __ct_utils.fish __ct_test_utils.fish)
sha1sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')

check() {
	echo "-----------------------------"
	echo "testing ct_copy.fish...:"
	echo "-----------------------------"
	./ct-test-copy.fish -i .
	echo "-----------------------------"
	echo "testing ct_backup.fish...:"
	echo "-----------------------------"
	./ct-test-backup.fish -i .
}

package() {
		dest_dir="/usr/bin"
		echo "dest_dir: $dest_dir"
    mkdir -p "$pkgdir/$dest_dir"
    install -D -m755 ./ct-copy.fish "$pkgdir/$dest_dir/"
    install -D -m755 ./ct-backup.fish "$pkgdir/$dest_dir/"
    install -D -m755 ./ct-test-copy.fish "$pkgdir/$dest_dir/"
    install -D -m755 ./ct-test-backup.fish "$pkgdir/$dest_dir/"
    install -D -m444 ./__ct_test_utils.fish "$pkgdir/$dest_dir/"
    install -D -m444 ./__ct_utils.fish "$pkgdir/$dest_dir/"
}
