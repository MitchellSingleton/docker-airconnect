# Changelog

## changes:
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

## testing:
passed on RaspberryPi 3b+ running the linux-aarch64-static version of AirConnect 1.6.2 (killed aircast) using the docker command line to run on a standalone docker node.

passed on RaspberryPi 4 running the linux-aarch64-static version of AirConnect 1.6.2 (killed aircast) using portainer to create a stack on a docker swarm.

passed when using AIRCAST_VAR to kill the service

passed when using AIRUPNP_VAR to kill the service

passed when using both AIRCAST_VAR and AIRUPNP_VAR to kill their respective services

passed when using VERSION_VAR to specify version
* not set (defaults to latest - 1.6.2)
* 1.5.4
* 1.6.0
* 1.6.1
* 1.6.2

passed when using MAXTOKEEP_VAR to specify
* not set (defaults to skip cleanup)
* 3
* 0 - skips clean up

## future:


# docker-airconnect
Minimal muti-architecture (AMD64, ARM64, and ARM) docker container with AirConnect for turning Chromecast and UPNP devices into Apple Airplay targets. the image is built from 
Published on DockerHub: https://hub.docker.com/r/mitchellsingleton/docker-airconnect

This is a container built with the fantastic program by [philippe44](https://github.com/philippe44) called AirConnect. It allows you to be able to use Apple AirPlay v1 to push audio to either Chromecast and / or UPNP based devices (Sonos). I highly recommend reading through the information and details that can be found on the GitHub Repository for AirConnect [GitHub Project](https://github.com/philippe44/AirConnect). This container image allows passing any of the command line parameters through an environmental variable. This container does need to be launched using Host networking mode. I recommend also mounting a persistant volume and passing in through an environment variable the path. This will allow reducing the number of times that downloads will occur.

The main purpose of this derivation from the previous repository image (https://github.com/1activegeek/docker-airconnect) is to rework the scripts and logic so that this container doesn't need to be rebuilt upon a new release of AirConnect.

What differentiates this image over the others out there, is that this container acquires the AirConnect executable(s) during container startup. It can get the latest version of the app (default) or a specific tagged version using an environment variable from the AirConnect GitHub page. It uses the alpine base image (v 3.19) and s6 produced by the [LS.io team](https://github.com/linuxserver).

This image has been built using Docker's buildx with multi-architecture support for AMD64, ARM64, and ARM devices.

# How to use this image

This image can be used by running a docker compose file or a docker run command.

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

Sample docker run command:
`sudo docker run --net=host --pull always -v /mnt/docker_airconnect_data/:/config/ -e PATH_VAR=/config -e AIRCAST_VAR=kill -e MAXTOKEEP_VAR=10 --rm mitchellsingleton/docker-airconnect`

Bare minimum Docker run command (will run both aircast and airupnp executables as services):

`docker run -d --net=host mitchellsingleton/docker-airconnect`

If you would like to run a specific version of AirConnect you can now specify the Release Version corresponding to the releases from the original developer of the application as found here: https://github.com/philippe44/AirConnect/releases. This can be done by using an evironment variable named "VERSION_VAR". For example, to run release 1.6.1 use:

`docker run -d --net=host -e VERSION_VAR=1.6.1 mitchellsingleton/docker-airconnect`

Environment variables that can be set when the container is ran:
* `AIRCAST_VAR` - This variable allows passing command line parameters to the aircast executable or using the special case of 'kill' to disable the aircast service.
  Note: do not add -z or -Z to deamonize or the s6 overlay will think the service died and will start it again.
* `AIRUPNP_VAR` - This variable allows passing command line parameters to the airupnp executable or using the special case of 'kill' to disable the airupnp service.
  Note: do not add -z or -Z to deamonize or the s6 overlay will think the service died and will start it again.
  Note: add in `-l 1000:2000` per the AirConnect notes for Sonos/Heos players. This is part of the current default string.
* `PATH_VAR` - allows specifying a persistant storage path
* `VERSION_VAR` - allows specifying a specific version of airconnect
* `MAXTOKEEP_VAR` - allows specifying how many previous version in the path (if it isn't persistent, only the most recent one will be there)

If you only need one service, you can choose to kill the unneeded service on startup so that it does not run. To do this, use the appropriate variable from above (`AIRCAST_VAR`/`AIRUPNP_VAR`) and set it equal to `kill`. This will prevent the service from starting up.

### Runtime Commands

The usage information listing available command line parameters can be seen in the docker output. This is a copy of the output from AirConnect v1.6.2:

```
v1.6.2 (Dec 27 2023 @ 00:21:16)
See -t for license terms
Usage: [options]
  -b <ip|iface>[:<port>]        network interface or interface and UPnP port to use
  -a <port>[:<count>]   set inbound port and range for RTP and HTTP
  -c <mp3[:<rate>]|flac[:0..9]|wav|pcm> audio format send to player
  -g <-3|-1|0>          HTTP content-length mode (-3:chunked, -1:none, 0:fixed)
  -u <version>  set the maximum UPnP version for search (default 1)
  -x <config file>      read config from file (default is ./config.xml)
  -i <config file>      discover players, save <config file> and exit
  -I                    auto save config at every network scan
  -l <[rtp][:http][:f]> RTP and HTTP latency (ms), ':f' forces silence fill
  -r                    let timing reference drift (no click)
  -f <logfile>          write debug to logfile
  -p <pid file>         write PID in file
  -N <format>           transform device name using C format (%s=name)
  -m <n1,n2...>         exclude devices whose model include tokens
  -n <m1,m2,...>        exclude devices whose name includes tokens
  -o <m1,m2,...>        include only listed models; overrides -m and -n (use <NULL> if player don't return a model)
  -d <log>=<level>      Set logging level, logs: all|raop|main|util|upnp, level: error|warn|info|debug|sdebug
  -z                    Daemonize
  -Z                    NOT interactive
  -k                    Immediate exit on SIGQUIT and SIGTERM
  -t                    License terms
  --noflush             ignore flush command (wait for teardown to stop)
```

# Troubleshooting

1. When and what version was the last successfully running AirConnect and container?
2. Were there any changes that might have affected the environment? 
3. Does the AirConnect executable run successfully on the host computer?
4. Is there any output that can be seen as to why there was an issue?

Troubleshooting can be done outside of the container or inside the container, use the following examples to help dig into diagnosis.

`docker exec -it <name of container> bash`

Once inside the container, you can use standard config options to run the app as outlined by the creator. The executables will be located in the `/bin` directory. Both the UPNP and Cast versions of the file are being run in this container. (sub your platform below if not running x86-64 - arm64 = aarch64, arm = arm).

`./aircast-x86-64 --h` - will provide you a list of commands that can be run via the app

`./aircast-x86-64 -d all=debug` - will run the app and output a debug based log in an interactive mode

If you perform any testing inside the container, it is suggested to completely restart the container after testing to be sure there are no incompatibilities. If there is a mounted volume, please ensure that it is doublechecked for correctness.

# Appreciation
If you like what I've created, please consider contributing:
<br>
<a href="https://paypal.me/MitchellSingleton"><img src="https://img.shields.io/badge/PayPal-Make%20a%20Donation-grey?style=for-the-badge&logo=paypal&labelColor=000000"></a>
<br>
<a href="https://ko-fi.com/mitchellsingleton"><img src="https://img.shields.io/badge/Coffee-Buy%20me%20a%20Coffee-grey?style=for-the-badge&logo=buy-me-a-coffee&labelColor=000000"></a>
