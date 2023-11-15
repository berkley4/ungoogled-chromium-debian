# Building the Widevine CDM deb package

This involves running a script to download an official google chrome deb
package from google and extracting the widevine cdm files from it.

This results in a widevine-cdm deb being produced in the widevine-cdm
directory.

Note that neither the extracted files nor any package build from them are
redistributable. The licence file (included in the deb) states this quite
clearly.


___Script variables___

The script takes the following variables :-

- CHROME_VER	<chrome version>
- DL_CACHE	<path/to/folder>
- CHECK		<0|1>

CHROME_VER is mandatory and is the google chrome version eg 116.0.5845.140-1
(note the '-1' suffix).

DL_CACHE is optional and defaults to ../download_cache (ie alongside the
widevine-cdm folder).

CHECK is optional and defaults to 0 (no checking). When enabled this checks
for an existing install and skips building a new deb if the installed version
matches that from the downloaded deb file.


___Example usage___

```sh
env CHROME_VER=116.0.5845.110-1 DL_CACHE=/tmp /bin/sh ./widevine-cdm/widevine-cdm.sh
```

The 'env' bit, plus the /bin/sh might be useful to those working on a noexec mounted
drive/partition. If this doesn't affect you, then a simpler equivalent command is :-

```sh
CHROME_VER=116.0.5845.110-1 DL_CACHE=/tmp ./widevine-cdm/widevine-cdm.sh
```


___Testing widevine___

The files are installed to /usr/lib/WidevineCdm, and you can
test to see if things are working be going to the following urls :-

[https://bitmovin.com/demos/drm](https://bitmovin.com/demos/drm)

[https://demo.castlabs.com/#/player/demo](https://demo.castlabs.com/#/player/demo) [click on the 'Protected' links]
