# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit multilib

# @ECLASS: mpi.eclass
# @MAINTAINER:
# Justin Bronder <jsbronder@gentoo.org>
# Cluster Team <cluster@gentoo.org>
# @AUTHOR:
# Justin Bronder <jsbronder@gentoo.org>
# @VCSURL: http://git.overlays.gentoo.org/gitweb/?p=proj/sci.git;a=history;f=eclass/mpi.eclass;hb=HEAD
# @BLURB:  Common functions for mpi support in ebuilds
# @DESCRIPTION:
# This eclass is intended to support classed installations of mpi
# implementations in ebuilds. For extend description please visit:
#
# https://wiki.gentoo.org/....
#
# @EXAMPLE:
#
# inherit mpi
#
#


#####################
# Private Variables #
#####################

# @ECLASS-VARIABLE: __MPI_ALL_IMPLEMENTATION_PNS
# @INTERNAL
# @REQUIRED
# @DESCRIPTION:
#
# All known mpi implementations
__MPI_ALL_IMPLEMENTATION_PNS="lam-mpi mpich mpich2 openmpi openib-mvapich2"

# @ECLASS-VARIABLE: __MPI_ALL_CLASSABLE_PNS
# @INTERNAL
# @REQUIRED
# @DESCRIPTION:
#
# All mpi implentations that can be classed.
__MPI_ALL_CLASSABLE_PNS="lam-mpi mpich mpich2 openmpi"


###################################################################
# Generic Functions that are used by Implementations and Packages #
###################################################################

# @ECLASS-VARIABLE: MPI_UNCLASSED_DEP_STR
# @DEFAULT_UNSET
# @DESCRIPTION:
#
# String inserted into the deplist when not using a classed
# install.

# @FUNCTION: mpi_classed
# @RETURN: True if this build is classed.
# @DESCRIPTION:
# Check if the current package is classed
mpi_classed() {
	[[ ${CATEGORY} == mpi-* ]]
}

# @FUNCTION: mpi_class
# @RETURN: The name of the current class, or nothing if unclassed
# @DESCRIPTION:
# Get the class if the installaiton is classed
mpi_class() {
	mpi_classed && echo "${CATEGORY}"
}

# @FUNCTION: mpi_root
# @RETURN: The root path that packages should be installed to.
# @DESCRIPTION:
# Query for the root path of the package. In the end, the majority of a package
# will will install to $(mpi_root).
mpi_root() {
	if mpi_classed; then
		echo "/usr/$(get_libdir)/mpi/$(mpi_class)/"
	else
		echo "/"
	fi
}

# @FUNCTION: mpi_econf_args
# @RETURN: If classed, a list of arguments for econf that sets the default install locations
# @DESCRIPTION:
# If classed, returns a list of arguments for econf that sets the
# default install locations correctly. Should be first in the list of arguments
# to econf so that any unsuitable options can be overwritten.
mpi_econf_args() {
	if mpi_classed; then
		local d=$(mpi_root)
		local c=$(mpi_class)
		local a="
			--prefix=${d}usr
			--mandir=${d}usr/share/man
			--infodir=${d}usr/share/info
			--datadir=${d}usr/share
			--sysconfdir=/etc/${c}
			--localstatedir=/var/lib/${c}"
		echo "${a}"
	fi
}

