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
#Known Dependencies
known_deps=(
          "yarn"
          "protobuf"
          "bzr"
          "clang"
          "rust"
          "go"
)

go_fn_x86_64="go1.13.12.linux-amd64.tar.gz"
go_fn_x86="go1.13.12.linux-386.tar.gz"
go_fn_armv8="go1.13.12.linux-arm64.tar.gz"
go_fn_armv6="go1.13.12.linux-armv6l.tar.gz"
go_path="https://dl.google.com/go/"

selected_fn=""

#First phase of Linux distro detection based on awk /etc/os-release output
function detect_distro_phase() {
  #Handle docker missing lsb-release
  apt-get update && apt-get install -y lsb-release && apt-get clean all
  # Determine OS platform
  UNAME=$(uname | tr "[:upper:]" "[:lower:]")
  # If Linux, try to determine specific distribution
  if [ "$UNAME" == "linux" ]; then
      # If available, use LSB to identify distribution
      if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
          export DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'// | head -n1 | cut -d " " -f1)
      # Otherwise, use release info file
      else
          export DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1 | head -n1 | cut -d " " -f1)
      fi
  fi
  # For everything else (or if above failed), just use generic identifier
  [ "$DISTRO" == "" ] && export DISTRO=$UNAME
  unset UNAME
  detect_architecture
}
#Detect if arm architecture is present on system
function detect_architecture() {
    arch=$(uname -i)
    if [ "$arch" == 'x86_64' ]; then
      arch="X64"
      echo "X64 Architecture"
      selected_fn=${go_fn_x86_64}
    fi
    if [ "$arch" == 'x86_32' ]; then
      arch="X86"
      echo "X32 Architecture"
      selected_fn=${go_fn_x86}
    fi
    if [ "$arch" == 'armv*' ]; then
      arch="ARM"
      echo "ARM Architecture"
      selected_fn=${go_fn_armv6}
    fi
}
function setup_go(){
  echo "Getting GO Dependencies"
  curl -o ${selected_fn} ${go_path}${selected_fn}
  sudo chmod 775 ${selected_fn}
  sudo tar -C /usr/local -xzf ${selected_fn}
  export PATH=$PATH:/usr/local/go/bin
}
function_install_dep_mapper(){
  if [[ "$DISTRO" == *"Ubuntu"* ]]; then
    echo $DISTRO
    export T_TYPE="deb"
    install_dep_ubuntu
  fi
  if [[ "$DISTRO" == *"centos"* ]]; then
    echo $DISTRO
    export T_TYPE="rpm"
    install_dep_centos
  fi
}
function install_dep_ubuntu(){
  #This is to get proper yarn on Ubuntu
  apt-get install sudo apt-utils curl gnupg -y
  echo "Set disable_coredump false" >> /etc/sudo.conf
  sudo apt remove cmdtest -y
  sudo apt remove yarnpkg -y
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  sudo apt update && sudo apt install yarn -y
  yarn --version
  sudo apt-get install libclang-dev -y
  sudo apt -y install bzr protobuf-compiler yarnpkg
  sudo apt install git-all -y
  sudo apt-get install build-essential -y
  sudo apt-get install pkg-config -y
}
function install_dep_centos(){
  yum install sudo -y
  sudo yum install epel-release -y
  sudo yum repolist
  sudo yum install protobuf clang -y
  sudo yum groupinstall 'Development Tools' -y
  sudo dnf install @nodejs -y
  curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
  sudo rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg
  sudo dnf install yarn -y
  sudo dnf install git-all -y
  sudo yum install pkgconfig -y
}
function download_source(){
  echo "Getting Master Branch Source"
  rm -rf influxdb
  git clone https://github.com/influxdata/influxdb.git influxdb
  cd influxdb && BUILD_VERSION=$(git describe --tags) && BUILD_VERSION_SHORT=$(git describe --tags --abbrev=0) && cd ..
}
function setup_rust(){
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rust.sh && chmod +x rust.sh && ./rust.sh -y && export PATH=$PATH:$HOME/.cargo/bin && rm rust.sh
}
function make_project(){
  export GO111MODULE=on
  cd influxdb
  make && cd ..
}
function copy_files(){
  mkdir $DISTRO$arch
  cp -avr influxdb/bin/linux/. $DISTRO$arch
  rm ${selected_fn}
  sudo rm -rf influxdb
}
function packager(){
  echo $T_TYPE
  if [[ "$T_TYPE" == "deb" ]]; then
    package_deb
  else
    package_rpm
  fi
}
function package_deb(){
  cp -avr ${PWD}/templates/deb/ $DISTRO$arch/packages
  cp $DISTRO$arch/influxd $DISTRO$arch/packages/influxd/usr/bin
  INSTALL_SIZE=$(du -s $DISTRO$arch/packages/influxd/usr/bin | awk '{ print $1 }')
  sed -i "s/__VERSION__/${BUILD_VERSION:1}/g" $DISTRO$arch/packages/influxd/DEBIAN/control
  sed -i "s/__FILESIZE__/${INSTALL_SIZE}/g" $DISTRO$arch/packages/influxd/DEBIAN/control
  fakeroot dpkg-deb -b $DISTRO$arch/packages/influxd
  mv $DISTRO$arch/packages/influxd.deb $DISTRO$arch/packages/influxd-${BUILD_VERSION_SHORT}-${arch}.deb


}
function package_rpm(){
  echo "package rpm here"
}

detecter
detect_distro_phase
function_install_dep_mapper
#setup_go
download_source
#setup_rust
#make_project
#copy_files
packager
