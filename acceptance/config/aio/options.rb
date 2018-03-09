{
  :type                        => 'aio',
  :pre_suite                   => [
    'setup/common/pre-suite/000-delete-puppet-when-none.rb',
    'setup/aio/pre-suite/010_Install.rb',
    'setup/aio/pre-suite/020_InstallCumulusModules.rb',
    'setup/aio/pre-suite/021_InstallAristaModule.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/common/pre-suite/030_StopSssd.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/aio/pre-suite/045_EnsureMasterStarted.rb',
  ],
  'is_puppetserver'            => true,
  'use-service'                => true, # use service scripts to start/stop stuff
  'puppetservice'              => 'puppetserver',
  'puppetserver-confdir'       => '/etc/puppetlabs/puppetserver/conf.d',
  'puppetserver-config'        => '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf'
}
