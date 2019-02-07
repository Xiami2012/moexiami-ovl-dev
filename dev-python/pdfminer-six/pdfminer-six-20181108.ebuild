# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python2_7 python3_{4,5,6} )
inherit distutils-r1

DESCRIPTION="Fork of PDFMiner using six for Python 2+3 compatibility"
HOMEPAGE="https://github.com/pdfminer/pdfminer.six"
SRC_URI="https://github.com/pdfminer/pdfminer.six/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND=""
RDEPEND="
	dev-python/pycryptodome[${PYTHON_USEDEP}]
	dev-python/six[${PYTHON_USEDEP}]
	dev-python/sortedcontainers[${PYTHON_USEDEP}]
	$(python_gen_cond_dep 'dev-python/chardet[${PYTHON_USEDEP}]' -3)
	!!app-text/pdfminer
"
BDEPEND=""

S="${WORKDIR}/pdfminer.six-${PV}"
