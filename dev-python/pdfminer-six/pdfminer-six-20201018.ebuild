# Copyright 2019-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{7..9} )
inherit distutils-r1

DESCRIPTION="Fork of PDFMiner using six for Python 2+3 compatibility"
HOMEPAGE="https://github.com/pdfminer/pdfminer.six https://pypi.org/project/pdfminer.six/"
MY_P=${P/-/.}
MY_PN=${PN/-/.}
SRC_URI="mirror://pypi/${MY_PN:0:1}/${MY_PN}/${MY_P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND=""
RDEPEND="
	$(python_gen_cond_dep 'dev-python/chardet[${PYTHON_USEDEP}]' -3)
	dev-python/cryptography[${PYTHON_USEDEP}]
	dev-python/sortedcontainers[${PYTHON_USEDEP}]
	!!app-text/pdfminer
"
BDEPEND=""

S="${WORKDIR}/${MY_P}"
