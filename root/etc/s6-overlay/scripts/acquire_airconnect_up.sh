#!/usr/bin/with-contenv bash

echo "Start of acquire_airconnect_up.sh"

# This one shot script is a dependacy and will run first.
# It will check if the request version has been downloaded and if not download
# It will check if the downloaded file has been unzipped and if not unzip
# It will check if the desired binaries are copied into place with the correct permissions

if [ "$ARCH_VAR" == "amd64" ]; then
  ARCH_VAR=linux-x86_64
elif [ "$ARCH_VAR" == "arm64" ]; then
  ARCH_VAR=linux-aarch64
# elif [ "$ARCH_VAR" == "arm" ]; then
#   ARCH_VAR=linux-arm
fi

echo "Checking for valid arch options"
case $ARCH_VAR in
  linux-x86_64)
    echo "Proceeding with linux-x86_64 arch"
    ;;
  linux-aarch64)
    echo "Proceeding with linux-aarch64 arch"
    ;;
  # linux-arm)
  #   echo "Proceeding with linux-arm arch"
  #   ;;
  *)
    echo "Unrecognized or invalid arch selection, CANCELING INSTALL"
    echo "========== FAILURE DETECTED ========="
    echo "YOUR CONTAINER WILL NOT WORK, PLEASE ADDRESS OR OPEN AN ISSUE"
    exit 1
    ;;
esac

# Adjusting process names in supervisord for Architecture differences
#[ "$ARCH_VAR" != "linux-x86_64" ] && sed -i 's;process_name = airupnp-linux-x86_64;process_name = airupnp-'"$ARCH_VAR"';' /etc/supervisord.conf
#[ "$ARCH_VAR" != "linux-x86_64" ] && sed -i 's;process_name = aircast-linux-x86_64;process_name = aircast-'"$ARCH_VAR"';' /etc/supervisord.conf

#test if PATH is not zero length and not null, if so use default, if not use variable
if [ -z "${PATH_VAR}" ]; then
   var_path="/tmp"
else
   var_path="${PATH_VAR}"
fi

#test if VERSION is zero length or not set, if so use default, if not use variable
if [ -z "${VERSION_VAR}" ]; then
   var_tag="latest"
else
   var_tag="tags/${VERSION_VAR}"
fi

# download the json and grep out the URL for the supplied tag
var_url=$(curl -s https://api.github.com/repos/philippe44/AirConnect/releases/${var_tag} | grep browser_download_url | cut -d '"' -f 4)
# test if variable is zero length or not set (a bad version will result in a zero length url)
if [ -z "${var_url}" ]; then
   var_url=$(curl -s https://api.github.com/repos/philippe44/AirConnect/releases/latest | grep browser_download_url | cut -d '"' -f 4)
fi

#derive filename from URL
var_filename=${var_url##*/}

#derive version from filename
var_version=${var_filename%.*}
var_version=${var_version#*-}

#future check if file already exists so that downloading can be skipped - only works if download location is persistant
echo "testing if ${var_path}/${var_filename} exists"
if [ ! -f /${var_path}/${var_filename} ]; then
    echo "file not found, downloading"
    mkdir -p ${var_path}
    # to allow saving download to path, change directory first.
    #future investigate curl version and --output-dir flag
    cd ${var_path}
    curl -L -o ${var_filename} ${var_url}
    cd /
    #future add check for download success
else
    echo "file exists"
fi

# test if desired binaries exist
# if not, extract and copy files to path (to persist) and to the container
# cleanup the extracted files
echo "testing if either ${var_path}/${var_version}/airupnp-${ARCH_VAR} or ${var_path}/${var_version}/aircast-${ARCH_VAR} does not exists"
if [ ! -f ${var_path}/${var_version}/airupnp-${ARCH_VAR} -o ! -f ${var_path}/${var_version}/aircast-${ARCH_VAR} ]; then
    unzip ${var_path}/${var_filename} airupnp-${ARCH_VAR} aircast-${ARCH_VAR} *.dll -d ${var_path}/${var_filename%.*}/ \
    && mkdir -p ${var_path}/${var_version} \
    && mv ${var_path}/${var_filename%.*}/airupnp-${ARCH_VAR} ${var_path}/${var_version}/airupnp-${ARCH_VAR} \
    && mv ${var_path}/${var_filename%.*}/aircast-${ARCH_VAR} ${var_path}/${var_version}/aircast-${ARCH_VAR}
    echo "$(ls -la ${var_path}/${var_version}/)"
    # clean up extracted files
    echo "Removing ${var_path}/${var_filename%.*}/"
    rm -r ${var_path}/${var_filename%.*}/
fi

if [ -f /bin/airupnp-${ARCH_VAR} ]; then
    echo "Removing old executable /bin/airupnp-${ARCH_VAR}"
    rm /bin/airupnp-${ARCH_VAR}
fi
if [ -f /bin/aircast-${ARCH_VAR} ]; then
    echo "Removing old executable /bin/aircast-${ARCH_VAR}"
    rm /bin/aircast-${ARCH_VAR}
fi

# move specified binaries into place unless skipped by kill variable
if [ "$AIRUPNP_VAR" != "kill" ]; then
    echo "copying ${var_path}/${var_version}/airupnp-${ARCH_VAR} to /bin/airupnp-${ARCH_VAR}"
    cp ${var_path}/${var_version}/airupnp-${ARCH_VAR} /bin/airupnp-${ARCH_VAR} \
    && chmod +x /bin/airupnp-$ARCH_VAR
    echo "$(ls -la /bin/airupnp-$ARCH_VAR)"
else
    echo "Skipping copy of ${var_path}/${var_version}/airupnp-${ARCH_VAR}"
    echo "setting airupnp service to down"
    s6-svc -d /etc/s6-overlay/s6-rc.d/airupnp
fi

# move specified binaries into place unless skipped by kill variable
if [ "$AIRCAST_VAR" != "kill" ]; then
    echo "copying ${var_path}/${var_version}/aircast-${ARCH_VAR} to /bin/aircast-${ARCH_VAR}"
    cp ${var_path}/${var_version}/aircast-${ARCH_VAR} /bin/aircast-${ARCH_VAR} \
    && chmod +x /bin/aircast-$ARCH_VAR
    echo "$(ls -la /bin/aircast-$ARCH_VAR)"
else
    echo "Skipping copy of ${var_path}/${var_version}/aircast-${ARCH_VAR}"
    echo "setting aircast service to down"
    s6-svc -d /etc/s6-overlay/s6-rc.d/aircast
fi

echo "end of acquire_airconnect_up.sh"
