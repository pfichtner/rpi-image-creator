#!/bin/sh

die() {
    echo 1>&2 ERROR: "$1"
    exit 1
}



# TODO this all has not to run inside chroot!
rm -f /etc/init.d/apply_noobs_os_config /etc/rc2.d/S01apply_noobs_os_config || die "Could not remove noobs stuff"
rm -f /etc/profile.d/raspi-config.sh || die "Could not remove raspi-config first-boot stuff"

sed -i -e 's/^#\(FSCKFIX=\)no/\1yes/' /etc/default/rcS || die "Could not enable automatic filesystem fix on boot"
echo "localhost" >/etc/hostname || die "Could not set hostname to localhost"
echo "unset old_host_name # this will make the system always set the hostname from DHCP" >/etc/dhcp/dhclient-enter-hooks.d/unset_old_hostname || die "Could not apply fix http://blog.schlomo.schapiro.org/2013/11/setting-hostname-from-dhcp-in-debian.html"
sed -i -e 's/^/#/' /etc/ld.so.preload || die "Could not disable ld.so.preload"
















apt-get -qq update || die "Could not update package sources"
apt-get -qq dist-upgrade || die "Could not upgrade system"

service rsyslog stop &>/dev/null || : # some packages start syslog

