# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-tex/envlab/envlab-1.2-r1.ebuild,v 1.18 2012/05/09 17:16:08 aballier Exp $

EAPI=5

PYTHON_COMPAT=( python{2_7,3_2,3_3} )

inherit latex-package python-single-r1

S="${WORKDIR}/${PN}"
LICENSE="LPPL-1.3 BSD"
DESCRIPTION="Fast Access to Python from within LaTeX"
HOMEPAGE="https://github.com/gpoore/pythontex"
SRC_URI="https://github.com/gpoore/pythontex/raw/master/package_downloads/${PN}_${PV}.zip https://github.com/gpoore/pythontex/raw/master/package_downloads/old_versions/${PN}_${PV}.zip"
SLOT="0"
KEYWORDS="~amd64"
IUSE="highlighting"

DEPEND="app-text/texlive
	${PYTHON_DEPS}"

RDEPEND="${DEPEND}
	highlighting? ( dev-python/pygments[${PYTHON_USEDEP}] )"

TEXMF=/usr/share/texmf-site

S="${WORKDIR}"/${PN}

src_prepare() {
	rm pythontex.sty
}

src_compile() {
	ebegin "Compiling ${PN}"
	latex ${PN}.ins extra >/dev/null || die "Building style from ${PN}.ins failed"
	eend
	sed -i -e '1i#!/usr/bin/env python' depythontex.py || die "adding shebang failed!"
	sed -i -e '1i#!/usr/bin/env python' depythontex2.py || die "adding shebang failed!"
	sed -i -e '1i#!/usr/bin/env python' depythontex3.py || die "adding shebang failed!"
}

src_install() {
	python_optimize .
	if python_is_python3; then 
		python_scriptinto /usr/share/texmf-site/scripts/pythontex/
		python_newscript pythontex3.py pythontex.py 
		python_newscript depythontex3.py depythontex.py
		insinto /usr/share/texmf-site/scripts/${PN}/
		doins "${S}"/${PN}3.py
	fi
	
	if ! python_is_python3; then
		python_scriptinto /usr/share/texmf-site/scripts/pythontex/
		python_newscript pythontex2.py pythontex.py
		python_doscript pythontex_2to3.py
		python_newscript depythontex2.py depythontex.py
		insinto /usr/share/texmf-site/scripts/${PN}/
		doins "${S}"/${PN}2.py
	fi
	
	insinto /usr/share/texmf-site/scripts/pythontex/
	dolib "${S}"/pythontex_engines.py 
	dolib "${S}"/pythontex_utils.py

	insinto /usr/share/texmf-site/tex/latex/pythontex/
	doins "${S}"/pythontex.sty

	#insinto /usr/$(get_libdir)/python-exec
	#doins "${S}"/pythontex_engines.py
	
	insinto /usr/share/texmf-site/source/latex/pythontex/
	doins "${S}"/pythontex.dtx 
	doins "${S}"/pythontex.ins	

	latex-package_src_install

	#dosym /usr/share/texmf-site/scripts/${PN}/${PN}.py /usr/bin/${PN}

	echo "LDPATH=/usr/share/texmf-site/scripts/pythontex/" >> "${T}"/99${PN} || die "Can't write environment variable."
	doenvd "${T}"/99${PN}

	dodoc README
	mktexlsr
}
