#!/usr/bin/env bats

@test "rpi-init will die if not config file ist given" {
  run ../rpi-init
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: configfile not set" ]
}

@test "rpi-init will die if basedir is set but does not exist" {
  somedir=`mktemp -d`
  run ../rpi-init $somedir/someNotExistingSubDirectory
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: configfile not readable" ]
  rmdir "$somedir"
}

@test "rpi-init will die if no basedir entry in configfile" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  run ../rpi-init $somedir/configfile
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no BASEDIR entry found in config" ]
  rm $somedir/configfile
  rmdir "$somedir"
}

@test "rpi-init will die if no download-url entry in configfile" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  echo "BASEDIR=$somedir" >>$somedir/configfile
  run ../rpi-init $somedir/configfile
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no DOWNLOAD_URL entry found in config" ]
  rm $somedir/configfile
  rmdir "$somedir"
}

@test "rpi-init will die if no md5sum entry in configfile" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  echo "BASEDIR=$somedir" >>$somedir/configfile
  echo "DOWNLOAD_URL=http://some.download.url" >>$somedir/configfile
  run ../rpi-init $somedir/configfile
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: no MD5SUM entry found in config" ]
  rm $somedir/configfile
  rmdir "$somedir"
}

@test "rpi-init will not download if md5sum matches" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  echo "BASEDIR=$somedir" >>$somedir/configfile
  echo "DOWNLOAD_URL=http://some.download.url/somefile.zip" >>$somedir/configfile
  mkdir "$somedir/download"
  echo "not really a zip file but that does not matter" > $somedir/download/somefile.zip
  MD5SUM=`md5sum $somedir/download/somefile.zip | cut -d' ' -f1`
  echo "MD5SUM=$MD5SUM" >>$somedir/configfile

  run ../rpi-init $somedir/configfile
  [ "$status" -eq 0 ]

  rm $somedir/download/somefile.zip
  rm $somedir/configfile
  rmdir "$somedir/download"
  rmdir "$somedir/images"
  rmdir "$somedir"
}

@test "rpi-init will download if md5sum mismatch" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  echo "BASEDIR=$somedir" >>$somedir/configfile
  echo "DOWNLOAD_URL=http://some.download.url/somefile.zip" >>$somedir/configfile
  mkdir "$somedir/download"
  echo "some_con..." >$somedir/download/somefile.zip
  echo "some_content" >$somedir/expected_content
  MD5SUM=`md5sum $somedir/expected_content | cut -d' ' -f1`
  echo "MD5SUM=$MD5SUM" >>$somedir/configfile

  load helpers/mocks/stub
  stub wget "${_WGET_ARGS} : mv $somedir/expected_content $somedir/download/somefile.zip"
  stub unzip "${_UNZIP_ARGS} : echo 0"

  run ../rpi-init $somedir/configfile
  [ "$status" -eq 0 ]

  rm $somedir/download/somefile.zip
  rm $somedir/configfile
  rmdir "$somedir/download"
  rmdir "$somedir/images"
  rmdir "$somedir"
}

@test "rpi-init will fail if md5sum mismatch after download" {
  somedir=`mktemp -d`
  touch $somedir/configfile
  echo "BASEDIR=$somedir" >>$somedir/configfile
  echo "DOWNLOAD_URL=http://some.download.url/somefile.zip" >>$somedir/configfile
  mkdir "$somedir/download"
  echo "not really a zip file but that does not matter" > $somedir/download/somefile.zip
  echo "MD5SUM=some_not_matching_md5sum" >>$somedir/configfile

  load helpers/mocks/stub
  stub wget "${_WGET_ARGS}: echo"

  run ../rpi-init $somedir/configfile
  [ "$status" -eq 1 ]
  # [ "$output" = "ERROR: md5sum mismatch" ]

  rm $somedir/download/somefile.zip
  rm $somedir/configfile
  rmdir "$somedir/download"
  rmdir "$somedir"
}


@test "rpi-init will unzip exisiting zip files to image directory" {
  somedir=`mktemp -d`
  echo "BASEDIR=$somedir" >>$somedir/configfile
  DOWNLOAD_URL="https://local.invalid/pathX/pathY/content.zip"
  
  # create a small test zip
  mkdir "$somedir/zip"
  echo "foo" >$somedir/zip/bar
  mkdir "$somedir/download"
  (cd "$somedir/zip" && zip -qq -r "$somedir/download/content.zip" *)
  rm -rf "$somedir/zip"
  MD5SUM=`md5sum $somedir/download/content.zip | cut -d' ' -f1`
  echo "DOWNLOAD_URL=$DOWNLOAD_URL" >>$somedir/configfile
  echo "MD5SUM=$MD5SUM" >>$somedir/configfile
  
  run ../rpi-init $somedir/configfile
  [ "$status" -eq 0 ]
  [ "`echo $somedir/images/*`" == "$somedir/images/bar" ]
  [ "`cat $somedir/images/bar`" == "foo" ]
  rm $somedir/images/bar
  rmdir $somedir/images
  rm "$somedir/download/content.zip"
  rmdir "$somedir/download"
  rm $somedir/configfile
  rmdir "$somedir"
}

@test "rpi-init will overwrite existing files" {
  somedir=`mktemp -d`
  echo "BASEDIR=$somedir" >>$somedir/configfile
  DOWNLOAD_URL="https://local.invalid/pathX/pathY/content.zip"
  
  # create a small test zip
  mkdir "$somedir/zip"
  echo "foo" >$somedir/zip/bar
  mkdir "$somedir/download"
  (cd "$somedir/zip" && zip -qq -r "$somedir/download/content.zip" *)
  rm -rf "$somedir/zip"
  MD5SUM=`md5sum $somedir/download/content.zip | cut -d' ' -f1`
  echo "DOWNLOAD_URL=$DOWNLOAD_URL" >>$somedir/configfile
  echo "MD5SUM=$MD5SUM" >>$somedir/configfile
  
  run ../rpi-init $somedir/configfile
  echo "newContent that should be overwritten when unzipping again" > $somedir/images/bar

  run ../rpi-init $somedir/configfile
  [ "$status" -eq 0 ]
  [ "`echo $somedir/images/*`" == "$somedir/images/bar" ]
  [ "`cat $somedir/images/bar`" == "foo" ]
  rm $somedir/images/bar
  rmdir $somedir/images
  rm "$somedir/download/content.zip"
  rmdir "$somedir/download"
  rm $somedir/configfile
  rmdir "$somedir"
}

#########################
### integration tests ###
#########################

### TODO Add a test that checks if md5sum won't fail if download file not already there

@test "rpi-init will download on md5sum mismatch" {
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
  echo "MD5SUM=someInvalidMd5Sum" >>$somedir/configfile

  run ../rpi-init $somedir/configfile
  [ "$status" -eq 0 ]
  [ "5753bcb74ead5219628cd8622410f9ef" = "`md5sum $ZIPFILE | cut -d' ' -f1`" ]

  rm $somedir/configfile
  rm "$somedir/download/$ZIPFILE_NAME"
  rmdir "$somedir/download"
  rmdir "$somedir/images"
  rmdir "$somedir"
}
