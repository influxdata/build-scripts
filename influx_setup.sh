#!/bin/bash

#Architecture vars
known_compatible_architectures=(
                        "X32"
                        "X64"
                        "ARM"
)
#Distros vars
known_compatible_distros=(
                        "DebianStable"
                        "DebianUnstable"
                        "UbuntuLTS"
                        "UbuntuStable"
                        "UbuntuDev"
                        "FedoraStable"
                        "FedoraDev"
                        "RHELStable"
                        "CentOS"
                    )

#First phase of Linux distro detection based on awk /etc/os-release output
function detect_distro_phase1() {
    echo "Performing Distro Detection"
    for i in "${known_compatible_distros[@]}"; do
        awk -F= '$1=="ID" { print $2 ;}' /etc/os-release | grep "${i}" -i > /dev/null
        if [ "$?" = "0" ]; then
            distro="${i^}"
            break
        fi
    done
}

#Second phase of Linux distro detection based on architecture and version file
function detect_distro_phase2() {
    if [ "${distro}" = "Unknown Linux" ]; then
        if [ -f ${osversionfile_dir}"centos-release" ]; then
            distro="CentOS"
          elif [ -f ${osversionfile_dir}"centos" ]; then
              distro="CentOS"
        elif [ -f ${osversionfile_dir}"fedora-release" ]; then
            distro="Fedora"
        elif [ -f ${osversionfile_dir}"gentoo-release" ]; then
            distro="Gentoo"
        elif [ -f ${osversionfile_dir}"openmandriva-release" ]; then
            distro="OpenMandriva"
        elif [ -f ${osversionfile_dir}"redhat-release" ]; then
            distro="Red Hat"
        elif [ -f ${osversionfile_dir}"SuSE-release" ]; then
            distro="SuSE"
        elif [ -f ${osversionfile_dir}"debian_version" ]; then
            distro="Debian"
            if [ -f ${osversionfile_dir}"os-release" ]; then
                extra_os_info=$(cat < ${osversionfile_dir}"os-release" | grep "PRETTY_NAME")
                if [[ "${extra_os_info}" =~ Raspbian ]]; then
                    distro="Raspbian"
                    is_arm=1
                elif [[ "${extra_os_info}" =~ Parrot ]]; then
                    distro="Parrot arm"
                    is_arm=1
                fi
            fi
        fi
    fi
    detect_architecture
}

#Detect if arm architecture is present on system
function detect_architecture() {
    arch=$(uname -i)
    if [ "$arch" == 'x86_64' ]; then
      echo "X64 Architecture"
    fi
    if [ "$arch" == 'x86_32' ]; then
      echo "X32 Architecture"
    fi
    if [ "$arch" == 'armv*' ]; then
      echo "ARM Architecture"
    fi
}
#add associated repository based on distro
function add_repo(){
  cat <<EOF | sudo tee /etc/yum.repos.d/influxdb.repo
[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key
EOF
}
#Add Service
function add_and_start_service(){
  echo "Installing Influx db"
  sudo yum install -y influxdb
  echo "Starting Service"
  sudo service influxdb start
}

detect_distro_phase1
detect_distro_phase2
add_repo
add_and_start_service


echo "${distro}"
echo "${is_arm}"
