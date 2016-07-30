# openhab-qnap-qpkg
openHAB Packages for QNAP NAS systems

## How to install
1. ~~Download the QPKG from the releases section here on GitHub.~~

2. Create a directory for your addons, configurations and userdata, by

  1. Creating a share called "openHAB2" (recommended)
  2. ~~Creating folder called "openHAB2" in "Public" share~~
  3. Not creating any of them and therefore using ".qpkg/openHAB2/distribution" for all data (for testing or demonstration)
  
3. Install the qpkg via "App Center" > "manual installation".

## How to uninstall
1. Go to the "App Center" and remove the app like any other.
2. If wanted/needed also remove "addons", "conf" and "userdata" from the your directory, eg. "openHAB2" share or "Public"/openHAB2
  1. _REMEMBER_: If you have installed openHAB2 to ".qpkg" (see "How to install", section 2.3) then all files get removed directly!
  
