if options['is_puppetserver']
  master['use-service'] = true
  master['puppetservice'] = 'puppetserver'
  master['puppetserver-confdir'] = '/etc/puppetlabs/puppetserver/conf.d'
elsif master['platform'] =~ /^el-|^fedora-/
  master.uses_passenger!('httpd')
else
  master.uses_passenger!
end