# @FUNCTION: _mpi_do
# @USAGE: <standard helper function>
# @INTERNAL
# @DESCRIPTION:
# Large wrapping class for all of the {do,new}* commands that need
# to respect the new root to install to. Works with unclassed builds as well.
_mpi_do() {
	local rc prefix d
	local cmd=${1}
	local ran=1
	local slash=/
	local mdir="$(mpi_root)"

	if ! mpi_classed; then
		$*
		return ${?}
	fi

	shift
	if [ "${cmd#do}" != "${cmd}" ]; then
		prefix="do"; cmd=${cmd#do}
	elif [ "${cmd#new}" != "${cmd}" ]; then
		prefix="new"; cmd=${cmd#new}
	else
		die "Unknown command passed to _mpi_do: ${cmd}"
	fi
	case ${cmd} in
		bin|lib|lib.a|lib.so|sbin)
			DESTTREE="${mdir}usr" ${prefix}${cmd} $*
			rc=$?;;
		doc)
			_E_DOCDESTTREE_="../../../../${mdir}usr/share/doc/${PF}/${_E_DOCDESTTREE_}" \
				${prefix}${cmd} $*
			rc=$?
			for d in "/share/doc/${P}" "/share/doc" "/share"; do
				rmdir ${D}/usr${d} &>/dev/null
			done
			;;
		html)
			_E_DOCDESTTREE_="../../../../${mdir}usr/share/doc/${PF}/www/${_E_DOCDESTTREE_}" \
				${prefix}${cmd} $*
			rc=$?
			for d in "/share/doc/${P}/html" "/share/doc/${P}" "/share/doc" "/share"; do
				rmdir ${D}/usr${d} &>/dev/null
			done
			;;
		exe)
			_E_EXEDESTTREE_="${mdir}${_E_EXEDESTTREE_}" ${prefix}${cmd} $*
			rc=$?;;
		man|info)
			[ -d "${D}"usr/share/${cmd} ] && mv "${D}"usr/share/${cmd}{,-orig}
			[ ! -d "${D}"${mdir}usr/share/${cmd} ] \
				&& install -d "${D}"${mdir}usr/share/${cmd}
			[ ! -d "${D}"usr/share ] \
				&& install -d "${D}"usr/share

			ln -snf ../../${mdir}usr/share/${cmd} ${D}usr/share/${cmd}
			${prefix}${cmd} $*
			rc=$?
			rm "${D}"usr/share/${cmd}
			[ -d "${D}"usr/share/${cmd}-orig ] \
				&& mv "${D}"usr/share/${cmd}{-orig,}
			[ "$(find "${D}"usr/share/)" == "${D}usr/share/" ] \
				&& rmdir "${D}usr/share"
			;;
		dir)
			dodir "${@/#${slash}/${mdir}${slash}}"; rc=$?;;
		hard|sym)
			${prefix}${cmd} "${mdir}$1" "${mdir}/$2"; rc=$?;;
		ins)
			INSDESTTREE="${mdir}${INSTREE}" ${prefix}${cmd} $*; rc=$?;;
		*)
			rc=0;;
	esac

	[[ ${ran} -eq 0 ]] && die "mpi_do passed unknown command: ${cmd}"
	return ${rc}
}

# @FUNCTION: mpi_do<standard_helper_function>
# @DESCRIPTION:
# Wrapper for standard ebuild helper functions like the {do,new}* commands that
# need to respect the new root to install to. Works with unclassed builds as well.
#
# Currently supported <standard helper function>s are:
# @CODE
# dobin    newbin    dodoc     newdoc
# doexe    newexe    dohtml    dolib
# dolib.a  newlib.a  dolib.so  newlib.so
# dosbin   newsbin   doman     newman
# doinfo   dodir     dohard    doins
# dosym
# @CODE
mpi_dobin()     { _mpi_do "dobin"        $*; }
mpi_newbin()    { _mpi_do "newbin"       $*; }
mpi_dodoc()     { _mpi_do "dodoc"        $*; }
mpi_newdoc()    { _mpi_do "newdoc"       $*; }
mpi_doexe()     { _mpi_do "doexe"        $*; }
mpi_newexe()    { _mpi_do "newexe"       $*; }
mpi_dohtml()    { _mpi_do "dohtml"       $*; }
mpi_dolib()     { _mpi_do "dolib"        $*; }
mpi_dolib.a()   { _mpi_do "dolib.a"      $*; }
mpi_newlib.a()  { _mpi_do "newlib.a"     $*; }
mpi_dolib.so()  { _mpi_do "dolib.so"     $*; }
mpi_newlib.so() { _mpi_do "newlib.so"    $*; }
mpi_dosbin()    { _mpi_do "dosbin"       $*; }
mpi_newsbin()   { _mpi_do "newsbin"      $*; }
mpi_doman()     { _mpi_do "doman"        $*; }
mpi_newman()    { _mpi_do "newman"       $*; }
mpi_doinfo()    { _mpi_do "doinfo"       $*; }
mpi_dodir()     { _mpi_do "dodir"        $*; }
mpi_dohard()    { _mpi_do "dohard"       $*; }
mpi_doins()     { _mpi_do "doins"        $*; }
mpi_dosym()     { _mpi_do "dosym"        $*; }


###########################################
# Functions for MPI Implementation Builds #
###########################################

# @FUNCTION: mpi_imp_deplist
# @DESCRIPTION:
# asd
# @USAGE:
# @RETURNS: Returns a deplist that handles the blocking between mpi
# implementations, and any blockers as specified in MPI_UNCLASSED_DEP_STR
mpi_imp_deplist() {
	local c="sys-cluster"
	local pn ver

	mpi_classed && c="${CATEGORY}"
	ver=""
	for pn in ${__MPI_ALL_IMPLEMENTATION_PNS}; do
		ver="${ver} !${c}/${pn}"
	done
	if ! mpi_classed && [ -n "${MPI_UNCLASSED_DEP_STR}" ]; then
		ver="${ver} ${MPI_UNCLASSED_DEP_STR}"
	else
		ver="${ver} sys-cluster/empi"
	fi
	echo "${ver}"
}

