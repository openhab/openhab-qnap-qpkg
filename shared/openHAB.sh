#!/bin/bash

CONF=/etc/config/qpkg.conf
QPKG_HTTP_PORT=8090
QPKG_HTTPS_PORT=8444
QPKG_NAME="openHAB"
QPKG_ROOT=`/sbin/getcfg $QPKG_NAME Install_Path -f ${CONF}`
QPKG_JAVA=${QPKG_ROOT}/java
QPKG_DISTRIBUTION=${QPKG_ROOT}/distribution
QPKG_TMP=${QPKG_ROOT}/tmp
#QPKG_PIDFILE=${QPKG_ROOT}/${QPKG_NAME}.pid
QPKG_STDOUT=${QPKG_ROOT}/${QPKG_NAME}.stdout
QPKG_STDERR=${QPKG_ROOT}/${QPKG_NAME}.stderr
#QPKG_START=${QPKG_ROOT}/distribution/start.sh
QPKG_START=${QPKG_DISTRIBUTION}/runtime/bin/start
QPKG_STOP=${QPKG_DISTRIBUTION}/runtime/bin/stop
QPKG_STATUS=${QPKG_DISTRIBUTION}/runtime/bin/status
QPKG_CONSOLE=${QPKG_DISTRIBUTION}/start.sh
QPKG_SNAPSHOT_FLAVOUR=offline
QPKG_SNAPSHOT_VERSION=2.0.0

function downloadJavaCommon {
    echo "Please visit http://www.oracle.com/technetwork/java/javase/terms/license/index.html"
    echo "and read the licence carefully. While downloading and using Oracle Java here, you agree the licence automatically."
    read -p "Continue downloading Oracle Java (y/n)? " choice
    case "$choice" in
        y|Y )
            echo "Let's continue downloading Oracle Java..."
        ;;
        n|N )
            echo "Aborting download and installation..."
            exit 1
        ;;
        * )
            echo "Invalid input! Please rerun!"
            exit 1
        ;;
    esac
    if [ -f ${QPKG_ROOT}/jdk.tar.gz ]; then
        rm ${QPKG_ROOT}/jdk.tar.gz
    fi
    wget --show-progress \
         --no-check-certificate \
         --no-cookies \
         --header "Cookie: oraclelicense=accept-securebackup-cookie" \
         -O ${QPKG_ROOT}/jdk.tar.gz \
         $1
    current_sum=$(md5sum ${QPKG_ROOT}/jdk.tar.gz | awk '{print $1}')
    if [ x${current_sum} != x$2 ]; then
        echo "Download failed!"
        exit 1
    fi
    echo "Download was fine!"
    rm -rf ${QPKG_JAVA}
    mkdir -p ${QPKG_JAVA}
    tar --strip-components=1 \
        -xvzf \
        ${QPKG_ROOT}/jdk.tar.gz \
        --directory=${QPKG_JAVA}
    exit 0
}

function downloadJavaArm32 {
    downloadJavaCommon http://download.oracle.com/otn-pub/java/jdk/8u111-b14/jdk-8u111-linux-arm32-vfp-hflt.tar.gz e74f9808168fb41570ee727e8e3f3366
}

function downloadJavaArm64 {
    downloadJavaCommon http://download.oracle.com/otn-pub/java/jdk/8u111-b14/jdk-8u111-linux-arm64-vfp-hflt.tar.gz 2f428b30b713542e3ed48fb7668bcfe2
}

function downloadJavaI586 {
    downloadJavaCommon http://download.oracle.com/otn-pub/java/jdk/8u111-b14/jdk-8u111-linux-i586.tar.gz f3399a2c00560a8f5f9a652f7c67e493
}

function downloadJavaX64 {
    downloadJavaCommon http://download.oracle.com/otn-pub/java/jdk/8u111-b14/jdk-8u111-linux-x64.tar.gz 2d48badebe05c848cc3b4d6e0c53a457
}

