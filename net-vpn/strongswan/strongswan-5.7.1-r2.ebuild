# Copyright 1999-2018 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"
inherit linux-info systemd

DESCRIPTION="IPsec-based VPN solution, supporting IKEv1/IKEv2 and MOBIKE"
HOMEPAGE="https://www.strongswan.org/"
SRC_URI="https://download.strongswan.org/${P}.tar.bz2"

LICENSE="GPL-2 RSA DES"
SLOT="0"
KEYWORDS="~amd64 ~arm ~ppc ~ppc64 ~x86"
IUSE="+caps debug +non-root selinux"

# crypto plugins
# HIDDEN: +fips-prf, -md4, mgf1, +nonce
# DIFF_DEF: -des -md5 +openssl
STRONGSWAN_PLUGINS_STD="aes cmac curve25519 hmac random rc2 sha1 sha2 xcbc"
STRONGSWAN_PLUGINS_OPT="bliss blowfish ccm chapoly ctr des gcm md5 newhope ntru padlock rdrand aesni sha3"
IUSE+=" af-alg botan gcrypt +gmp +openssl"
# encoding/decoding plugins are all hidden and enabled by default
# fetcher/resolver plugins
# HIDDEN: -winhttp
STRONGSWAN_PLUGINS_OPT+=" files"
IUSE+=" curl ldap soup unbound"
# database plugins
IUSE+=" mysql sqlite"
# authentication/credential plugins
# HIDDEN: -keychain, xauth-eap
STRONGSWAN_PLUGINS_STD+=" constraints revocation xauth-generic"
STRONGSWAN_PLUGINS_OPT+=" addrblock acert agent coupling dnscert ext-auth ipseckey tpm whitelist xauth-noauth"
IUSE+=" eap-simaka eap pkcs11 pam"
# kernel interfaces / sockets
# HIDDEN: +kernel-netlink, -kernel-pfroute, -kernel-iph, -kernel-wfp, -socket-win
STRONGSWAN_PLUGINS_STD+=" socket-default"
STRONGSWAN_PLUGINS_OPT+=" kernel-pfkey kernel-libipsec socket-dynamic"
# configuration/control plugins are ignored
# attribute provider/consumer plugins
# HIDDEN: -android-dns, attr-sql, -osx-attr
STRONGSWAN_PLUGINS_STD+=" attr resolve"
STRONGSWAN_PLUGINS_OPT+=" dhcp p-cscf unity"
# TNC modules/plugins
IUSE+=" tnc"
# misc plugins
# HIDDEN: -android-log, counters, load-tester, test-vectors
STRONGSWAN_PLUGINS_STD+=" updown"
STRONGSWAN_PLUGINS_OPT+=" bypass-lan certexpire connmark forecast duplicheck error-notify farp ha led lookip radattr save-keys systime-fix"

# program/components
# HIDDEN: fast, -fuzzing, libipsec, -manager, -medcli, -medsrv, +scripts, -svc, -tkm
# DIFF_DEF: -scripts
IUSE+=" aikgen +charon cmd conftest networkmanager +pki +scepclient systemd +swanctl"
# optional features are ignored

for mod in $STRONGSWAN_PLUGINS_STD; do
	IUSE+=" +strongswan_plugins_${mod}"
done

for mod in $STRONGSWAN_PLUGINS_OPT; do
	IUSE+=" strongswan_plugins_${mod}"
done

REQUIRED_USE="
	eap-simaka? (
		gmp
		|| ( openssl strongswan_plugins_sha1 )
	)"

COMMON_DEPEND="non-root? (
		acct-user/ipsec
		acct-group/ipsec
	)
	gmp? ( >=dev-libs/gmp-4.1.4:= )
	ldap? ( net-nds/openldap )
	curl? ( net-misc/curl )
	unbound? ( net-dns/unbound:= net-libs/ldns )
	soup? ( net-libs/libsoup:2.4 )
	tnc? ( dev-libs/libxml2 dev-libs/json-c )
	systemd? ( >=sys-apps/systemd-209 )
	aikgen? ( app-crypt/trousers )
	mysql? ( dev-db/mysql-connector-c:= )
	sqlite? ( >=dev-db/sqlite-3.3.1 )
	openssl? ( >=dev-libs/openssl-0.9.8:=[-bindist] )
	gcrypt? ( dev-libs/libgcrypt:0 )
	botan? ( dev-libs/botan:2 )
	eap-simaka? ( sys-apps/pcsc-lite )
	networkmanager? ( net-misc/networkmanager dev-libs/glib:2 )
	pam? ( sys-libs/pam )
	strongswan_plugins_connmark? ( net-firewall/iptables:= )
	strongswan_plugins_forecast? ( net-firewall/iptables:= )
	caps? ( sys-libs/libcap )"

