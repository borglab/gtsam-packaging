# Container image that runs your code
FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y install git pristine-tar git-buildpackage dpkg-dev cmake libboost-all-dev libeigen3-dev libtbb-dev debhelper gnupg

# Copies your code file from your action repository to
# the filesystem path `/` of the container
COPY snapshot_script.bash /snapshot_script.bash
COPY .gnupg /.gnupg

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/snapshot_script.bash"]
