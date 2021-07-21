# `ext/` directory details 
This directory contains files used internally when packaging [puppet](https://github.com/puppetlabs/puppet) and [puppet-agent](https://github.com/puppetlabs/puppet-agent)
What follows is a more detailed description of each directory/file:
* `debian/` - init scripts for puppet (used for Debian-based platforms that do not support systemd)
* `hiera/hiera.yaml` - installed to `$codedir/environments/production`as a default Hiera configuration file
* `osx/puppet.plist` - puppet launchd plist for macOS
* `redhat/` -  init scripts for puppet (used for EL-based platforms that do not support systemd)
* `solaris/smf/` - service manifests for Solaris 11
* `suse/client.init` - init script for puppet (used for SUSE-based platforms that do not support systemd) 
* `systemd/puppet.service` - systemd unit file for puppet
* `windows/` - the puppet daemon for Windows, and other useful `.bat` helper wrappers
* `build_defaults.yaml` - information pertaining to the puppetlabs build automation
* `project_data.yaml` - information used when packaging the puppet gem