DEPEND="${COMMON_DEPEND}
	virtual/linux-sources
	sys-kernel/linux-headers"
RDEPEND="${COMMON_DEPEND}
	virtual/logger
	sys-apps/iproute2
	!net-misc/openswan
	!net-vpn/libreswan
	selinux? ( sec-policy/selinux-ipsec )"

UGID="ipsec"

pkg_setup() {
	linux-info_pkg_setup

	elog "Linux kernel version: ${KV_FULL}"

	if ! kernel_is -ge 2 6 16; then
		eerror
		eerror "This ebuild currently only supports ${PN} with the"
		eerror "native Linux 2.6 IPsec stack on kernels >= 2.6.16."
		eerror
	fi

	if kernel_is -lt 2 6 34; then
		ewarn
		ewarn "IMPORTANT KERNEL NOTES: Please read carefully..."
		ewarn

		if kernel_is -lt 2 6 29; then
			ewarn "[ < 2.6.29 ] Due to a missing kernel feature, you have to"
			ewarn "include all required IPv6 modules even if you just intend"
			ewarn "to run on IPv4 only."
			ewarn
			ewarn "This has been fixed with kernels >= 2.6.29."
			ewarn
		fi

		if kernel_is -lt 2 6 33; then
			ewarn "[ < 2.6.33 ] Kernels prior to 2.6.33 include a non-standards"
			ewarn "compliant implementation for SHA-2 HMAC support in ESP and"
			ewarn "miss SHA384 and SHA512 HMAC support altogether."
			ewarn
			ewarn "If you need any of those features, please use kernel >= 2.6.33."
			ewarn
		fi

		if kernel_is -lt 2 6 34; then
			ewarn "[ < 2.6.34 ] Support for the AES-GMAC authentification-only"
			ewarn "ESP cipher is only included in kernels >= 2.6.34."
			ewarn
			ewarn "If you need it, please use kernel >= 2.6.34."
			ewarn
		fi
	fi
}