mpi_imp_add_eselect() {
	mpi_classed || return 0
	local c=$(mpi_class)
	cp "${FILESDIR}"/${MPI_ESELECT_FILE} ${T}/${c}.eselect || die
	sed -i \
		-e "s|@ROOT@|$(mpi_root)|g" \
	 	-e "s|@LIBDIR@|$(get_libdir)|g" \
		-e "s|@BASE_IMP@|${PN}|g" \
		${T}/${c}.eselect || die

	eselect mpi add "${T}"/${c}.eselect || die
}



########################################
# Functions for packages requiring MPI #
########################################

# @ECLASS-VARIABLE: MPI_PKG_NEED_IMPS
# @DESCRIPTION:
#
# List of package names (${PN}) of mpi implementations that this package is
# compatible with. Default is the list of all mpi implementations
: ${MPI_PKG_NEED_IMPS:=${__MPI_ALL_CLASSABLE_PNS}}

# @ECLASS-VARIABLE: MPI_REQ_USE
# @DEFAULT_UNSET
# @DESCRIPTION:
# The list of USEflags required to be enabled on the chosen mpi
# implementations, formed as a USE-dependency string. It should match the
# USE of virtual/mpi.
#
# This should be set before calling `inherit'.
#
# Example:
# @CODE
# MPI_REQ_USE="cxx,romio(-)?"
# @CODE
#
# It will cause the mpi dependencies to look like:
#
# Unclassed installation:
# @CODE
# virtual/mpi[cxx,romio(-)?]
# @CODE
#
# Classed installaion:
# @CODE
# sys-cluster/empi
# virtual/mpi[cxx,romio(-)?]
# @CODE



# @ECLASS-VARIABLE: MPI_PKG_USE_CXX
# @DEFAULT_UNSET
# @DESCRIPTION:
#
# Require a mpi implementation with c++ enabled.
#
# DEPRECATED varaible, please use MPI_REQ_USE


# @ECLASS-VARIABLE: MPI_PKG_USE_FC
# @DEFAULT_UNSET
# @DESCRIPTION:
#
# Require a mpi implementation with fortran enabled.
#
# DEPRECATED varaible, please use MPI_REQ_USE


# @ECLASS-VARIABLE: MPI_PKG_USE_ROMIO
# @DEFAULT_UNSET
# @DESCRIPTION:
#
# Require a mpi implementation with romio enabled.
#
# DEPRECATED varaible, please use MPI_REQ_USE


# @FUNCTION: mpi_pkg_deplist
# @DESCRIPTION:
# asd
# @USAGE:
# @RETURN: Returns a deplist comprised of valid implementations and any blockers
# depending on if this package is building with mpi class support.
mpi_pkg_deplist() {
	local pn pn2 ver usedeps invalid_imps inval

	if [[ ${MPI_REQ_USE} ]]; then
		usedeps=${MPI_REQ_USE}
	else
		[[ -n ${MPI_PKG_USE_CXX} ]] && usedeps+=" cxx"
		[[ -n ${MPI_PKG_USE_FC} ]] && usedeps+=" fortran"
		[[ -n ${MPI_PKG_USE_ROMIO} ]] && usedeps+=" romio"

		if [[ -n "${usedeps}" ]] ; then
			eqawarn "This ebuild is using a deprecated way of setting USE deps"
			eqawarn "Please report a bug at https:bugs.gentoo.org"

			usedeps=${usedeps/ /,}
		fi
	fi

	if mpi_classed; then
		ver="sys-cluster/empi virtual/$(mpi_class)"
	else
		ver="virtual/mpi"
	fi

	if [[ -n "${usedeps}" ]]; then
		ver+="[${usedeps:1}]"
	fi

	if ! mpi_classed && [ -n "${MPI_UNCLASSED_DEP_STR}" ]; then
		ver+=" ${MPI_UNCLASSED_DEP_STR}"
	fi

	for pn in ${__MPI_ALL_IMPLEMENTATION_PNS}; do
		inval=1
		for pn2 in ${MPI_PKG_NEED_IMPS}; do
			if [ "${pn}" == "${pn2}" ]; then
				inval=0
				break;
			fi
		done
		[[ ${inval} -eq 1 ]] \
			&& invalid_imps+=" ${pn}"
	done

	for pn in ${inval_imps}; do
		ver="${ver} !${c}/${pn}"
	done
	echo "${ver}"
}

