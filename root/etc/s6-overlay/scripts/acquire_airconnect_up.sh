#!/usr/bin/with-contenv bash
echo "=== Starting acquire_airconnect_up.sh ==="
# This one-shot script is a dependacy and will run first.
# It will check if the requested version has been downloaded and if not download it
# It will check if the downloaded file has been unzipped and if not unzip
# It will check if the desired binaries are copied into place with the correct permissions

if [ "$ARCH_VAR" == "amd64" ]; then
  ARCH_VAR=linux-x86_64
elif [ "$ARCH_VAR" == "arm64" ]; then
  ARCH_VAR=linux-aarch64
elif [ "$ARCH_VAR" == "arm" ]; then
   ARCH_VAR=linux-arm
fi

echo " Checking for valid arch options"
case $ARCH_VAR in
  linux-x86_64)
    echo "  Proceeding with linux-x86_64 arch"
    ;;
  linux-aarch64)
    echo "  Proceeding with linux-aarch64 arch"
    ;;
  linux-arm)
    echo "  Proceeding with linux-arm arch"
    ;;
  *)
    echo "  Unrecognized or invalid arch selection, CANCELING INSTALL"
    echo "  ========== FAILURE DETECTED ========="
    echo "  YOUR CONTAINER WILL NOT WORK, PLEASE ADDRESS OR OPEN AN ISSUE"
    exit 1
    ;;
esac

# update variable so that the statically linked executable is used
ARCH_VAR="${ARCH_VAR}-static"

#test if PATH_VAR is zero length or not set, if so use default, if not use the passed variable
if [ -z "${PATH_VAR}" ]; then
   var_path="/tmp"
else
   var_path="${PATH_VAR}"
fi

#test if VERSION_VAR is zero length or not set, if so use default, if not use the passed variable
if [ -z "${VERSION_VAR}" ]; then
   var_tag="latest"
else
   var_tag="tags/${VERSION_VAR}"
fi

# download the json and grep out the URL for the supplied tag
var_url=$(curl -s https://api.github.com/repos/philippe44/AirConnect/releases/${var_tag} | grep browser_download_url | cut -d '"' -f 4)
# test if variable is zero length or not set (a bad version tag will result in a zero length url)
if [ -z "${var_url}" ]; then
   var_url=$(curl -s https://api.github.com/repos/philippe44/AirConnect/releases/latest | grep browser_download_url | cut -d '"' -f 4)
fi

#derive filename from URL
var_filename=${var_url##*/}

#future check if file already exists so that downloading can be skipped - only works if download location is persistant
echo " testing if ${var_path}/${var_filename} exists"
if [ ! -f ${var_path}/${var_filename} ]; then
    echo "  ${var_path}/${var_filename} not found, downloading"
    mkdir -p ${var_path}
    # to allow saving download to path, change directory first.
    #future investigate curl version and --output-dir flag
    cd ${var_path}
    curl -L -o ${var_filename} ${var_url}
    cd /
    #future add check for download success
else
    echo "  file exists"
fi

#derive version from filename
var_version=${var_filename%.*}
#var_version=AirConnect-1.6.2
#var_version=${var_version#*-}
#var_version=1.6.2

# test if desired binaries exist
# if not, extract and copy files to path (to persist) and to the container
# cleanup the extracted files
echo " testing if either ${var_path}/${var_version}/airupnp-${ARCH_VAR} or ${var_path}/${var_version}/aircast-${ARCH_VAR} does not exist"
if [ ! -f ${var_path}/${var_version}/airupnp-${ARCH_VAR} -o ! -f ${var_path}/${var_version}/aircast-${ARCH_VAR} ]; then
    echo "  extracting required executables: airupnp-${ARCH_VAR} aircast-${ARCH_VAR}"
    unzip -o ${var_path}/${var_filename} airupnp-${ARCH_VAR} aircast-${ARCH_VAR} -d ${var_path}/${var_version}/
fi

ls -la ${var_path}/${var_version}/
if [ ${MAXTOKEEP_VAR} -eq 0 ]; then
   echo " MAXTOKEEP_VAR is set to zero or not set, skipping cleanup"
else
   echo " MAXTOKEEP_VAR is set to ${MAXTOKEEP_VAR}, will keep the most recent ${MAXTOKEEP_VAR} .zip files and directories"
   var_max=${MAXTOKEEP_VAR}
   cd ${var_path}
   n=0
   # only keep X versions of file
   echo " checking for files and directories to clean up"
   ls -1t *.zip |
   while read file; do
      n=$((n+1))
      if [ $n -gt $var_max ]; then
          echo "  removing ${file}"
          rm "${file}"
      fi
   done
   n=0
   # only keep X versions of directories
   ls -1dt */ |
   while read directory; do
      n=$((n+1))
      if [ $n -gt $var_max ]; then
          echo "  removing ${directory}"
          rm -r "$directory"
      fi
   done
   n=0
   cd /
fi

# copy specified binaries into place unless skipped by kill variable
if [ "$AIRUPNP_VAR" != "kill" ]; then
    echo " copying ${var_path}/${var_version}/airupnp-${ARCH_VAR} to /bin/airupnp-${ARCH_VAR}"
    cp ${var_path}/${var_version}/airupnp-${ARCH_VAR} /bin/airupnp-${ARCH_VAR} \
    && chmod +x /bin/airupnp-$ARCH_VAR
else
    echo " AIRUPNP_VAR variable set to \"kill\", not enabling airupnp service and removing any previous airupnp executables from /bin"
    rm /bin/airupnp-* 2> /dev/null
fi

# copy specified binaries into place unless skipped by kill variable
if [ "$AIRCAST_VAR" != "kill" ]; then
    echo " copying ${var_path}/${var_version}/aircast-${ARCH_VAR} to /bin/aircast-${ARCH_VAR}"
    cp ${var_path}/${var_version}/aircast-${ARCH_VAR} /bin/aircast-${ARCH_VAR} \
    && chmod +x /bin/aircast-$ARCH_VAR
else
    echo " AIRCAST_VAR variable set to \"kill\", not enabling aircast service and removing any previous aircast executables from /bin"
    rm /bin/aircast-* 2> /dev/null
fi

echo " executable usage:"
if [ -f /bin/airupnp-${ARCH_VAR} ]; then
/bin/airupnp-$ARCH_VAR -h
elif [ -f /bin/aircast-$ARCH_VAR ]; then
/bin/aircast-$ARCH_VAR -h
fi

echo "=== exiting acquire_airconnect_up.sh ==="
