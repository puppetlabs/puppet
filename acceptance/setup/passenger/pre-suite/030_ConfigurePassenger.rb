certname = on(master, puppet('master --configprint certname')).stdout.chomp

if master['platform'] =~ /^el-|^fedora-/
  on(master, "sed -i 's|localhost|#{certname}|g' /etc/httpd/conf.d/puppet-passenger.conf")
else
  on(master, "sed -i 's|localhost|#{certname}|g' /etc/apache2/sites-available/puppet-passenger*")
  on(master, 'a2enmod headers')
  on(master, 'a2enmod ssl')
  on(master, 'a2ensite puppet-passenger')
end
