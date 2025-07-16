# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit linux-info udev systemd

DESCRIPTION="Userspace Linux Integration Services for guests of Hyper-V"
HOMEPAGE="https://www.kernel.org"
SRC_URI="https://www.kernel.org/pub/linux/kernel/v$(ver_cut 1).x/linux-${PV}.tar.xz"

S="${WORKDIR}/linux-${PV}/tools/hv"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

IUSE="systemd"

CONFIG_CHECK="~PARAVIRT_SPINLOCKS ~ACPI ~VSOCKETS ~HYPERV_VSOCKETS
	~PCI ~PCI_MSI ~PCI_HYPERV ~SCSI_FC_ATTRS ~HYPERV_STORAGE ~HYPERV_NET
	~HYPERV_KEYBOARD ~DRM_HYPERV ~HID_HYPERV_MOUSE ~UIO_HV_GENERIC
	~HYPERV ~HYPERV_UTILS ~HYPERV_BALLOON"

src_unpack() {
	paths=("tools/hv" "tools/scripts" "tools/build")

	gtar -xf "${DISTDIR}/${A}" -- "${paths[@]/#/linux-${PV}/}"
}

src_prepare() {
	eapply -p3 "${FILESDIR}/${PN}-implement-gentoo-specific.patch"

	default
}

src_install() {
	default

	rmdir "${ED}"/var/lib
	rm "${ED}"/usr/libexec/hypervkvpd/hv_set_ifconfig

	if use systemd; then
		udev_dorules "${FILESDIR}"/90-hyperv-daemons.rules
		systemd_dounit "${FILESDIR}"/hypervfcopyd.service
		systemd_dounit "${FILESDIR}"/hypervkvpd.service
		systemd_dounit "${FILESDIR}"/hypervvssd.service
	fi
}
