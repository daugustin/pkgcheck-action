# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Fixture package with deliberate QA violations"
HOMEPAGE="https://github.com/daugustin/pkgcheck-action"

# The license below is not in the gentoo tree, so this fires UnknownLicense
# (error). The license list lives in the master repo, so it only resolves once
# masters=gentoo is wired up: this doubles as proof that the synced gentoo tree
# is actually being consulted.
LICENSE="This-License-Does-Not-Exist"
SLOT="0"
KEYWORDS="~amd64"

# S belongs above LICENSE. Out of order here on purpose: VariableOrderWrong (style).
S="${WORKDIR}"

# The next line ends in a space on purpose (WhitespaceFound, carries line list). 
# The next line contains a non-breaking space on purpose (BadWhitespaceCharacter, carries lineno).
# here is the nbsp: end

src_install() {
	dodir /usr/share/${PN}
}
