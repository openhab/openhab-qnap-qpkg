# openhab-qnap-qpkg
openHAB Packages for QNAP NAS systems

 ![AppCenter enabled](docs/QTS_4.2.0_AppCenter%20enabled.png)

## How to install
1. Download the QPKG from the releases section here on GitHub.

2. Create a directory for your addons, configurations and userdata, by

  1. ~~Creating a share called "openHAB2" (recommended)~~ Due to issue (2)
  2. ~~Creating folder called "openHAB2" in "Public" share~~ Due to issue (2)
  3. Not creating any of them and therefore using ".qpkg/openHAB2/distribution" for all data (for testing or demonstration)

3. Go to your NAS's App Center and make sure you have got "JRE" (for x86) or "JRE_ARM" (for ARM) installed. You can find the application via search function or under the category "Developer Tools".

4. Wait for a while until the Java installation has finished.

5. Finally install the qpkg via "Install Manually".

## How to uninstall
1. Go to the "App Center" and remove the app like any other.
2. If wanted/needed also remove "addons", "conf" and "userdata" from the your directory, eg. "openHAB2" share or "Public"/openHAB2
  1. _REMEMBER_: If you have installed openHAB2 to ".qpkg" (see "How to install", section 2.3) then all files get removed directly!

## Known issues
* (1) Wrong start/stop behaviour: https://github.com/openhab/openhab-distro/issues/258
* (2) Symlinked directory are not watched for changes: https://github.com/openhab/openhab-distro/issues/265
