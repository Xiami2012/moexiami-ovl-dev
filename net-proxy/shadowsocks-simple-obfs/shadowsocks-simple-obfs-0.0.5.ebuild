# Copyright 2018 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit autotools

DESCRIPTION="A simple obfuscating tool designed as plugin server of shadowsocks"
HOMEPAGE="https://github.com/shadowsocks/simple-obfs"
SRC_URI="https://github.com/shadowsocks/simple-obfs/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="+doc"

DEPEND="dev-libs/libev
	net-libs/libcork"
RDEPEND="${DEPEND}"
BDEPEND="doc? (
		app-text/asciidoc
		app-text/xmlto
	)"

S="${WORKDIR}"/simple-obfs-"${PV}"

src_prepare() {
	sed -i "s:libcork/Makefile::" configure.ac
	sed -i "s:\(SUBDIRS =.*\) libcork:\1:" Makefile.am
	sed -i -e 's:$(top_builddir)/libcork/libcork.la:-lcork:' \
		-e '/AM_CFLAGS.*libcork/d' src/Makefile.am
	default
	eautoreconf
}

src_configure() {
	myconf=""
	if ! use doc; then
		myconf+="--disable-documentation"
	fi

	econf ${myconf}
}
