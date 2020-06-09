#!/bin/bash
# Declare an array of string with type
declare -a TargetsArray=("ubuntu" "centos")
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
       docker run -v $PWD:/scripts $val /bin/bash -c "/scripts/influx_builder.sh"
   fi
done
# echo "Starting OpenFace Docker"
# if [ ! "$(docker ps -q -f name=bamos/openface)" ]; then
#     if [ "$(docker ps -aq -f status=exited -f name=bamos/openface)" ]; then
#         # cleanup
#         docker rm bamos/openface
#     fi
#     docker run -v $PWD:/scripts centos /bin/bash -c "/scripts/influx_setup.sh"
# fi
