# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module go-microarch systemd

DESCRIPTION="mihomo Daemon, Another Clash Kernel."
HOMEPAGE="https://github.com/MetaCubeX/mihomo"

if [[ "${PV}" = *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/MetaCubeX/${PN}.git"
	EGIT_BRANCH=Alpha
else
	SRC_URI="https://github.com/MetaCubeX/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	SRC_URI+=" https://github.com/Xiami2012/moexiami-ovl-deps/releases/download/${P}/${P}-deps.tar.xz"
	KEYWORDS="~amd64"
fi

LICENSE="Apache-2.0 BSD-2 BSD CC0-1.0 GPL-3 ISC MIT MPL-2.0"
SLOT="0"
IUSE="+gvisor"

RDEPEND="
	acct-user/mihomo
	acct-group/mihomo
"

src_unpack() {
	if [[ "${PV}" = *9999 ]]; then
		git-r3_src_unpack
		go-module_live_vendor
	else
		go-module_src_unpack
	fi
}

src_compile() {
	local ver
	if [[ "${PV}" = *9999 ]]; then
		ver=vgit-${EGIT_VERSION:0:8}
	else
		ver=v${PV}
	fi
	go-microarch_setenv
	myldflags="-X \"github.com/metacubex/mihomo/constant.Version=${ver}\""
	myldflags+=" -X \"github.com/metacubex/mihomo/constant.BuildTime=$(LC_ALL=C date -u)\""
	ego build $(usex gvisor -tags=with_gvisor "") -trimpath -ldflags "$myldflags"
}

src_test() {
	ego test ./...
}

src_install() {
	dobin mihomo

	systemd_dounit "${FILESDIR}"/mihomo.service

	insinto /etc/mihomo
	doins "${FILESDIR}"/config.yaml
	newins ./docs/config.yaml config.yaml.example
}