function downloadAndExtractSnapshot {
    # Download snapshot
    if [ -f ${QPKG_ROOT}/openhab-SNAPSHOT.tar.gz ]; then
        rm ${QPKG_ROOT}/openhab-SNAPSHOT.tar.gz
    fi
    wget --show-progress \
        --no-check-certificate \
        -O ${QPKG_ROOT}/openhab-SNAPSHOT.tar.gz \
        https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-${QPKG_SNAPSHOT_FLAVOUR}/target/openhab-${QPKG_SNAPSHOT_FLAVOUR}-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz

    # Extract runtime for snapshot and clean up
    if [ -d ${QPKG_TMP} ]; then
        rm -rf ${QPKG_TMP}
    fi
    mkdir -p ${QPKG_TMP}
    tar -xvzf ${QPKG_ROOT}/openhab-SNAPSHOT.tar.gz --directory=${QPKG_TMP}

}

case "$1" in
  start)
    ENABLED=$(/sbin/getcfg ${QPKG_NAME} Enable -u -d FALSE -f ${CONF})
    if [ "$ENABLED" != "TRUE" ]; then
        echo "$QPKG_NAME is disabled."
        exit 1
    fi

    # Is there our own JAVA installation?
    if [ ! -d ${QPKG_JAVA} ]; then
        # Is JRE* enabled?
        JRE_ENABLED=$(/sbin/getcfg JRE Enable -u -d FALSE -f ${CONF})
        JRE_ARM_ENABLED=$(/sbin/getcfg JRE_ARM Enable -u -d FALSE -f ${CONF})
        if [ "$JRE_ENABLED" != "TRUE" ] && [ "$JRE_ARM_ENABLED" != "TRUE" ]; then
            log_tool -t 1 -a "Java not enabled! Please read the documentation about details."
            exit 1
        fi

        # Is there JAVA_HOME?
        JAVA_HOME=/usr/local/jre
        if [ ! -d ${JAVA_HOME} ]; then
            log_tool -t 1 -a "Java not found! Please read the documentation about details."
            exit 1
        fi
    else
        JAVA_HOME=${QPKG_JAVA}/jre
        if [ ! -d ${JAVA_HOME} ]; then
            log_tool -t 1 -a "Couldn't find JRE in our installation! Please read the documentation about details."
            exit 1
        fi
    fi

    # Are the ports already used?
    if lsof -Pi :${QPKG_HTTP_PORT} -sTCP:LISTEN -t > /dev/null && lsof -Pi :${QPKG_HTTPS_PORT} -sTCP:LISTEN -t > /dev/null; then
        log_tool -t 1 -a "Port ${QPKG_HTTP_PORT} or ${QPKG_HTTPS_PORT} already in use."
        exit 1
    fi

#    # Is there a pidfile?
#    if [ -f ${QPKG_PIDFILE} ]; then
#        if [ -f /proc/$(cat ${QPKG_PIDFILE})/status ] ; then
#            log_tool -t 1 -a "$QPKG_NAME is already running as <"$(cat ${QPKG_PIDFILE})"> with status: "$(cat /proc/$(cat ${QPKG_PIDFILE})/status)"."
#            exit 1
#        else
#            rm ${QPKG_PIDFILE}
#        fi
#    fi

    # Detecting PID of current instance while looking at instance.properties
    if [ -f ${QPKG_DISTRIBUTION}/runtime/karaf/instances/instance.properties ]; then
        QPKG_PID=$(sed -n -e '/item.0.pid/ s/.*\= *//p' ${QPKG_DISTRIBUTION}/runtime/karaf/instances/instance.properties)
        # Checking whether PID is still running
        if [ x${QPKG_PID} != "x" ]; then
            if [ -f /proc/${QPKG_PID}/status ] ; then
                log_tool -t 1 -a $QPKG_NAME" is still running as <"${QPKG_PID}"> with status: "$(cat /proc/${QPKG_PID}/status)"."
                exit 1
            fi
        fi
    fi

    # Get timezone defined in system
    export TZ=`/sbin/getcfg System "Time Zone" -f /etc/config/uLinux.conf`

    # Change to distribution directory and run openHAB2
    ( cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT} OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT} ${QPKG_START} > ${QPKG_STDOUT} 2> ${QPKG_STDERR} ) &
