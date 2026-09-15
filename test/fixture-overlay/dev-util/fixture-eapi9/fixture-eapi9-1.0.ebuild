# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=9

DESCRIPTION="Fixture package using EAPI 9, to detect runners whose bash is too old"
HOMEPAGE="https://github.com/daugustin/pkgcheck-action"

S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

src_install() {
	dodir /usr/share/${PN}
}
