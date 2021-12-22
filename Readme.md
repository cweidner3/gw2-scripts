# GW2 Addon Scripts

## `gw2-addons-install.sh`

Use this script to aid in the installation of ArcDPS and other related plugins
to the Guild Wars installation.

If GW2 is installed and maintained with [lutris][], then it should pick up the
install path with [lutris][]. Also note, if you want this feature than
[python-magic][] must also be installed which may be avaliable with your
package manager.

Otherwise, create a config file in this repo, `gw2-scripts.conf`.

```conf
# Path to the directory containing Gw2-64.exe
#
# This is the root of the game install path and is used as reference for
# installing the addons
GW2_INSTALL_PATH='/path/to/Guild Wars 2'

# To install the Boon Table along with ArcDPS
#   0  Dont include
#   1  Do include
BT_INSTALL=1

# To install the DirectX 9 Vulkin layer, might help with cpu usage.
#   0  Dont include
#   1  Do include
VK_INSTALL=0
```

[lutris]: https://lutris.net/
[python-magic]: https://github.com/ahupp/python-magic
