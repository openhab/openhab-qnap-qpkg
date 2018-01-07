# openhab-qnap-qpkg
openHAB Packages for QNAP NAS systems

## Requirements
* QTS firmware version minimum 4.1.0
* At least Java 1.8.101 is required
* The running service needs after installation about 200MB of System Memory. If QTS does swapping, you could experience speed problems if you have too less RAM.

## How to install
1. Download the QPKG from the [releases section over on GitHub](https://github.com/openhab/openhab-qnap-qpkg/releases).

2. Create a directory for your addons, configurations and userdata, by either
    * Creating a share called "openHAB" (recommended)
    * Creating a folder called "openHAB" inside the "Public" share
    * Not creating any of them and therefore using `.qpkg/openHAB/distribution` for all data (for testing or demonstration)

3. Go to your NAS's App Center and make sure you have got "JRE" (for x86-CPU based NAS) or "JRE_ARM" (for ARM-CPU based NAS) installed. If that is not the case, go to the "Developer-Tools" section of the App Center, install the appropriate version and wait for a while until the Java installation has finished.

4. Open the "Install manually" dialog in the App Center by clicking the gear-wheel on the upper-right corner of the App Center and choose the `qpkg` you have downloaded.

    ![AppCenter choose](https://github.com/openhab/openhab-qnap-qpkg/raw/master/docs/QTS_4.2.0_AppCenter%20choose.png)

5. Confirm the installation

    ![AppCenter confirm](https://github.com/openhab/openhab-qnap-qpkg/raw/master/docs/QTS_4.2.0_AppCenter%20confirm.png)

6. Wait while the package is being installed

7. When finished just close the dialog and wait for a while until openHAB has completely started.  This may take several minutes.

    ![AppCenter finished](https://github.com/openhab/openhab-qnap-qpkg/raw/master/docs/QTS_4.2.0_AppCenter%20finished.png)

8. Access openHAB via "[http://NAS_IP_or_DNS_address:8090](#)". If the interface does not start, retry after another minute. The initial startup takes some time.

## How to uninstall

If you want to keep configuration files, copy them to a save place outside of the openhab-path.

1. Go to the "App Center" and remove the app like any other.
2. Additionally if wanted or needed, please remove the folders "addons", "conf" and "userdata" from the your directory, eg. "openHAB" share or "Public"/openHAB"
   If you have installed openHAB2 to `.qpkg` (see "How to install", third option) then all files get removed automatically.

## Known issues
* (1) Wrong start/stop behaviour: https://github.com/openhab/openhab-distro/issues/258
* (2) Version 2.2.0 has problems with update from previous versions. 
