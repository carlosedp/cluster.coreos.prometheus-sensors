FROM golang:1.11.5-stretch as build

# Install hddtemp
RUN apt-get update && apt-get -y install \
        build-essential \
        gcc \
        libc-dev \
        hddtemp \
        lm-sensors \
        libsensors4-dev \
        git

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /go
ENV GOPATH=/go

RUN go get \
        github.com/amkay/gosensors \
        github.com/prometheus/client_golang/prometheus

RUN git clone https://github.com/epfl-sti/cluster.coreos.prometheus-sensors
RUN mkdir -p /go/src/github.com/ncabatoff/
RUN cp -R cluster.coreos.prometheus-sensors/sensor-exporter /go/src/github.com/ncabatoff/

RUN go install github.com/ncabatoff/sensor-exporter

RUN cp /usr/lib/$(uname -m)-linux-gnu/libsensors.so.4.4.0 /libsensors.so.4.4.0
RUN cp /usr/lib/$(uname -m)-linux-gnu/libsensors.a /libsensors.a

#----------------------------------------------------------------
FROM debian:stretch-slim

WORKDIR /root/
COPY --from=build /go/bin/sensor-exporter .

COPY --from=build /libsensors.so.4.4.0 /
COPY --from=build /libsensors.a /

RUN ARCH=$(uname -m) && \
    mv /libsensors.so.4.4.0 /usr/lib/$ARCH-linux-gnu/ && \
    mv /libsensors.a /usr/lib/$ARCH-linux-gnu/ && \
    ln -sf /usr/lib/$ARCH-linux-gnu/libsensors.so.4.4.0 /usr/lib/$ARCH-linux-gnu/libsensors.so.4 && \
    ln -sf /usr/lib/$ARCH-linux-gnu/libsensors.so.4 /usr/lib/$ARCH-linux-gnu/libsensors.so

# Run the outyet command by default when the container starts.
#ENTRYPOINT [ "/bin/bash", "-c", "set -x; hddtemp -q -d -F /dev/sd? & /go/bin/sensor-exporter" ]
CMD [ "/root/sensor-exporter" ]

# Document that the service listens on port 9255.
EXPOSE 9255

