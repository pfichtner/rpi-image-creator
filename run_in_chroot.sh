#!/bin/sh

die() {
    echo 1>&2 ERROR: ""
    exit 1
}

rm -f /etc/init.d/apply_noobs_os_config /etc/rc2.d/S01apply_noobs_os_config || die "Could not remove noobs stuff"
rm -f /etc/profile.d/raspi-config.sh || die "Could not remove raspi-config first-boot stuff"

sed -i -e '/RPICFG_TO_DISABLE/d' -e '/RPICFG_TO_ENABLE/s/^#//' -e '/RPICFG_TO_ENABLE/s/ #.*$//' /etc/inittab || die "Could not remove raspi-config autorun from inittab"
sed -i -e 's/^#\(FSCKFIX=\)no/\1yes/' /etc/default/rcS || die "Could not enable automatic filesystem fix on boot"
for f in /etc/default/{keyboard,console-setup} /etc/{resolv.conf,localtime} ; do
    [ -r "" ] && cp "" "/" || die "Could not copy "
done
echo "localhost" >/etc/hostname || die "Could not set hostname to localhost"
echo "unset old_host_name # this will make the system always set the hostname from DHCP"     >/etc/dhcp/dhclient-enter-hooks.d/unset_old_hostname || die "Could not apply fix http://blog.schlomo.schapiro.org/2013/11/setting-hostname-from-dhcp-in-debian.html"
sed -i -e 's/^/#/' /etc/ld.so.preload || die "Could not disable ld.so.preload"

