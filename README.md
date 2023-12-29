changes:
* changed from supervisor to s6
* changed image from ls.io ubuntu to ls.io alpine
* changed the script order to download airconnect on container start (instead of requiring a container build)
* added environment variables for persistent path and specific AirConnect version
  * PATH_VAR - allows specifying a persistant storagepath
  * VERSION_VAR - allows specifying a specific version of airconnect
  * MAXTOKEEP_VAR - allows specifying how many previous version in the path (if it isn't persistent, only the most recent one will be there)
* added check to only download a file if it doesn't already exist in persistent path
* changed the extraction to only pull out the executables needed (changed to statically built ones)
* added check to only extract the binary files if they don't already exist

testing:
passed on RaspberryPi 3b+ running the linux-aarch64-static version of AirConnect 1.6.2 (killed aircast)
passed on RaspberryPi 4 running the linux-aarch64-static version of AirConnect 1.6.2 (killed aircast)

future:
only keep x number of directories of previous versions
better testing

If you like what I've created, please consider contributing:
<br>
<a href="https://www.paypal.com/paypalme"><img src="https://img.shields.io/badge/PayPal-Make%20a%20Donation-grey?style=for-the-badge&logo=paypal&labelColor=000000"></a>
<br>
<a href="https://ko-fi.com/"><img src="https://img.shields.io/badge/Coffee-Buy%20me%20a%20Coffee-grey?style=for-the-badge&logo=buy-me-a-coffee&labelColor=000000"></a>
<br>
<br>

# docker-airconnect
Minimal docker container with AirConnect for turning Chromecast and UPNP devices into Airplay targets  
On DockerHub: https://hub.docker.com/r/mitchellsingleton/docker-airconnect

This is a container with the fantastic program by [philippe44](https://github.com/philippe44) called AirConnect. It allows you to be able to use AirPlay to push audio to either Chromecast and / or UPNP based devices (Sonos). There are some advanced details and information that you should review on his [GitHub Project](https://github.com/philippe44/AirConnect). This container image allows passing any of the command line parameters through an environmental variable. This container does need to be launched using Host networking mode. I recommend also mounting a persistant volume and passing in through an environment variable the path. This will allow reducing the number of times that downloads will occur.

The main purpose of this derivation from the previous repository image (https://github.com/1activegeek/docker-airconnect) is to rework the scripts and logic so that this container doesn't need to be rebuilt upon a new release of AirConnect.

What differentiates this image over the others out there, is that this container acquires the AirConnect executable during container startup. It can get the latest version of the app or a specific tagged version from the AirConnect GitHub page. It uses the alpine base image (v 3.19) and s6 produced by the [LS.io team](https://github.com/linuxserver).

This image has been built using multi-architecture support for AMD64, ARM64, and ARM devices.

# Running

This can be run using a docker compose file or a standard docker run command.

Sample docker compose file (includes environment variable so the aircast executable is never started and custom parameters for the airupnp executable):

```
version: '3.9'
services:
    airconnect:
        network_mode: host
        image: mitchellsingleton/docker-airconnect
        environment:
            - "AIRCAST_VAR=kill" #this prevents the aircast executable from starting
            - "AIRUPNP_VAR=-x /config/airconnect-airupnp.xml -l 1000:2000" #custom parameters for the airupnp executable, the -x parameter loads a config file
            - "PATH_VAR=/config" #variable of where to store executables
            #- "VERSION_VAR=" #variable for a specific version, default is latest.
            - "MAXTOKEEP_VAR=10" #variable to only keep the most recent number of versions (uses modification date)

        volumes:
            - /mnt/docker_airconnect_data:/config
        networks:
            - outside

networks:
    outside:
      name: "host"
      external: true`
```

Bare minimum Docker run config (will run both aircast and airupnp executables):

`docker run -d --net=host mitchellsingleton/docker-airconnect`

If you would like to run a specific version of AirConnect you can now specify the Release Version corresponding to the releases from the original developer of the application as found here: https://github.com/philippe44/AirConnect/releases. This can be done by using an evironment variable named "VERSION_VAR". For example, to run release 1.6.1 use:

`docker run -d --net=host -e VERSION_VAR=1.6.1 mitchellsingleton/docker-airconnect`

Environment variables that can be used when you run the container:
* `AIRCAST_VAR` - This variable allows passing command line parameters to the aircast executable or using the special case of 'kill' to disable the aircast service.
  Note: do not add -z or -Z to deamonize or the s6 overlay will think the service died and will start it again.
* `AIRUPNP_VAR` - This variable allows passing command line parameters to  to send to the airupnp runtime used for integration with Sonos and UPnP based devices
  Note: do not add -z or -Z to deamonize or the s6 overlay will think the service died and will start it again.
   **If you alter this variable you need to add in `-l 1000:2000` per the devs notes for Sonos/Heos players. If you don't alter the variable, I include this by default in the docker files**

If you only need one service, you can choose to kill the unneeded service on startup so that it does not run. To do this, use the appropriate variable from above (`AIRCAST_VAR`/`AIRUPNP_VAR`) and set it equal to `kill`. This will prevent the service from starting up.

### Runtime Commands

The current usage can be seen in the docker output

```
Usage: [options]
  -b < address>        network address to bind to
  -c <mp3[:<rate>]|flc[:0..9]|wav>    audio format send to player
  -x <config file>    read config from file (default is ./config.xml)
  -i <config file>    discover players, save <config file> and exit
  -I             auto save config at every network scan
  -l <[rtp][:http][:f]>    RTP and HTTP latency (ms), ':f' forces silence fill
  -r             let timing reference drift (no click)
  -f <logfile>        Write debug to logfile
  -p <pid file>        write PID in file
  -d <log>=<level>    Set logging level, logs: all|raop|main|util|cast, level: error|warn|info|debug|sdebug
  -Z             NOT interactive
  -k             Immediate exit on SIGQUIT and SIGTERM
  -t             License terms
```

# Troubleshooting

If you need to attempt to dig into troubleshooting and see the logs realtime in the container, use the following examples to help dig into diagnosis.

`docker exec -it <name of container> bash`

Once inside the container, you can use standard config options to run the app as outlined by the creator. The app is located in the `/bin` directory. Both the UPNP and Cast versions of the file are being run in this container. (sub your platform below if not running x86-64 - arm64 = aarch64, arm = arm).

`./aircast-x86-64 --h` - will provide you a list of commands that can be run via the app

`./aircast-x86-64 -d all=debug` - will run the app and output a debug based log in an interactive mode

If you perform any realtime testing, it is suggested to completely restart the container after testing to be sure there are no incompatibilities that arise with running it in daemon mode while also running it interactively.

# Changelog
**2023-10-21:** Package maintainer changed the release asset output, had to move from tarball to zip package. No major change should be experienced as the output is still the same. Also added link in docs to an ARMv7 repo for those using older devices stuck on ARMv7 release maintained by [sidevesh](https://github.com/sidevesh). <br>
**2023-07-08:** The LS.io team has officially deprecated building ARMv7 base images. Had to deprecate this support as well. Attempted to comment out in case changes happen in the future to remedy this. <br>
**2022-11-28:** Some recent updates to handle changes by the original developer in formatting for binary file names. More efficient workflow runs as well. Added in output of tags for AirConnect versions, allowing you to specifically use a specific version of AirConnect. <br>
**2022-01-03:** Fixed the multi-arch builds with the new setup on GH actions, migrated to single unified Dockerfile deployment<br>
**2021-12-12:** Modified the builder to use the docker buildx GH actions, and manifest to be just the single tag. Additionally the Binary pull has been moved from startup script, to the actual dockerfile. This results in the images being a point-in-time version of the current airconnect binaries vs always running the latest. `kill` function introduced for the AIRUPNP_VAR/AIRCAST_VAR variables which will stop the appropriate service from running (in case you are not using it).

<p>
<p>
<a href="https://ko-fi.com/" target="_blank"><img src="https://user-images.githubusercontent.com/1685680/61808727-4925de00-ae3c-11e9-9d60-66bef358fd8e.png" alt="Buy Me A Coffee" style="height: 50px !important;width: auto !important;" ></a>
