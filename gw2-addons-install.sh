#!/bin/bash
#
# Script to aid in the update process of guild wars 2 addons such as ArcDPS.
#
# Just configure the install path below and then just run the script.
#
# If you don't want the boon table or DirectX 9 Vulkan Layer translation, enter
# 0 instead of 1.
#
# If lutris exists with a game name 'Guild Wars 2', this script will use that
# directory path if it exists. Otherwise, it'll try to use the one configured
# in this file.
#
# The boon table and d9vk install boolean can be overridden by setting the
# environment varaibles BT_INSTALL=1 VK_INSTALL=1 whne running this script.
#
# A configuration file can be used, this file should contain one or more of the
# following. The file name should be in the same folder named gw2-scripts.conf
#
# - GW2_INSTALL_PATH: [str] Path to GW2 install directory.
# - BT_INSTALL: [int] 1 to install, otherwise skip.
# - VK_INSTALL: [int] 1 to install, otherwise skip.
# - DRY_RUN: [int] 1 to dry run the script, i.e. don't copy to installation.
#

if [[ $1 =~ "--dry-run" ]]; then
    DRY_RUN=1
fi

function die() {
    echo "Error: $*" >&2
    exit 1
}

. "$(cd "$(dirname "$0")" && pwd)/gw2-scripts.conf"

which lutris > /dev/null
if [[ -z $GW2_INSTALL_PATH ]] && [[ $? -eq 0 ]]; then
read -d ''  PY_LUTRIS_SCRIPT <<"EOF"
import json
import sys
data = json.loads(sys.stdin.read())
data = filter(lambda x: x['name'] == 'Guild Wars 2', data)
data = map(lambda x: x['directory'], data)
data = next(data)
if not data:
    sys.exit(1)
print(data)
EOF
    LUTRIS_DATA=$(lutris --list-games --json)
    if [[ $? -eq 0 ]]; then
        LUTRIS_DATA=$(echo "${LUTRIS_DATA}" | python3 -c "${PY_LUTRIS_SCRIPT}")
        if [[ $? -eq 0 ]] && [[ -n ${LUTRIS_DATA} ]]; then
            GW2_INSTALL_PATH="${LUTRIS_DATA}"
        fi
    fi
fi

### Configuration - Change this to the correct path

if [[ -z ${GW2_INSTALL_PATH} ]]; then
    GW2_INSTALL_PATH="/home/user/Games/Guild Wars 2"
fi
[[ ! -f ${GW2_INSTALL_PATH}/Gw2-64.exe ]] && die "Expecting install path to include Gw2-64.exe"
[[ ! -d ${GW2_INSTALL_PATH}/bin64 ]] && die "Expecting install path to include bin64/"

ADPS_URL="https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
ADPS_FILE="bin64/d3d9.dll"

BT_INSTALL=${BT_INSTALL:-1}
BT_OWNER="knoxfighter"
BT_REPO="GW2-ArcDPS-Boon-Table"
BT_FILE="bin64/d3d9_arcdps_table.dll"

VK_INSTALL=${VK_INSTALL:-0}
VK_OWNER="Joshua-Ashton"
VK_REPO="d9vk"
VK_FILE="bin64/d3d9_chainload.dll"

### End config

TMPDIR=$(mktemp -d '/tmp/gw2-addon-update.XXXXXXX')
trap "rm -rf ${TMPDIR}" EXIT

read -d '' PY_SCRIPT_ARTIFACT_URL <<"EOF"
import json
import sys

def endswith_list(str, suffix):
    for suf in suffix:
        if str.endswith(suf):
            return True
    return False

data = json.loads(sys.stdin.read())
data = filter(lambda x: endswith_list(x['name'], ['.dll', '.tar.gz']), data[0]['assets'])
data = next(data)
print(data['browser_download_url'])
EOF

function get_latest_gh_artifact() {
    local owner=$1
    local repo=$2
    local artifact=$3
    echo ":: Querying Github Releases"
    local out=$(curl \
        --fail \
        "https://api.github.com/repos/${owner}/${repo}/releases")
    [[ $? -ne 0 ]] && die "Failed to query latest release"
    local art_url=$(echo "${out}" | python3 -c "${PY_SCRIPT_ARTIFACT_URL}")
    [[ $? -ne 0 ]] && die "Py script failed"
    echo ":: Downloading ${art_url}" >&2
    echo "::  as ${artifact}" >&2
    curl --fail -L "${art_url}" -o "${artifact}"
}

echo ":: Downloading ${ADPS_URL}" >&2
curl --fail "${ADPS_URL}" -o "${TMPDIR}/${ADPS_FILE##*/}"
[[ $? -ne 0 ]] && die "Failed to download arcdps"

if [[ ${BT_INSTALL} -eq 1 ]]; then
    get_latest_gh_artifact "${BT_OWNER}" "${BT_REPO}" "${TMPDIR}/${BT_FILE##*/}"
    [[ $? -ne 0 ]] && die "Failed to download artifact for ${BT_REPO}"
fi
if [[ ${VK_INSTALL} -eq 1 ]]; then
    get_latest_gh_artifact "${VK_OWNER}" "${VK_REPO}" "${TMPDIR}/d9vk.tar.gz"
    [[ $? -ne 0 ]] && die "Failed to download artifact for ${VK_REPO}"

    pushd "${TMPDIR}" > /dev/null
    tar xf d9vk.tar.gz --strip-components 1
    popd > /dev/null
fi

pushd "${GW2_INSTALL_PATH}" > /dev/null

function do_install() {
    local dest_file="$1"
    if [[ -n $2 ]]; then
        local src_file="$2"
    else
        local src_file="${TMPDIR}/${dest_file##*/}"
    fi
    local old_md5=$(md5sum "${dest_file}" | awk '{print $1}')
    local new_md5=$(md5sum "${src_file}" | awk '{print $1}')
    if [[ ${old_md5} != ${new_md5} ]]; then
        if [[ $DRY_RUN -ne 1 ]]; then
            cp "${src_file}" "${dest_file}"
            chmod 0755 "${dest_file}"
        fi
        echo "${dest_file}: CHANGED"
    else
        echo "${dest_file}: UNCHANGED"
    fi
}

do_install "${ADPS_FILE}"
if [[ ${BT_INSTALL} -eq 1 ]]; then
    do_install "${BT_FILE}"
fi
if [[ ${VK_INSTALL} -eq 1 ]]; then
    do_install "${VK_FILE}" "${TMPDIR}/x64/d3d9.dll"
fi

popd > /dev/null