#    echo $! > ${QPKG_PIDFILE}

#    # Renice new pid - TODO: Needs more testing
#    sleep 3
#    sync
#    QPKG_PID=$(sed -n -e '/item.0.pid/ s/.*\= *//p' ${QPKG_DISTRIBUTION}/runtime/karaf/instances/instance.properties)
#    renice -10 ${QPKG_PID}
#    log_tool -t 1 -a "Reniced karaf process "${QPKG_PID}" to "$(awk '{print $19}' /proc/${QPKG_PID}/stat)
    ;;

  stop)
#    if [ -f ${QPKG_PIDFILE} ]; then
#        kill -9 $(cat ${QPKG_PIDFILE}) > ${QPKG_STDOUT}_kill 2> ${QPKG_STDERR}_kill
#        rm ${QPKG_PIDFILE}
    ( cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT} OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT} ${QPKG_STOP} > ${QPKG_STDOUT}_stop 2> ${QPKG_STDERR}_stop )
#    else
#        log_tool -t 1 -a  "$QPKG_NAME already stopped."
#    fi
    ;;

  restart)
    if ${QPKG_STOP} ; then
        if ${QPKG_START}
            then
                exit 0
            else
                exit 1
            fi
        else
            exit 1
        fi
    ;;

  status)
    exit ${QPKG_STATUS} status
    ;;

  console)
    cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT} OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT} ${QPKG_CONSOLE}
    ;;

  backup)
    mkdir -p ${QPKG_ROOT}/backups
    cd ${QPKG_DISTRIBUTION}
    tar --exclude=./.Trash-1000 \
        -vpczf \
        ${QPKG_ROOT}/backups/openHAB_backup-$(date --iso-8601=seconds).tar.gz \
        .
    cd ${QPKG_JAVA}
    tar --exclude=./.Trash-1000 \
        -vpczf \
        ${QPKG_ROOT}/backups/openHAB_backup-java-$(date --iso-8601=seconds).tar.gz \
        .
    ;;

  snapshot-download)
    # download and extract snapshot
    downloadAndExtractSnapshot
    ;;

  snapshot-update)
    # download and extract snapshot
    downloadAndExtractSnapshot

    ## Migration from the old folder layout to the new:
    ## -> https://github.com/openhab/openhab-distro/pull/318
    # Keeping karaf settings
    if [ -d ${QPKG_DISTRIBUTION}/runtime/karaf/etc ]; then
        cp -rf ${QPKG_DISTRIBUTION}/runtime/karaf/etc/* ${QPKG_TMP}/userdata/etc
        rm -rf ${QPKG_DISTRIBUTION}/runtime/karaf/etc
    fi
    # Removing superfluous/orphaned files
    rm -rf ${QPKG_DISTRIBUTION}/userdata/deploy
    rm -rf ${QPKG_DISTRIBUTION}/userdata/kar
    rm -rf ${QPKG_DISTRIBUTION}/userdata/lock
    ## END: Migration

    # Remove and replace some directories from the existing OH2 installation
    rm -rf ${QPKG_DISTRIBUTION}/runtime/
    rm -rf ${QPKG_DISTRIBUTION}/userdata/cache/*
    rm -rf ${QPKG_DISTRIBUTION}/userdata/tmp/*
    mv ${QPKG_TMP}/runtime/ distribution/
    rm -rf ${QPKG_TMP}
    ;;

  downloadJava)
    echo "Usage: $0 {downloadJavaArm32|downloadJavaArm64|downloadJavaI586|downloadJavaX64}"
    ;;
  downloadJavaArm32)
    downloadJavaArm32
    ;;
  downloadJavaArm64)
    downloadJavaArm64
    ;;
  downloadJavaI586)
    downloadJavaI586
    ;;
  downloadJavaX64)
    downloadJavaX64
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|console|backup|snapshot-update|snapshot-download|downloadJava}"
    exit 1
esac

exit 0
