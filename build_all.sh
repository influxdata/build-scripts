#!/bin/bash
# Declare an array of string with type
#("ubuntu" "i386/ubuntu:eoan-20200410" "arm32v7/ubuntu:eoan-20200410" "centos" "arm64v8/ubuntu:eoan-20200608")
declare -a TargetsArray=("arm64v8/ubuntu:eoan-20200608")
echo "Checking Docker installation"
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed. Install docker first. try "sudo apt install docker.io" or equivalent' >&2
  exit 1
else
  echo 'We have docker installed'
fi
#Iterate through TargetsArray
for val in ${TargetsArray[@]}; do
   echo "Starting $val Docker"
   docker pull $val
   if [ ! "$(docker ps -q -f name=$val)" ]; then
       if [ "$(docker ps -aq -f status=exited -f name=$val)" ]; then
           # cleanup
           docker rm $val
       fi
       cp influx_builder.sh ${PWD}/builds
# docker run -it --rm -v ${PWD}/builds:/mnt/builds $val /bin/bash
docker run -i --rm -v ${PWD}/builds:/mnt/builds $val /bin/bash << COMMANDS
rm -rf /mnt/builds/influxdb
cd /mnt/builds/
./influx_builder.sh
echo Changing owner from \$(id -u):\$(id -g) to $(id -u):$(id -u)
chown -R $(id -u):$(id -u) /mnt/builds
rm /mnt/builds/influx_builder.sh
COMMANDS
   fi
done
