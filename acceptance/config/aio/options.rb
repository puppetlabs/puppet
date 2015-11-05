{
  :type => 'aio',
  :is_puppetserver => true,
  :puppetservice => 'puppetserver',
  :'puppetserver-confdir' => '/etc/puppetlabs/puppetserver/conf.d',
  :restart_when_done => false,
  :pre_suite => [
    'setup/common/pre-suite/000-delete-puppet-when-none.rb',
    'setup/aio/pre-suite/010_Install.rb',
    'setup/aio/pre-suite/015_PackageHostsPresets.rb',
    'setup/aio/pre-suite/020_InstallCumulusModules.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/aio/pre-suite/045_EnsureMasterStartedOnPassenger.rb',
    'setup/common/pre-suite/070_InstallCACerts.rb',
  ],
}
