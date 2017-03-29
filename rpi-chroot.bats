#!/usr/bin/env bats

@test "rpi-chroot will die if not config file ist given" {
  run ./rpi-chroot
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: configfile not set" ]
}

@test "rpi-chroot will die if basedir is set but does not exist" {
  somedir=`mktemp -d`

  run ./rpi-chroot $somedir/someNotExistingSubDirectory

  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: configfile not readable" ]

  rmdir "$somedir"
}

@test "rpi-chroot will die if no basedir entry in configfile" {
  somedir=`mktemp -d`
  touch $somedir/configfile

  run ./rpi-chroot $somedir/configfile

  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no BASEDIR entry found in config" ]

  rm $somedir/configfile
  rmdir "$somedir"
}

@test "rpi-chroot will die if mount directory does not exist" {
  somedir=`mktemp -d`
  echo "BASEDIR=$somedir" >>$somedir/configfile

  run ./rpi-chroot $somedir/configfile

  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no mount directory found" ]

  rm $somedir/configfile
  rmdir "$somedir"
}

@test "rpi-chroot will die if mount directory is empty (/bin/date does not exist)" {
  somedir=`mktemp -d`
  echo "BASEDIR=$somedir" >>$somedir/configfile
  mkdir $somedir/mount

  run ./rpi-chroot $somedir/configfile

  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: Could not chroot date" ]

  rmdir $somedir/mount
  rm $somedir/configfile
  rmdir "$somedir"
}