src_configure() {
	local myconf=""

	if use non-root; then
		myconf+=" --with-user=${UGID} --with-group=${UGID}"
	fi

	# If a user has already enabled db support, those plugins will
	# most likely be desired as well. Besides they don't impose new
	# dependencies and come at no cost (except for space).
	if use mysql || use sqlite; then
		myconf+=" --enable-attr-sql --enable-sql"
		if use eap-simaka; then
			myconf+=" --enable-eap-simaka-sql"
		fi
	fi

	# strongSwan builds and installs static libs by default which are
	# useless to the user (and to strongSwan for that matter) because no
	# header files or alike get installed... so disabling them is safe.
	if use pam && use eap; then
		myconf+=" --enable-eap-gtc"
	else
		myconf+=" --disable-eap-gtc"
	fi

	if use eap && use tnc; then
		myconf+=" --enable-eap-tnc"
	fi

	if use eap || use eap-simaka; then
		myconf+=" --enable-xauth-eap"
	fi

	for mod in $STRONGSWAN_PLUGINS_STD $STRONGSWAN_PLUGINS_OPT; do
		if use strongswan_plugins_${mod}; then
			myconf+=" --enable-${mod}"
		else
			myconf+=" --disable-${mod}"
		fi
	done

	econf \
		$(use_with caps capabilities libcap) \
		$(use_enable debug load-tester) \
		$(use_enable debug test-vectors) \
		$(use_enable debug bfd-backtraces) \
		$(use_enable debug integrity-test) \
		$(use_enable debug leak-detective) \
		$(use_enable debug lock-profiler) \
		$(use_enable af-alg) \
		$(use_enable botan) \
		$(use_enable gcrypt) \
		$(use_enable gmp) \
		$(use_enable openssl) \
		$(use_enable curl) \
		$(use_enable ldap) \
		$(use_enable soup) \
		$(use_enable unbound) \
		$(use_enable mysql) \
		$(use_enable sqlite) \
		$(use_enable eap-simaka eap-sim) \
		$(use_enable eap-simaka eap-sim-file) \
		$(use_enable eap-simaka eap-sim-pcsc) \
		$(use_enable eap-simaka eap-aka) \
		$(use_enable eap-simaka eap-aka-3gpp) \
		$(use_enable eap-simaka eap-aka-3gpp2) \
		$(use_enable eap-simaka eap-simaka-pseudonym) \
		$(use_enable eap-simaka eap-simaka-reauth) \
		$(use_enable eap eap-identity) \
		$(use_enable eap eap-md5) \
		$(use_enable eap eap-mschapv2) \
		$(use_enable eap eap-tls) \
		$(use_enable eap eap-ttls) \
		$(use_enable eap eap-peap) \
		$(use_enable eap eap-dynamic) \
		$(use_enable eap eap-radius) \
		$(use_enable pkcs11) \
		$(use_enable pam xauth-pam) \
		$(use_enable tnc imc-test) \
		$(use_enable tnc imv-test) \
		$(use_enable tnc imc-scanner) \
		$(use_enable tnc imv-scanner) \
		$(use_enable tnc imc-os) \
		$(use_enable tnc imv-os) \
		$(use_enable tnc imc-attestation) \
		$(use_enable tnc imv-attestation) \
		$(use_enable tnc imc-swima) \
		$(use_enable tnc imv-swima) \
		$(use_enable tnc imc-hcd) \
		$(use_enable tnc imv-hcd) \
		$(use_enable tnc tnc-ifmap) \
		$(use_enable tnc tnc-imc) \
		$(use_enable tnc tnc-imv) \
		$(use_enable tnc tnc-pdp) \
		$(use_enable tnc tnccs-11) \
		$(use_enable tnc tnccs-20) \
		$(use_enable tnc tnccs-dynamic) \
		$(use_enable aikgen) \
		$(use_enable charon) \
		$(use_enable cmd) \
		$(use_enable conftest) \
		$(use_enable networkmanager nm) \
		$(use_enable pki) \
		$(use_enable scepclient) \
		--disable-scripts \
		$(use_enable systemd) \
		--with-systemdsystemunitdir="$(systemd_get_systemunitdir)" \
		$(use_enable swanctl) \
		${myconf}
}

src_install() {
	emake DESTDIR="${D}" install

	doinitd "${FILESDIR}"/ipsec

	local dir_ugid
	if use non-root; then
		fowners ${UGID}:${UGID} \
			/etc/ipsec.conf \
			/etc/strongswan.conf

		dir_ugid="${UGID}"
	else
		dir_ugid="root"
	fi

	diropts -m 0750 -o ${dir_ugid} -g ${dir_ugid}
	dodir /etc/ipsec.d \
		/etc/ipsec.d/aacerts \
		/etc/ipsec.d/acerts \
		/etc/ipsec.d/cacerts \
		/etc/ipsec.d/certs \
		/etc/ipsec.d/crls \
		/etc/ipsec.d/ocspcerts \
		/etc/ipsec.d/private \
		/etc/ipsec.d/reqs

	dodoc NEWS README TODO || die

	# shared libs are used only internally and there are no static libs,
	# so it's safe to get rid of the .la files
	find "${D}" -name '*.la' -delete || die "Failed to remove .la files."
}

pkg_preinst() {
	has_version "<net-vpn/strongswan-4.3.6-r1"
	upgrade_from_leq_4_3_6=$(( !$? ))

	has_version "<net-vpn/strongswan-4.3.6-r1[-caps]"
	previous_4_3_6_with_caps=$(( !$? ))

	has_version "<net-vpn/strongswan-5.7.1-r1"
	upgrade_from_leq_5_7_1=$(( !$? ))
}

