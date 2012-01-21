# Puppet master fails to start due to impropper 
# permissons on the puppet/ dir.  Specially, the rrd 
# sub dir is not created when puppet master starts
 
test_name "Tickets 6734 6256 5530 5503i Puppet Master fails to start"

with_master_running_on(master) do
  step "Check permissions on puppet/rrd/"
  on master, "ls -l /var/lib/puppet | grep rrd | awk '{print $3\" \"$4}'" do
    assert_match(/puppet puppet/, stdout, "puppet/rrd does not exist/wrong permissions")
  end
end
