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
#Packages
package_depdencies=(
                      "Test"
)
go_fn="go1.13.12.linux-amd64.tar.gz"
go_path="https://dl.google.com/go/${go_fn}"


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
function setup_go(){
  echo "Getting GO Dependencies"
  curl -o ${go_fn} ${go_path}
  sudo chmod 775 ${go_fn}
  sudo tar -C /usr/local -xzf ${go_fn}
  export PATH=$PATH:/usr/local/go/bin
}
function install_dep(){
  #This is to get proper yarn on Ubuntu
  sudo apt remove cmdtest -y
  sudo apt remove yarnpkg -y
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  sudo apt update && sudo apt install yarn
  ##
  #This gets libclang dev for ubuntu/debian_version
  sudo apt-get install libclang-dev -y
  ##

  #Here is where we would get CentOS/RHL/FedoraDev
  #sudo yum install clang  # Or replace `yum` with `dnf`
  #
  sudo apt -y install bzr protobuf-compiler yarnpkg
}
function download_source(){
  echo "Getting Master Branch Source"
  rm -rf influxdb
  git clone https://github.com/influxdata/influxdb.git influxdb
}
function setup_rust(){
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rust.sh && chmod +x rust.sh && ./rust.sh -y && export PATH=$PATH:$HOME/.cargo/bin && rm rust.sh
}
function make_project(){
  export GO111MODULE=on
  cd influxdb
  make
}


detect_distro_phase1
detect_distro_phase2
setup_go
install_dep
download_source
setup_rust
make_project
