#!/usr/bin/env bats

@test "rpi-mount will die if not config file ist given" {
  run ../rpi-mount
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: configfile not set" ]
}

@test "rpi-mount will die if basedir is set but does not exist" {
  somedir=`mktemp -d`
  run ../rpi-mount $somedir/someNotExistingSubDirectory
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: configfile not readable" ]
  rmdir "$somedir"
}

@test "rpi-mount will die if no basedir entry in configfile" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  run ../rpi-mount $somedir/configfile
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no BASEDIR entry found in config" ]
  rm $somedir/configfile
  rmdir "$somedir"
}

@test "rpi-mount will die if images directory does not exist" {
  somedir=`mktemp -d`
  echo "BASEDIR=$somedir" >>$somedir/configfile
  run ../rpi-mount $somedir/configfile
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no images directory found" ]
  rm $somedir/configfile
  rmdir "$somedir"
}

#########################
### integration tests ###
#########################

@test "rpi-mount will mount an existing image file" {
  skip "must not unzip into /tmp (RAM)"

  INTEGRATION_DIR="/vagrant/workdir"
  DOWNLOAD_URL="https://downloads.raspberrypi.org/raspbian/images/raspbian-2017-03-03/2017-03-02-raspbian-jessie.zip"
  ZIPFILE_NAME=`basename $DOWNLOAD_URL`

  somedir=`mktemp -d`
  touch $somedir/configfile
  mkdir "$somedir/download"
  ln -sf "$INTEGRATION_DIR/$ZIPFILE_NAME" "$somedir/download"

  echo "BASEDIR=$somedir" >>$somedir/configfile
  echo "DOWNLOAD_URL=$DOWNLOAD_URL" >>$somedir/configfile
  echo "MD5SUM=5753bcb74ead5219628cd8622410f9ef" >>$somedir/configfile

  ../rpi-init $somedir/configfile

  run ../rpi-mount $somedir/configfile
  [ "$status" -eq 0 ]
  [ -r "$somedir/mount/img_root/boot/kernel.img" ]

  ../rpi-umount $somedir/configfile
  rm $somedir/images/`basename -s .zip $DOWNLOAD_URL`.img
  rmdir $somedir/images
  rmdir $somedir/mount/img_root
  rmdir $somedir/mount

  rm $somedir/download/ZIPFILE_NAME
  rmdir $somedir/download

  rm $somedir/configfile
  rmdir "$somedir"
}

