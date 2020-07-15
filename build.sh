#!/bin/bash
# Declare an array of string with type
declare -a DefaultTargets=("ubuntu" "debian" "centos" "fedora")
declare -a x86Targets=("i386/ubuntu:eoan-20200410")
declare -a arm32Targets=("arm32v7/ubuntu:eoan-20200410")
declare -a arm64Targets=("arm64v8/ubuntu:eoan-20200608")
declare -a SupportedArchs=("amd64")
declare -a ChosenTargets=("")
interactive_flag=false
while getopts ":a:d:i" option; do
  case "${option}" in
    a )
       architectures="$OPTARG"
       ;;
    d ) distributions=("$OPTARG")
        until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
          distributions+=($(eval "echo \${$OPTIND}"))
          OPTIND=$((OPTIND + 1))
        done
        ;;
    i ) # "i" flag indicates interactive, drops you directly into bash prompt for each distribution
       interactive_flag=true
       ;;
  esac
done
if [ -z "$distributions" ]
then
 echo "No distributions specified, proceeding with default list"
 for d in "${DefaultTargets[@]}"
 do
   ChosenTargets+="$d"
   ChosenTargets+=" "
 done
else
  ## now loop through the above array
 for i in "${distributions[@]}"
 do
    for d in "${DefaultTargets[@]}"
    do
      if [ "$i" == "$d" ]; then
        ChosenTargets+="$d"
        ChosenTargets+=" "
      fi
    done
 done
fi
echo "Checking Docker installation"
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed. Install docker first. try "sudo apt install docker.io" or equivalent' >&2
  exit 1
else
  echo 'We have docker installed'
fi
#Iterate through TargetsArray
for val in ${ChosenTargets[@]}; do
   echo "Starting $val Docker"
   docker pull $val
   if [ ! "$(docker ps -q -f name=$val)" ]; then
       if [ "$(docker ps -aq -f status=exited -f name=$val)" ]; then
           # cleanup
           docker rm $val
       fi
       cp influx_builder.sh ${PWD}/builds

       target_logfile=$(echo $val | sed -e "s/[\\/\\:]/-/g").log
       if [ "$interactive_flag" = true ]
       then
docker run -it --rm -v ${PWD}/builds:/mnt/builds $val /bin/bash
       else
docker run -i --rm -v ${PWD}/builds:/mnt/builds $val /bin/bash << COMMANDS 2>&1 |tee ${PWD}/builds/${target_logfile}
rm -rf /mnt/builds/influxdb
cd /mnt/builds/
./influx_builder.sh
echo Changing owner from \$(id -u):\$(id -g) to $(id -u):$(id -u)
chown -R $(id -u):$(id -u) /mnt/builds
rm /mnt/builds/influx_builder.sh
COMMANDS
  fi
fi
done
