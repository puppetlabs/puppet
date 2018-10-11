{
  :type                        => 'git',
  :install                     => [
    'puppet',
  ],
  'is_puppetserver'            => true,
  'use-service'                => true, # use service scripts to start/stop stuff
  'puppetservice'              => 'puppetserver',
  'puppetserver-confdir'       => '/etc/puppetlabs/puppetserver/conf.d',
  'puppetserver-config'        => '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf',
  :pre_suite                   => [
    "setup/git/000_register_puppetres_dll.rb"
  ]
}