# @FUNCTION: mpi_pkg_base_imp
# @USAGE:
# @DESCRIPTION: Returns the ${PN} of the package providing mpi support.   Works
# even when using an unclassed mpi build.
mpi_pkg_base_imp() {
	if mpi_classed; then
		echo "$(_get_eselect_var CLASS_BASE_MPI_IMP)"
	else
		local pn
		for pn in ${MPI_PKG_NEED_IMPS}; do
			if has_version "sys-cluster/${pn}"; then
				echo "${PN}"
			fi
		done
	fi
}

# @FUNCTION:  mpi_pkg_set_ld_library_path
# @DESCRIPTION:
# Adds the correct path(s) to the end of LD_LIBRARY_PATH.  Does
# nothing if the build is unclassed.
mpi_pkg_set_ld_library_path() {
	if mpi_classed; then
		export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:$(_get_eselect_var LD_LIBRARY_PATH)"
	fi
}

# @FUNCTION: _mpi_pkg_compiler
# @USAGE: <class variable for compiler> <suffix for generic mpi## executable>
# @INTERNAL
# @DESCRIPTION:
#
# If classed, we can ask eselect-mpi.  Otherwise we'll look for some common
# executable names in ${EROOT}usr/bin.
#
_mpi_pkg_compiler() {
	[[ $# -lt 2 ]] && die "_mpi_pkg_compiler() requires at least two arguments"
	if mpi_classed; then
		echo "$(eselect mpi printvar $(mpi_class) ${1})"
	else
		local suffixes=${2}
		local p

		for p in ${suffixes}; do
			if [ -x "${EROOT}usr/bin/mpi${p}" ]; then
				echo "${EROOT}usr/bin/mpi${p}"
				break
			fi
		done
	fi
}

# @FUNCTION: mpi_pkg_<compiler>
# @RETURN: Full path to the mpi version of <compiler>
# @DESCRIPTION:
#
# Trys to find a mpi version of <compiler>, even if this build is unclassed.
# If return is empty, user should assume the implementation does not support
# this compiler
#
# Currently supported <compiler> are
# @CODE
# cc cxx f90 fc f77
# @CODE
mpi_pkg_cc()  { _mpi_pkg_compiler "MPI_CC"  "cc"     ; }
mpi_pkg_cxx() { _mpi_pkg_compiler "MPI_CXX" "cxx"    ; }
mpi_pkg_fc()  { _mpi_pkg_compiler "MPI_FC"  "f90 fc" ; }
mpi_pkg_f90() { _mpi_pkg_compiler "MPI_F90" "f90 fc" ; }
mpi_pkg_f77() { _mpi_pkg_compiler "MPI_F77" "f77"    ; }

# @FUNCTION: mpi_pkg_set_env
# @DESCRIPTION:
#
# Export Class specific build variables like CC, CXX, F77, FC, PKG_CONFIG_PATH
#
mpi_pkg_set_env() {
	if mpi_classed; then
		_mpi_oCC=${CC}
		_mpi_oCXX=${CXX}
		_mpi_oF77=${F77}
		_mpi_oFC=${FC}
		_mpi_oF90=${F90}
		_mpi_oPCP=${PKG_CONFIG_PATH}
		_mpi_oLLP=${LD_LIBRARY_PATH}
		export CC=$(mpi_pkg_cc)
		export CXX=$(mpi_pkg_cxx)
		export F77=$(mpi_pkg_f77)
		export FC=$(mpi_pkg_fc)
		export F90=$(mpi_pkg_fc)
		export PKG_CONFIG_PATH="$(mpi_root)$(get_libdir)/pkgconfig:${PKG_CONFIG_PATH}"
		mpi_pkg_set_ld_library_path
	fi
}

# @FUNCTION: mpi_pkg_restore_env
# @DESCRIPTION:
# Attempts to undo the changes in enviroment done by mpi_pkg_set_env
mpi_pkg_restore_env() {
	if mpi_classed; then
		export CC=${_mpi_oCC}
		export CXX=${_mpi_oCXX}
		export F77=${_mpi_oF77}
		export FC=${_mpi_oFC}
		export F90=${_mpi_oFC}
		export PKG_CONFIG_PATH=${_mpi_oPCP}
		export LD_LIBRARY_PATH=${_mpi_oLLP}
	fi
}

# @FUNCTION: _get_eselect_var
# @USAGE: VARIABLE
# @RETURN: If classed, return VARIABLE content; otherwise empty
# @INTERNAL
# @DESCRIPTION:
# Get variable for a class from the env.d file
_get_eselect_var() {
	if mpi_classed && [ -n "${1}" ]; then
		echo "$(eselect mpi printvar $(mpi_class) ${1} 2>/dev/null)"
	fi
}

case "${EAPI:-0}" in
	0|1|2|3) die "EAPI=${EAPI} is not supported" ;;
esac