pkg_postinst() {
	if ! use botan && ! use gcrypt && ! use openssl; then
		elog
		elog "${PN} has been compiled without Botan, libgcrypt and OpenSSL support."
		elog "Please note that this might effect availability and speed of some"
		elog "cryptographic features. You are advised to enable the OpenSSL plugin."
	elif ! use botan && ! use openssl; then
		elog
		elog "${PN} has been compiled without Botan and OpenSSL plugin. This"
		elog "might effect availability and speed of some cryptographic features."
		elog "There will be no support for Elliptic Curve Cryptography"
		elog "(Diffie-Hellman groups 19-21, 25, 26) and ECDSA."
	fi

	if [[ $upgrade_from_leq_4_3_6 == 1 ]]; then
		chmod 0750 "${ROOT}"/etc/ipsec.d \
			"${ROOT}"/etc/ipsec.d/aacerts \
			"${ROOT}"/etc/ipsec.d/acerts \
			"${ROOT}"/etc/ipsec.d/cacerts \
			"${ROOT}"/etc/ipsec.d/certs \
			"${ROOT}"/etc/ipsec.d/crls \
			"${ROOT}"/etc/ipsec.d/ocspcerts \
			"${ROOT}"/etc/ipsec.d/private \
			"${ROOT}"/etc/ipsec.d/reqs

		ewarn
		ewarn "The default permissions for /etc/ipsec.d/* have been tightened for"
		ewarn "security reasons. Your system installed directories have been"
		ewarn "updated accordingly. Please check if necessary."
		ewarn

		if [[ $previous_4_3_6_with_caps == 1 ]]; then
			if ! use non-root; then
				ewarn
				ewarn "IMPORTANT: You previously had ${PN} installed without root"
				ewarn "privileges because it was implied by the 'caps' USE flag."
				ewarn "This has been changed. If you want ${PN} with user privileges,"
				ewarn "you have to re-emerge it with the 'non-root' USE flag enabled."
				ewarn
			fi
		fi
	fi
	if [[ $upgrade_from_leq_5_7_1 == 1 ]]; then
		elog
		elog "Starting from 5.7.1-r1, a lot of USE flags are added,"
		elog "and the following old USE flags are renamed:"
		elog "  constraints -> strongswan_plugins_constraints"
		elog "  dhcp -> strongswan_plugins_dhcp"
		elog "  farp -> strongswan_plugins_farp"
		elog "  strongswan_plugins_unbound -> unbound"
		elog "If you enabled/disabled either of those, you need to edit package.use ."
	fi
	if ! use caps && ! use non-root; then
		ewarn
		ewarn "You have decided to run ${PN} with root privileges and built it"
		ewarn "without support for POSIX capability dropping. It is generally"
		ewarn "strongly suggested that you reconsider- especially if you intend"
		ewarn "to run ${PN} as server with a public ip address."
		ewarn
		ewarn "You should re-emerge ${PN} with at least the 'caps' USE flag enabled."
		ewarn
	fi
	if use non-root; then
		elog
		elog "${PN} has been installed without superuser privileges (USE=non-root)."
		elog "This imposes a few limitations to the daemon 'charon'."
		elog
		elog "Please carefully read: http://wiki.strongswan.org/wiki/nonRoot"
		elog
		elog "If you need to specify a custom updown script to charon which"
		elog "requires superuser privileges, you can work around this limitation"
		elog "by using sudo to grant the user \"ipsec\" the appropriate rights."
		elog "For example (the default case):"
		elog "/etc/sudoers:"
		elog "  ipsec ALL=(ALL) NOPASSWD: SETENV: /usr/sbin/ipsec"
		elog "Under the specific connection block in /etc/ipsec.conf:"
		elog "  leftupdown=\"sudo -E ipsec _updown iptables\""
		elog
	fi
	elog
	elog "Make sure you have _all_ required kernel modules available including"
	elog "the appropriate cryptographic algorithms. A list is available at:"
	elog "  http://wiki.strongswan.org/projects/strongswan/wiki/KernelModules"
	elog
	elog "Notice that there are multiple plugins providing the same functionality."
	elog "e.g."
	elog "  Any of kernel-{libipsec,netlink,pfkey} provides 'IPsec' functionality."
	elog "  Any of aesni, botan, openssl, gcm + (aes/gcrypt)"
	elog "  provides 'AES-GCM' crypto."
	elog "The first loaded plugin which provides a functionality will be used"
	elog "for that functionality."
	elog "To adjust load priority of a plugin (or simply disable it), see:"
	elog "  https://wiki.strongswan.org/projects/strongswan/wiki/PluginLoad"
	elog
	elog "The up-to-date manual is available online at:"
	elog "  http://wiki.strongswan.org/"
	elog
}
