#!/bin/bash

is_arm=0

#Distros vars
known_compatible_distros=(
                        "Kali"
                        "Parrot"
                        "Backbox"
                        "Blackarch"
                        "Cyborg"
                        "Ubuntu"
                        "Debian"
                        "SuSE"
                        "CentOS"
                        "Gentoo"
                        "Fedora"
                        "Red Hat"
                        "Arch"
                        "OpenMandriva"
                        "centos"
                    )

known_arm_compatible_distros=(
                        "Raspbian"
                        "Parrot arm"
                        "Kali arm"
                    )

#First phase of Linux distro detection based on uname output
function detect_distro_phase1() {

    for i in "${known_compatible_distros[@]}"; do
        uname -a | grep "${i}" -i > /dev/null
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

    detect_arm_architecture
}

#Detect if arm architecture is present on system
function detect_arm_architecture() {

    distro_already_known=0
    uname -m | grep -i "arm" > /dev/null

    if [[ "$?" = "0" ]] && [[ "${distro}" != "Unknown Linux" ]]; then

        for item in "${known_arm_compatible_distros[@]}"; do
            if [ "${distro}" = "${item}" ]; then
                distro_already_known=1
            fi
        done

        if [ ${distro_already_known} -eq 0 ]; then
            distro="${distro} arm"
            is_arm=1
        fi
    fi
}

detect_distro_phase1
detect_distro_phase2

echo "${distro}"
echo "${is_arm}"
