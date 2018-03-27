{
  :type                        => 'aio',
  'is_puppetserver'            => true,
  'use-service'                => true, # use service scripts to start/stop stuff
  'puppetservice'              => 'puppetserver',
  'puppetserver-confdir'       => '/etc/puppetlabs/puppetserver/conf.d',
  'puppetserver-config'        => '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf'
}
