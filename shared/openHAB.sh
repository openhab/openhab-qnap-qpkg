#!/bin/bash

CONF=/etc/config/qpkg.conf
QPKG_HTTP_PORT=8090
QPKG_HTTPS_PORT=8444
QPKG_NAME="openHAB"
QPKG_ROOT=`/sbin/getcfg $QPKG_NAME Install_Path -f ${CONF}`
# QPKG_ROOT = /sbin/getcfg openHAB Install_Path -f /etc/config/qpkg.conf := /share/MD0_DATA/.qpkg/openHAB
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
QPKG_SNAPSHOT_VERSION=2.5.7

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
    if [ -f ${QPKG_ROOT}/openhab-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz ]; then
        rm ${QPKG_ROOT}/openhab-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz
    fi
	# down: https://openhab.ci.cloudbees.com /job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz
	# read: https://github.com/openhab/openhab-docs/issues/825 and change reference to https://ci.openhab.org/
    wget --show-progress \
        --no-check-certificate \
        -O ${QPKG_ROOT}/openhab-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz \
		https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz
    # Extract runtime for snapshot and clean up
    if [ -d ${QPKG_TMP} ]; then
        rm -rf ${QPKG_TMP}
    fi
    mkdir -p ${QPKG_TMP}
    tar -xvzf ${QPKG_ROOT}/openhab-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz --directory=${QPKG_TMP}

}

function CheckSnapshot {
	echo "The downloadAndExtractSnapshot function will use the following:"
	echo "Version: ${QPKG_SNAPSHOT_VERSION} (as hard coded) for at root directory ${QPKG_ROOT} "
	echo "Distribution location: ${QPKG_DISTRIBUTION} "
	echo "data from (fixed): https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz "
	echo "to file: ${QPKG_ROOT}/openhab-${QPKG_SNAPSHOT_VERSION}-SNAPSHOT.tar.gz "
	echo "is unpacked via tar -xvzf into: directory ${QPKG_TMP} "
	echo ""
	echo "The updateSnapshot will downloadAndExtractSnapshot and upgrade/replace data in place"
	echo " * move karaf/etc settings (if any) to ${QPKG_ROOT}/openHAB/tmp/userdata/etc "
	echo " * cleanup (if any) Karaf deployments in the distribtion"
	echo " * upgrade ${QPKG_ROOT}/openhab/distribution/userdata/tmp from SNAPshot"
	echo " * update ${QPKG_ROOT}/openhab/distribution/userdata/etc from SNAPshot"
	echo " * upgrade ${QPKG_ROOT}/openhab/distribution/runtime from SNAPshot"
	echo ""
	echo "Note: on this QNAP, the /etc/config/qpkg.conf is actually on /mnt/HDA_ROOT/.config/qpkg.conf"
	echo "wehich might require manual chage to reflect version. Ensure that openHAB is not active"
}


function setupEnvironment {
    ## JAVA SETUP
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

    echo "* Note: JAVA_HOME="$JAVA_HOME

    ## PORT SETUP
    # Default ports
    OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT}
    OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT}

    # http port
    if [ -f ${QPKG_DISTRIBUTION}/conf/qpkg/http.port ]; then
        typeset -i OPENHAB_HTTP_PORT=$(cat ${QPKG_DISTRIBUTION}/conf/qpkg/http.port)
    fi
    if [ "$OPENHAB_HTTP_PORT" -eq "0" ]; then
        OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT}
        log_tool -t 1 -a "Your http port definition is fautly. Using default ${OPENHAB_HTTP_PORT} instead!"
    fi
    # https port
    if [ -f ${QPKG_DISTRIBUTION}/conf/qpkg/https.port ]; then
        typeset -i OPENHAB_HTTPS_PORT=$(cat ${QPKG_DISTRIBUTION}/conf/qpkg/https.port)
    fi
    if [ "$OPENHAB_HTTPS_PORT" -eq "0" ]; then
        OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT}
        log_tool -t 1 -a "Your http port definition is faulty. Using default ${OPENHAB_HTTPS_PORT} instead!"
    fi
    echo "* Note: OPENHAB_HTTP_PORT="$OPENHAB_HTTP_PORT
    echo "* Note: OPENHAB_HTTPS_PORT="$OPENHAB_HTTPS_PORT
}

function checkPorts {
    # Are the ports already used?
    if lsof -Pi :${OPENHAB_HTTP_PORT} -sTCP:LISTEN -t > /dev/null && lsof -Pi :${OPENHAB_HTTPS_PORT} -sTCP:LISTEN -t > /dev/null; then
        log_tool -t 1 -a "Port ${OPENHAB_HTTP_PORT} or ${OPENHAB_HTTPS_PORT} already in use."
        exit 1
    fi
}

