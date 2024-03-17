# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: go-microarch.eclass
# @MAINTAINER:
# Xiami <i@f2light.com>
# @AUTHOR:
# Xiami <i@f2light.com>
# @VCSURL: https://github.com/Xiami2012/moexiami-ovl-dev/blob/master/eclass/go-microarch.eclass
# @SUPPORTED_EAPIS: 8
# @BLURB: Determine microarchitecture environment variables for Go building
# @DESCRIPTION:
# Select microarchitecture environment variables, such as GOAMD64, for Go
# build processes by reusing cpu_flags_* USE flags.
#
# The implementation can be somewhat tricky since the cpu_flags_* USE flags
# are not exhaustive. Some instruction set extensions do not appear in
# /proc/cpuinfo either. It is also challenging to account hierarchical
# relationships among them. (e.g. all CPUs supporting avx2 also support avx)
#
# Thus, the decision-making process is as follows: we assume a specific
# microarchitecture level is reached if all required cpu_flags_* USE flags
# for that level are enabled. This implies that any additional instruction
# set extensions needed for that microarchitecture level, even if not yet
# represented as a cpu_flags USE flag, are presumed to be present.
#
# Currently only GOAMD64 is supported.
# Also note that, GO386 and GOARM are set by go-env.eclass .
# @EXAMPLE:
# To utilize this eclass, inherit it and invoke go-microarch_setenv within
# src_compile.
#
# @CODE
# inherit go-microarch
#
# src_compile() {
#   go-microarch_setenv
#   ego build
# }
# @CODE

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ ! ${_GO_MICROARCH_ECLASS} ]]; then
_GO_MICROARCH_ECLASS=1

# Not in cpuinfo: cmpxchg16b, sahf
# Missing cpu_flags: lahf
_GOAMD64_V2=(popcnt sse3 sse4_1 sse4_2 ssse3)
# Not in cpuinfo: lzcnt
# Missing cpu_flags: bmi1, bmi2, movbe, osxsave
_GOAMD64_V3=(avx avx2 f16c fma3)
# According to https://en.wikichip.org/wiki/x86/avx-512 ,
#  all cpus with avx512f have avx512cd
#  all cpus with avx512dq, avx512vl have avx512bw
_GOAMD64_V4=(avx512f avx512dq avx512vl)

# @FUNCTION: _go-microarch_get_all_uses
# @USAGE: <arch> <flags...>
# @RETURN: USE flags with space delimited
# @INTERNAL
_go-microarch_get_all_uses() {
	[[ ${#} -ge 2 ]] || die "${FUNCNAME} requires at least 2 arguments"

	local arch=${1}
	local first=${2}
	shift 2
	echo -n "${first/#/cpu_flags_${arch}_}"

	for i in "${@}"; do
		echo -n " ${i/#/cpu_flags_${arch}_}"
	done
}

IUSE=$(_go-microarch_get_all_uses x86 "${_GOAMD64_V2[@]}" \
	"${_GOAMD64_V3[@]}" "${_GOAMD64_V4[@]}")

# @FUNCTION: _go-microarch_use_all
# @USAGE: <arch> <flags...>
# @INTERNAL
# @DESCRIPTION:
# Check if all specified arch-flags are all enabled.
_go-microarch_use_all() {
	for i in $(_go-microarch_get_all_uses "${@}"); do
		if ! use "${i}"; then
			return 1
		fi
	done

	return 0
}

# @FUNCTION: go-microarch_setenv
# @DESCRIPTION:
# Set microarchitecture environment variables
go-microarch_setenv() {
	GOAMD64=v1
	if _go-microarch_use_all x86 "${_GOAMD64_V2[@]}"; then
		GOAMD64=v2
	fi
	if _go-microarch_use_all x86 "${_GOAMD64_V3[@]}"; then
		GOAMD64=v3
	fi
	if _go-microarch_use_all x86 "${_GOAMD64_V4[@]}"; then
		GOAMD64=v4
	fi
	export GOAMD64
	einfo "Setting GOAMD64=${GOAMD64}"
}

fi
