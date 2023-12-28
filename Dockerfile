# attempting to use alpine
#FROM linuxserver/docker-baseimage-alpine:latest
FROM --platform=$BUILDPLATFORM lsiobase/alpine:3.19
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM" > /log
# Pulling TARGET_ARCH from build arguments and setting ENV variable
ARG TARGETARCH
ENV ARCH_VAR=$TARGETARCH

# future switch to s6
# alpine uses apk
RUN apk add --update bash libssl3 openssl-dev unzip && rm  -rf /tmp/* /var/cache/apk/*
# ADD supervisord.conf /etc/
COPY root/ /
RUN chmod 0755 /home/node/app/entrypoint.sh
ENTRYPOINT ["/init"]