case "$1" in
  mstop)
    setupEnvironment
#    if [ -f ${QPKG_PIDFILE} ]; then
#        kill -9 $(cat ${QPKG_PIDFILE}) > ${QPKG_STDOUT}_kill 2> ${QPKG_STDERR}_kill
#        rm ${QPKG_PIDFILE}
    ( cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT} OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT} ${QPKG_STOP}  )
#    else
#        log_tool -t 1 -a  "$QPKG_NAME already stopped."
#    fi

    # TODO: WORKAROUND: Waiting one minute until the service is properly turned off
    echo  "stopped."
    ;;

  check)
     CheckSnapshot
	;;
  restart)
    echo "stop script=" $QPKG_STOP ", start=" $QPKG_START
    if ${QPKG_STOP} ; then
		echo "openHAB.sh:  STOP executed"
		if ${QPKG_START}
		then
			echo "openHAB.sh:  START executed"
			exit 0
		else
			echo "openHAB.sh:  START executed; exitcode 1"
			exit 1
		fi
	else
		echo "openHAB.sh:  STOP executed; exitcode 1"
		exit 1
	fi
    ;;

  mstart)
 
    setupEnvironment
    checkPorts

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
    ( cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${OPENHAB_HTTP_PORT} OPENHAB_HTTPS_PORT=${OPENHAB_HTTPS_PORT} ${QPKG_START}  ) &
	log_tool -t 1 -a "openhab started "${QPKG_PID}" to "$(awk '{print $19}' /proc/${QPKG_PID}/stat)

#    # Renice new pid - TODO: Needs more testing
     sleep 3
     sync
     QPKG_PID=$(sed -n -e '/item.0.pid/ s/.*\= *//p' ${QPKG_DISTRIBUTION}/runtime/karaf/instances/instance.properties)
     renice -10 ${QPKG_PID}
     log_tool -t 1 -a "Reniced karaf process "${QPKG_PID}" to "$(awk '{print $19}' /proc/${QPKG_PID}/stat)

    # TODO: WORKAROUND: Waiting one and a half minute until the service is properly turned on
    echo "Started manually"
    ;;

  
  start)
    ENABLED=$(/sbin/getcfg ${QPKG_NAME} Enable -u -d FALSE -f ${CONF})
    if [ "$ENABLED" != "TRUE" ]; then
        echo $QPKG_NAME "is disabled."
        exit 1
    fi

    setupEnvironment
    checkPorts

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
    echo "QPKG_START="$QPKG_START
    ( cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${OPENHAB_HTTP_PORT} OPENHAB_HTTPS_PORT=${OPENHAB_HTTPS_PORT} ${QPKG_START} )
  # ( cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${OPENHAB_HTTP_PORT} OPENHAB_HTTPS_PORT=${OPENHAB_HTTPS_PORT} ${QPKG_START} > ${QPKG_STDOUT} 2> ${QPKG_STDERR} ) &
#    echo $! > ${QPKG_PIDFILE}

#    # Renice new pid - TODO: Needs more testing
#    sleep 3
#    sync
#    QPKG_PID=$(sed -n -e '/item.0.pid/ s/.*\= *//p' ${QPKG_DISTRIBUTION}/runtime/karaf/instances/instance.properties)
#    renice -10 ${QPKG_PID}
#    log_tool -t 1 -a "Reniced karaf process "${QPKG_PID}" to "$(awk '{print $19}' /proc/${QPKG_PID}/stat)

    # TODO: WORKAROUND: Waiting one and a half minute until the service is properly turned on
    echo "Waiting 90 secs until the openHAB service is properly turned on"
    sleep 90
    ;;

  stop)
    setupEnvironment
#    if [ -f ${QPKG_PIDFILE} ]; then
#        kill -9 $(cat ${QPKG_PIDFILE}) > ${QPKG_STDOUT}_kill 2> ${QPKG_STDERR}_kill
#        rm ${QPKG_PIDFILE}
	echo "Stop exec:" $QPKG_STOP
    # ( cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT} OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT} ${QPKG_STOP} > ${QPKG_STDOUT}_stop 2> ${QPKG_STDERR}_stop )
    ( cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT} OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT} ${QPKG_STOP} )
