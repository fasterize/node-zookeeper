#!/bin/bash

ROOT=`pwd`
BUILD=$ROOT/build/zk
BUILD_TMP=$BUILD/tmp
PLATFORM=`uname`
ZK_VERSION=3.4.6
ZK=zookeeper-$ZK_VERSION
ZK_FILE=/$BUILD_TMP/$ZK.tar.gz
ZK_URL=http://jenkins.fasterize.com/warp/$ZK.tar.gz

download_source() {
    if [ ! -e "$ZK_FILE" ] ; then
        echo "Downloading $ZK from $ZK_URL"
        curl --silent --output $ZK_FILE $ZK_URL || wget $ZK_URL -O $ZK_FILE
        if [ $? != 0 ] ; then
            echo "Unable to download zookeeper library"
            return 1
        fi
    fi

    # Check that the file is not corrupted
    tar -ztf $ZK_FILE > /dev/null
}

if [ "$PLATFORM" != "SunOS" ]; then
    if [ -e "$BUILD/lib/libzookeeper_st.la" ]; then
        echo "ZooKeeper has already been built"
        exit 0
    fi

    mkdir -p $BUILD_TMP

    RETRIES=5
    while [ $RETRIES -gt 0 ]
    do
      download_source
      if [ $? -eq 0 ]; then
          break
      else
          # Delete the file so it will be re-downloaded
          rm $ZK_FILE
      fi
      let "RETRIES-=1"
    done

    cd $BUILD_TMP

    tar -zxf $ZK_FILE

    PATCH_URL=https://issues.apache.org/jira/secure/attachment/12673210/ZOOKEEPER-2049.noprefix.branch-3.4.patch
    PATCH_FILE=/$BUILD_TMP/branch-3.4.patch
    echo "Downloading yosemite patch"
    curl --silent --output $PATCH_FILE $PATCH_URL || wget $PATCH_URL -O $PATCH_FILE
    if [ $? != 0 ] ; then
        echo "Unable to download yosemite patch"
        exit 1
    fi
    echo "Applying patch"
    (cd $ZK && patch -p0 < $PATCH_FILE)
    if [ $? != 0 ] ; then
            echo "Unable to patch the ZooKeeper source"
            exit 1
    fi


    cd $ZK/src/c && \
    ./configure \
        --without-syncapi \
        --enable-static \
        --disable-shared \
        --with-pic \
        --libdir=$BUILD/lib \
        --prefix=$BUILD && \
        make && \
        make install
    if [ $? != 0 ] ; then
            echo "Unable to build zookeeper library"
            exit 1
    fi
    cd $ROOT

    # At this point, the binaries have been built and copied
    # into the --prefix directory, so the temp files from the build
    # can be cleaned up
    rm -Rf $BUILD_TMP
else
    if [ `uname -v` =~ "joyent_.*" ] ; then
        pkgin list | grep zookeeper-client-$ZK_VERSION
        if [ $? != 0] ; then
            echo "You must install zookeeper before installing this module. Try:"
            echo "pkgin install zookeeper-client-$ZK_VERSION"
            exit 1
        fi
    fi
fi
