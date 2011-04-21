# Puppet master fails to start due to impropper 
# permissons on the puppet/ dir.  Specially, the rrd 
# sub dir is not created when puppet master starts
 
test_name "Tickets 6734 6256 5530 5503i Puppet Master fails to start"

# Kill running Puppet Master
step "Check for running Puppet Master"
on master, "ps -ef | grep puppet"
  fail_test "Puppet Master not running" unless
    stdout.include? 'master'

step "Check permissions on puppet/rrd/"
on master, "ls -l /var/lib/puppet | grep rrd | awk '{print $3\" \"$4}'"
  fail_test "puppet/rrd does not exist/wrong permission" unless
    stdout.include? 'puppet puppet'
