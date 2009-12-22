#!/bin/bash
#
# Script to build an "old style" not flat pkg out of the puppet repository.
#
# Author: Nigel Kersten (nigelk@google.com)
#
# Last Updated: 2008-07-31
#
# Copyright 2008 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License


INSTALLRB="install.rb"
BINDIR="/usr/bin"
SBINDIR="/usr/sbin"
SITELIBDIR="/usr/lib/ruby/site_ruby/1.8"
PACKAGEMAKER="/Developer/usr/bin/packagemaker"
PROTO_PLIST="PackageInfo.plist"
PREFLIGHT="preflight"


function find_installer() {
  # we walk up three directories to make this executable from the root,
  # root/conf or root/conf/osx
  if [ -f "./${INSTALLRB}" ]; then
    installer="$(pwd)/${INSTALLRB}"
  elif [ -f "../${INSTALLRB}" ]; then
    installer="$(pwd)/../${INSTALLRB}"
  elif [ -f "../../${INSTALLRB}" ]; then
    installer="$(pwd)/../../${INSTALLRB}"
  else
    installer=""
  fi
}

function find_puppet_root() {
  puppet_root=$(dirname "${installer}")
}

function install_puppet() {
  echo "Installing Puppet to ${pkgroot}"
  "${installer}" --destdir="${pkgroot}" --bindir="${BINDIR}" --sbindir="${SBINDIR}" --sitelibdir="${SITELIBDIR}"
  chown -R root:admin "${pkgroot}"
}

function install_docs() {
  echo "Installing docs to ${pkgroot}"
  docdir="${pkgroot}/usr/share/doc/puppet" 
  mkdir -p "${docdir}"
  for docfile in CHANGELOG CHANGELOG.old COPYING LICENSE README README.queueing README.rst; do
    install -m 0644 "${puppet_root}/${docfile}" "${docdir}"
  done
  chown -R root:wheel "${docdir}"
  chmod 0755 "${docdir}"
}

function get_puppet_version() {
  puppet_version=$(RUBYLIB="${pkgroot}/${SITELIBDIR}:${RUBYLIB}" ruby -e "require 'puppet'; puts Puppet.version")
}

function prepare_package() {
  # As we can't specify to follow symlinks from the command line, we have
  # to go through the hassle of creating an Info.plist file for packagemaker
  # to look at for package creation and substitue the version strings out.
  # Major/Minor versions can only be integers, so we have "0" and "245" for
  # puppet version 0.24.5
  # Note too that for 10.5 compatibility this Info.plist *must* be set to
  # follow symlinks.
  VER1=$(echo ${puppet_version} | awk -F "." '{print $1}')
  VER2=$(echo ${puppet_version} | awk -F "." '{print $2}')
  VER3=$(echo ${puppet_version} | awk -F "." '{print $3}')
  major_version="${VER1}"
  minor_version="${VER2}${VER3}"
  cp "${puppet_root}/conf/osx/${PROTO_PLIST}" "${pkgtemp}"
  sed -i '' "s/{SHORTVERSION}/${puppet_version}/g" "${pkgtemp}/${PROTO_PLIST}"
  sed -i '' "s/{MAJORVERSION}/${major_version}/g" "${pkgtemp}/${PROTO_PLIST}"
  sed -i '' "s/{MINORVERSION}/${minor_version}/g" "${pkgtemp}/${PROTO_PLIST}"

  # We need to create a preflight script to remove traces of previous
  # puppet installs due to limitations in Apple's pkg format.
  mkdir "${pkgtemp}/scripts"
  cp "${puppet_root}/conf/osx/${PREFLIGHT}" "${pkgtemp}/scripts"

  # substitute in the sitelibdir specified above on the assumption that this
  # is where any previous puppet install exists that should be cleaned out.
  sed -i '' "s|{SITELIBDIR}|${SITELIBDIR}|g" "${pkgtemp}/scripts/${PREFLIGHT}"
  # substitute in the bindir sepcified on the assumption that this is where
  # any old executables that have moved from bindir->sbindir should be
  # cleaned out from.
  sed -i '' "s|{BINDIR}|${BINDIR}|g" "${pkgtemp}/scripts/${PREFLIGHT}"
  chmod 0755 "${pkgtemp}/scripts/${PREFLIGHT}"
}

function create_package() {
  rm -fr "$(pwd)/puppet-${puppet_version}.pkg"
  echo "Building package"
  echo "Note that packagemaker is reknowned for spurious errors. Don't panic."
  "${PACKAGEMAKER}" --root "${pkgroot}" \
                    --info "${pkgtemp}/${PROTO_PLIST}" \
                    --scripts ${pkgtemp}/scripts \
                    --out "$(pwd)/puppet-${puppet_version}.pkg"
  if [ $? -ne 0 ]; then
    echo "There was a problem building the package."
    cleanup_and_exit 1
    exit 1
  else
    echo "The package has been built at:"
    echo "$(pwd)/puppet-${puppet_version}.pkg"
  fi
}

function cleanup_and_exit() {
  if [ -d "${pkgroot}" ]; then
    rm -fr "${pkgroot}"
  fi
  if [ -d "${pkgtemp}" ]; then
    rm -fr "${pkgtemp}"
  fi
  exit $1
}

# Program entry point
function main() {

  if [ $(whoami) != "root" ]; then
    echo "This script needs to be run as root via su or sudo."
    cleanup_and_exit 1
  fi

  find_installer

  if [ ! "${installer}" ]; then
    echo "Unable to find ${INSTALLRB}"
    cleanup_and_exit 1
  fi

  find_puppet_root

  if [ ! "${puppet_root}" ]; then
    echo "Unable to find puppet repository root."
    cleanup_and_exit 1
  fi

  pkgroot=$(mktemp -d -t puppetpkg)

  if [ ! "${pkgroot}" ]; then
    echo "Unable to create temporary package root."
    cleanup_and_exit 1
  fi

  pkgtemp=$(mktemp -d -t puppettmp)

  if [ ! "${pkgtemp}" ]; then
    echo "Unable to create temporary package root."
    cleanup_and_exit 1
  fi

  install_puppet
  install_docs
  get_puppet_version

  if [ ! "${puppet_version}" ]; then
    echo "Unable to retrieve puppet version"
    cleanup_and_exit 1
  fi

  prepare_package
  create_package

  cleanup_and_exit 0
}

main "$@"
