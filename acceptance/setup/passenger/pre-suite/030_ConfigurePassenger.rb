certname = on(master, puppet('master --configprint certname')).stdout.chomp

# workaround RE-4470
on(master, "cp /opt/puppetlabs/puppet/server/data/puppetmaster/config.ru /opt/puppetlabs/server/data/puppetmaster/config.ru")
on(master, "chown puppet:puppet /opt/puppetlabs/server/data/puppetmaster/config.ru")

if master['platform'] =~ /^el-|^fedora-/
  on(master, "sed -i 's|localhost|#{certname}|g' /etc/httpd/conf.d/puppet-passenger.conf")
else
  on(master, "sed -i 's|localhost|#{certname}|g' /etc/apache2/sites-available/puppet-passenger*")
  on(master, 'a2enmod headers')
  on(master, 'a2enmod ssl')
  on(master, 'a2ensite puppet-passenger')
end
