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
  sudo yum install redhat-lsb-core -y
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
    echo $arch
    longbit=$(getconf LONG_BIT)
    if [ "$arch" == 'x86_64' ]; then
      if [ "$longbit" = '32' ]; then
        arch="i386"
        echo "X32 Architecture"
        selected_fn=${go_fn_x86}
      else
        arch="amd64"
        echo "X64 Architecture"
        selected_fn=${go_fn_x86_64}
      fi
    fi
    if [ "$arch" == 'x86_32' ]; then
      arch="i386"
      echo "X32 Architecture"
      selected_fn=${go_fn_x86}
    fi
    if [ "$arch" == 'armv7l' ]; then
      arch="ARM"
      echo "ARM Architecture"
      selected_fn=${go_fn_armv6}
    fi
    if [ "$arch" == 'aarch64' ]; then
      arch="ARM64"
      echo "ARM Architecture"
      selected_fn=${go_fn_armv8}
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
  echo $DISTRO
  if [[ "$DISTRO" == *"Ubuntu"* ]]; then
    echo $DISTRO
    export T_TYPE="deb"
    install_dep_ubuntu
  fi
  if [[ "$DISTRO" == *"centos"* ]] || [[ "$DISTRO" == *"fedora"* ]] || [[ "$DISTRO" == *"RedHatEnterprise"* ]] ; then
    echo $DISTRO
    export T_TYPE="rpm"
    install_dep_centos
  fi
}
function install_dep_ubuntu(){
  export DEBIAN_FRONTEND=noninteractive
  ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
  apt-get install -y tzdata
  dpkg-reconfigure --frontend noninteractive tzdata
  apt-get install sudo apt-utils curl gnupg -y
  echo "Set disable_coredump false" >> /etc/sudo.conf
  sudo apt remove cmdtest -y
  sudo apt remove yarnpkg -y
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  sudo apt update && sudo apt install yarn -y
  sudo apt-get install libclang-dev -y
  sudo apt -y install bzr protobuf-compiler yarnpkg
  sudo apt install git-all -y
  sudo apt-get install build-essential -y
  sudo apt-get install pkg-config -y
  sudo apt purge nodejs npm -y
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
  source ~/.nvm/nvm.sh
  nvm install node
  npm install -g yarn
}
function install_dep_centos(){
  yum install sudo -y
  sudo yum install epel-release -y
  sudo yum repolist
  sudo yum install protobuf clang protobuf-devel -y
  if [[ "$DISTRO" == *"RedHatEnterprise"* ]] ; then
    PROTOC_ZIP=protoc-3.7.1-linux-x86_64.zip
    curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.7.1/$PROTOC_ZIP
    sudo unzip -o $PROTOC_ZIP -d /usr/local bin/protoc
    sudo unzip -o $PROTOC_ZIP -d /usr/local 'include/*'
    rm -f $PROTOC_ZIP
  fi
  sudo yum groupinstall 'Development Tools' -y
  sudo dnf install @nodejs -y
  curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
  sudo rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg
  sudo dnf install yarn -y
  sudo dnf install git-all -y
  sudo yum install pkgconfig -y
  yum info epel-release -y
  sudo yum install epel-release -y
  sudo yum config-manager --set-enabled PowerTools
  sudo yum update -y
  sudo yum install protobuf-devel -y
  sudo yum install ruby-devel -y
  sudo dnf install ruby-devel gcc make rpm-build libffi-devel -y
  sudo gem install fpm
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
  find . -name 'node_modules' -type d -prune -print -exec rm -rf '{}' \;
  make
  if [ "$?" != "0" ]; then
      echo "Build failed for ${DISTRO}_${arch}"
      exit 1
  fi
  cd ..
}
function copy_files(){
  echo "Creating packaging directory for ${DISTRO}_${arch}"
  sudo rm -rf ${DISTRO}_${arch}
  mkdir ${DISTRO}_${arch}
  cp -avr influxdb/bin/linux/. ${DISTRO}_${arch}
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
  cp -avr ${PWD}/templates/deb/ ${DISTRO}_${arch}/packages

  mkdir -p ${DISTRO}_${arch}/packages/influxd/usr/bin
  mkdir -p ${DISTRO}_${arch}/packages/influx/usr/bin
  cp ${DISTRO}_${arch}/influxd ${DISTRO}_${arch}/packages/influxd/usr/bin/influxd
  cp ${DISTRO}_${arch}/influx ${DISTRO}_${arch}/packages/influx/usr/bin/influx
  sudo chmod -R 755 ${DISTRO}_${arch}

  INSTALL_SIZE=$(du -s ${DISTRO}_${arch}/packages/influxd/usr/bin | awk '{ print $1 }')
  sed -i "s/__VERSION__/${BUILD_VERSION:1}/g" ${DISTRO}_${arch}/packages/influxd/DEBIAN/control
  sed -i "s/__FILESIZE__/${INSTALL_SIZE}/g" ${DISTRO}_${arch}/packages/influxd/DEBIAN/control
  fakeroot dpkg-deb -b ${DISTRO}_${arch}/packages/influxd

  INSTALL_SIZE=$(du -s ${DISTRO}_${arch}/packages/influx/usr/bin/influx | awk '{ print $1 }')
  sed -i "s/__VERSION__/${BUILD_VERSION:1}/g" ${DISTRO}_${arch}/packages/influx/DEBIAN/control
  sed -i "s/__FILESIZE__/${INSTALL_SIZE}/g" ${DISTRO}_${arch}/packages/influx/DEBIAN/control
  fakeroot dpkg-deb -b ${DISTRO}_${arch}/packages/influx


  mv ${DISTRO}_${arch}/packages/influxd.deb ${DISTRO}_${arch}/packages/influxdb_${BUILD_VERSION_SHORT}_${arch}.deb
  mv ${DISTRO}_${arch}/packages/influx.deb ${DISTRO}_${arch}/packages/influxdb-client_${BUILD_VERSION_SHORT}_${arch}.deb
}
function package_rpm(){
  cp -avr ${PWD}/templates/rpm/ ${DISTRO}_${arch}/packages
  mkdir -p "${DISTRO}_${arch}/packages/influxd/usr/bin" \
         "${DISTRO}_${arch}/packages/influxd/var/log/influxdb" \
         "${DISTRO}_${arch}/packages/influxd/var/lib/influxdb" \
         "${DISTRO}_${arch}/packages/influxd/usr/lib/influxdb/scripts" \
         "${DISTRO}_${arch}/packages/influxd/etc/influxdb" \
         "${DISTRO}_${arch}/packages/influxd/etc/logrotate.d" \
         "${DISTRO}_${arch}/packages/influxd/usr/lib/influxdb/scripts/"
  cp ${DISTRO}_${arch}/influxd ${DISTRO}_${arch}/packages/influxd/usr/bin/influxd
  chmod -R 0755 ${DISTRO}_${arch}
  cp ${DISTRO}_${arch}/packages/scripts/logrotate ${DISTRO}_${arch}/packages/influxd/etc/logrotate.d

  # Copy service scripts.
  cp ${DISTRO}_${arch}/packages/scripts/init.sh "${DISTRO}_${arch}/packages/influxd/usr/lib/influxdb/scripts/init.sh"
  chmod 0644 "${DISTRO}_${arch}/packages/influxd/usr/lib/influxdb/scripts/init.sh"
  cp ${DISTRO}_${arch}/packages/scripts/influxdb.service "${DISTRO}_${arch}/packages/influxd/usr/lib/influxdb/scripts/influxdb.service"
  chmod 0644 "${DISTRO}_${arch}/packages/influxd/usr/lib/influxdb/scripts/influxdb.service"

  # Copy logrotate script.
  cp ${DISTRO}_${arch}/packages/scripts/logrotate "${DISTRO}_${arch}/packages/influxd/etc/logrotate.d/influxdb"
  chmod 0644 "${DISTRO}_${arch}/packages/influxd/etc/logrotate.d/influxdb"


  for typeargs in "-t rpm --depends coreutils --depends shadow-utils"; do
    FPM_NAME=$(
      fpm \
        -s dir \
        $typeargs \
        --log error \
        --vendor InfluxData \
        --url "https://influxdata.com" \
        --after-install ${DISTRO}_${arch}/packages/scripts/post-install.sh \
        --before-install ${DISTRO}_${arch}/packages/scripts/pre-install.sh \
        --after-remove ${DISTRO}_${arch}/packages/scripts/post-uninstall.sh \
        --license Proprietary \
        --maintainer "support@influxdb.com" \
        --directories /var/log/influxdb \
        --directories /var/lib/influxdb \
        --rpm-attr 755,influxdb,influxdb:/var/log/influxdb \
        --rpm-attr 755,influxdb,influxdb:/var/lib/influxdb \
        --description 'Distributed time-series database.' \
        --name "influxdb" \
        --architecture "${arch}" \
        --version "${BUILD_VERSION_SHORT}" \
        --iteration 1 \
        -C "${DISTRO}_${arch}"/packages/influxd \
        -p "${DISTRO}_${arch}"/packages/influxd/output \
         | ruby -e 'puts (eval ARGF.read)[:path]' )

        echo "fpm created $FPM_NAME"
        NEW_NAME=influxdb_${BUILD_VERSION_SHORT}_${arch}.rpm
        echo "renaming to ${NEW_NAME}"
        mv "${FPM_NAME}" "${DISTRO}_${arch}/packages/${NEW_NAME}"
    done
}
function cleanup(){
  #Cleanup
  echo "cleanup"
}
detect_distro_phase
function_install_dep_mapper
setup_go
download_source
setup_rust
make_project
copy_files
packager
cleanup
