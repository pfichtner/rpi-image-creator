die() {
    echo 1>&2 ERROR: "$*"
    exit 1
}

dieIfEntryIsMissing() {
    eval "VALUE=\$$1"
    [ -n "$VALUE" ] || die "no $1 entry found in config"
}

_umount() {
    grep -q "$1" /proc/self/mounts && (umount -f "$1" || die "Could not umount $1")
}


_which() {
    command -v $1 || die "Unknown command $1"
}


md5() {
  md5sum $1 | cut -d' ' -f1
}

copyToPi() {
       	[ -r $1 ] && cp $1 $BASEDIR/mount/img_root/$1 || die "Could not copy $1"
}

rpi_init() {
  dieIfEntryIsMissing DOWNLOAD_URL
  dieIfEntryIsMissing MD5SUM

  [ -d $BASEDIR/download ] || mkdir $BASEDIR/download
  ZIPFILE=$BASEDIR/download/`basename $DOWNLOAD_URL`

  _which md5sum >/dev/null
  if [ "$MD5SUM" != "`md5 $ZIPFILE`" ]; then
    _which wget >/dev/null
    wget --quiet -c -O $ZIPFILE $DOWNLOAD_URL
    [ "$MD5SUM" != "`md5 $ZIPFILE`" ] && die "md5sum mismatch"
  fi

  [ -d "$BASEDIR/images" ] || mkdir -p "$BASEDIR/images"
  unzip -o -qq -d "$BASEDIR/images" "$ZIPFILE"
}

rpi_mount() {
  [ -d "$BASEDIR/images" ] || die "no images directory found"
  [ -d "$BASEDIR/mount" ] || mkdir -p "$BASEDIR/mount"

  _which kpartx >/dev/null
  kpartx=`kpartx -asv $BASEDIR/images/*.img` || die "Could not setup loop-back access to $BASEDIR/images/*.img"
  img_boot_dev=`echo "$kpartx" | grep -o 'loop.p.' | head -1 | tail -1`
  img_root_dev=`echo "$kpartx" | grep -o 'loop.p.' | head -2 | tail -1`

  test "$img_boot_dev" -a "$img_root_dev" || die "Could not extract boot and root loop device from kpartx output: $NL$kpartx"
  img_boot_dev=/dev/mapper/$img_boot_dev
  img_root_dev=/dev/mapper/$img_root_dev
  mkdir -p $BASEDIR/mount/img_root
  mountpoint -q $BASEDIR/mount/img_root || mount -t ext4 $img_root_dev $BASEDIR/mount/img_root || die "Could not mount $img_root_dev $BASEDIR/mount/img_root"
  mkdir -p $BASEDIR/mount/img_root/boot || die "Could not mkdir $BASEDIR/mount/img_root/boot"
  mountpoint -q BASEDIR/mount/img_root/boot || mount -t vfat $img_boot_dev $BASEDIR/mount/img_root/boot || die "Could not mount $img_boot_dev $BASEDIR/mount/img_root/boot"
  cp -a "`_which qemu-arm-static`" $BASEDIR/mount/img_root/usr/bin/ || die "Could not copy qemu-arm-static"
}

rpi_chroot_setup() {
  [ -d "$BASEDIR/mount" ] || die "no mount directory found"

  chroot $BASEDIR/mount/img_root date >/dev/null 2>&1 || die "Could not chroot date"

  mountpoint -q $BASEDIR/mount/img_root/dev/pts || mount -t devpts devpts -o noexec,nosuid,gid=5,mode=620 $BASEDIR/mount/img_root/dev/pts || die "Could not mount /dev/pts"
  mountpoint -q $BASEDIR/mount/img_root/proc || mount -t proc proc $BASEDIR/mount/img_root/proc || die "Could not mount /proc"
  mountpoint -q $BASEDIR/mount/img_root/run || mount -t tmpfs -o mode=1777 none $BASEDIR/mount/img_root/run || "Could not mount /run"
}

rpi_chroot_teardown() {
  _umount $BASEDIR/mount/img_root/proc
  _umount $BASEDIR/mount/img_root/sys
  _umount $BASEDIR/mount/img_root/run
  _umount $BASEDIR/mount/img_root/dev/pts
}

rpi_mksdcard() {
  [ -n "$DEST_DEVICE" ] || die "no DEST_DEVICE entry found in config"

  test -b "$DEST_DEVICE" || die "Must give block device with SD Card as first parameter"

  _umount $BASEDIR/mount/img_root/{proc,sys,run,dev/pts}
  umount -f ${DEST_DEVICE}* >/dev/null 2>&1 || :
  dd if=/dev/zero of=$DEST_DEVICE bs=1M count=100 status=none || die "Could not wipe SD card in $DEST_DEVICE"
  parted -a minimal -s $DEST_DEVICE mklabel msdos mkpart primary fat32 0mb 64mb mkpart primary ext2 64mb 100% set 1 boot on || die "Could not parted $DEST_DEVICE"
  if [ -e ${DEST_DEVICE}p1 ] ; then sd_boot_dev=${DEST_DEVICE}p1 ; elif [ -e ${DEST_DEVICE}1 ] ; then sd_boot_dev=${DEST_DEVICE}1 ; else die "Could not find sd-card partition 1" ; fi
  if [ -e ${DEST_DEVICE}p2 ] ; then sd_root_dev=${DEST_DEVICE}p2 ; elif [ -e ${DEST_DEVICE}2 ] ; then sd_root_dev=${DEST_DEVICE}2 ; else die "Could not find sd-card partition 2" ; fi
  echo "This is the boot partition of a Raspbian image intended for a Raspberry Pi" | mkfs.vfat >/dev/null -n RASPBIAN_BOOT -F 32 $sd_boot_dev -m -  || die "Could not create boot partition"
  mkfs.ext4 -q -L raspbian_root -E discard $sd_root_dev || die "Could not create root partition"
  tune2fs >/dev/null $sd_root_dev -o journal_data,discard || die "Could not tune2fs $sd_root_dev"

  mkdir -p $BASEDIR/mount/sd_root || die "Could not mkdir root"
  mountpoint -q $BASEDIR/mount/sd_root || mount -o data=writeback,nobarrier -t ext4 $sd_root_dev $BASEDIR/mount/sd_root || die "Could not mount $sd_root_dev $BASEDIR/mount/sd_root"
  mkdir -p $BASEDIR/mount/sd_root/boot || die "Could not mkdir boot"
  mountpoint -q $BASEDIR/mount/sd_root/boot || mount -t vfat $sd_boot_dev $BASEDIR/mount/sd_root/boot || die "Could not mount $sd_boot_dev $BASEDIR/mount/sd_root/boot"

  cp -a $BASEDIR/mount/img_root/* $BASEDIR/mount/sd_root/ || die "Could not copy root fs"

  umount $sd_boot_dev
  umount $sd_root_dev
}

rpi_umount() {
  _umount $BASEDIR/mount/img_root/boot
  _umount $BASEDIR/mount/img_root
}

export LANG="C" LANGUAGE="C" LC_ALL="C.UTF-8"