#    else
#        log_tool -t 1 -a  "$QPKG_NAME already stopped."
#    fi

    # TODO: WORKAROUND: Waiting one minute until the service is properly turned off
    echo Waiting 60 secs until the openHAB service is properly shutted down
    sleep 60
    ;;


  ports)
    # added by pocs on 13jun18 for test
    setupEnvironment
    lsof -Pi :${OPENHAB_HTTP_PORT} -sTCP:LISTEN -t 
    lsof -Pi :${OPENHAB_HTTPS_PORT} -sTCP:LISTEN -t
    ;;


  status)
    echo "executing:"$QPKG_STATUS
    setupEnvironment
    cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT} OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT} 
    ${QPKG_STATUS}
    ;;

  console)
    echo "please for checking environment usage step 1 QPKG_CONSOLE =" ${QPKG_CONSOLE}
    # QPKG_CONSOLE = /share/MD0_DATA/.qpkg/openHAB/distribution/start.sh
    setupEnvironment
    echo "please wait for not in use ports QPKG_HTTP_PORT=" ${QPKG_HTTP_PORT} QPKG_HTTPS_PORT "=" ${QPKG_HTTPS_PORT}
    # QPKG_HTTP_PORT = 8090
    checkPorts
    echo console function being activated
    cd ${QPKG_DISTRIBUTION} && JAVA_HOME=${JAVA_HOME} PATH=$PATH:${JAVA_HOME}/bin OPENHAB_HTTP_PORT=${QPKG_HTTP_PORT}    OPENHAB_HTTPS_PORT=${QPKG_HTTPS_PORT} ${QPKG_CONSOLE} > ${QPKG_STDOUT} 2> ${QPKG_STDERR} &
    echo "console function started, check pid......"
    ;;

  backup)
	# 05jul20 15u00 : disabled Java backup as its not applicaple to Qnap, changed date format to allow proper SMB/sharing 
    mkdir -p ${QPKG_ROOT}/backups
    cd ${QPKG_DISTRIBUTION}

    tar --exclude=./.Trash-1000 \
        -vpczf \
        ${QPKG_ROOT}/backups/openHAB_backup-$(date +%Y%m%d-%H%M%S).tar.gz \
        .
    # cd ${QPKG_JAVA}
    # tar --exclude=./.Trash-1000 \
    #    -vpczf \
    #    ${QPKG_ROOT}/backups/openHAB_backup-java-$(date --iso-8601=seconds).tar.gz \
    #    .
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

	# the following is happenin here:
	# If exist, set aside Karaf settings into distribution/etc:
	# copy	/share/MD0_DATA/.qpkg/openHAB/distribution/runtime/karaf/etc  to /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/etc
	# del	/share/MD0_DATA/.qpkg/openHAB/distribution/runtime/karaf/etc
	#
	# Remove old "Karaf/Deploy" rubbish:
	# del	/share/MD0_DATA/.qpkg/openHAB/distribution/userdata/deploy	# (not existing)
	#       /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/kar 	# (empty)
	#       /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/lock	# (not existing)
	#
	# Remove/empty: ../userdata/tmp and refill from snapshot
	# remove /share/MD0_DATA/.qpkg/openHAB/distribution/runtime			# (will be refilled)
	#        /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/cache 	# (filled with wring & bundles)
	#        /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/tmp  	# (work)
	# copy   /share/MD0_DATA/.qpkg/openHAB/tmp/userdata/tmp /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/tmp 	# (readme)
	#
	# Save existing Karaf settings in ../userdata/etc
	# remove /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/etc-old	# (not existing)
	# move 	 /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/etc /share/MD0_DATA/.qpkg/openHAB/distribution/userdata/etc-old # save
	# place	 /share/MD0_DATA/.qpkg/openHAB/tmp/userdata/etc	/share/MD0_DATA/.qpkg/openHAB/distribution/userdata/etc
	#
	# place/refill ../runtime:
	# move	/share/MD0_DATA/.qpkg/openHAB/tmp/runtime /share/MD0_DATA/.qpkg/openHAB/distribution/

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
    mv ${QPKG_TMP}/userdata/tmp/* ${QPKG_DISTRIBUTION}/userdata/tmp/
    rm -rf ${QPKG_DISTRIBUTION}/userdata/etc-old
    if [ -d ${QPKG_DISTRIBUTION}/userdata/etc ]; then
        mv ${QPKG_DISTRIBUTION}/userdata/etc ${QPKG_DISTRIBUTION}/userdata/etc-old
    fi
    mv ${QPKG_TMP}/userdata/etc ${QPKG_DISTRIBUTION}/userdata/etc
    mv ${QPKG_TMP}/runtime/ ${QPKG_DISTRIBUTION}
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
    echo "Usage: $0 {start|stop|restart|status|console|backup|check|snapshot-update|snapshot-download|downloadJava}"
    exit 1
esac

exit 0
