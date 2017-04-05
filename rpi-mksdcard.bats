#!/usr/bin/env bats

@test "rpi-mksdcard will die if not config file ist given" {
  run ./rpi-mksdcard
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: configfile not set" ]
}

@test "rpi-mksdcard will die if basedir is set but does not exist" {
  somedir=`mktemp -d`
  run ./rpi-mksdcard $somedir/someNotExistingSubDirectory
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: configfile not readable" ]
  rmdir "$somedir"
}

@test "rpi-mksdcard will die if no basedir entry in configfile" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  run ./rpi-mksdcard $somedir/configfile
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no BASEDIR entry found in config" ]
  rm $somedir/configfile
  rmdir "$somedir"
}

@test "rpi-mksdcard will die if no dest_device entry in configfile" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  echo "BASEDIR=$somedir" >>$somedir/configfile
  run ./rpi-mksdcard $somedir/configfile
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no DEST_DEVICE entry found in config" ]
  rm $somedir/configfile
  rmdir "$somedir"
}

prepare_sdcard() {
  # travis-ci doesn't support loop devices, so skip tests if losetup -f cannot detect a free loop device
  if [ "$CI" = "true" -a "$TRAVIS" = "true" ]; then
    losetup -f || skip "No loop device available"
  fi

  size="$1"
  dd if=/dev/zero bs=1M count=$size of=$somedir/aBlockDevice
  loopDevice=`losetup -f`
  losetup "$loopDevice" "$somedir/aBlockDevice"
  echo "$loopDevice"
}

free_sdcard() {
  loopDevice="$1"
  losetup -d "$loopDevice"
}

@test "rpi-mksdcard fails if the loopDevice has less then 100 MB" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  echo "BASEDIR=$somedir" >>$somedir/configfile
  loopDevice=`prepare_sdcard 99`
  echo "DEST_DEVICE=$loopDevice" >>$somedir/configfile

  run ./rpi-mksdcard $somedir/configfile
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "dd: error writing '$loopDevice': No space left on device" ]
  [ "${lines[1]}" = "ERROR: Could not wipe SD card in $loopDevice" ]

  free_sdcard "$loopDevice"
  rm "$somedir/aBlockDevice"
  rm "$somedir/configfile"
  rmdir "$somedir"
}


@test "rpi-mksdcard will create partitions and copy content" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  echo "BASEDIR=$somedir" >>$somedir/configfile
  loopDevice=`prepare_sdcard 100`
  echo "DEST_DEVICE=$loopDevice" >>$somedir/configfile
  
  # this is some internal (ok or not?): we know where rpi-mksdcard picks up its content to copy
  mkdir -p $somedir/mount/img_root/boot
  echo "some root content" >$somedir/mount/img_root/aRootFile.txt
  echo "some boot content" >$somedir/mount/img_root/boot/aRootFile.txt

  run ./rpi-mksdcard $somedir/configfile
  [ "$status" -eq 0 ]
  
  rm $somedir/mount/img_root/aRootFile.txt
  rm $somedir/mount/img_root/boot/aRootFile.txt
  rmdir $somedir/mount/img_root/boot
  rmdir $somedir/mount/img_root

  # created by rpi-mksdcard if not already there
  rmdir $somedir/mount/sd_root $somedir/mount

  ### we should add some assertions that check the content of $loopDevice

  free_sdcard "$loopDevice"
  rm "$somedir/aBlockDevice"
  rm "$somedir/configfile"
  rmdir "$somedir"
}

