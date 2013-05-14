require 'puppet/acceptance/config_utils'
extend Puppet::Acceptance::ConfigUtils

test_name "node_name_value should be used as the node name for puppet agent"

success_message = "node_name_value setting was correctly used as the node name"
testdir = master.tmpdir('nodenamevalue')

authfile = "#{testdir}/auth.conf"
create_remote_file master, authfile, <<AUTHCONF
path /catalog/specified_node_name
auth yes
allow *

path /node/specified_node_name
auth yes
allow *

path /report/specified_node_name
auth yes
allow *
AUTHCONF

manifest_file = "#{testdir}/manifest.pp"
create_remote_file master, manifest_file, <<MANIFEST
  Exec { path => "/usr/bin:/bin" }
  node default {
    notify { "false": }
  }
  node specified_node_name {
    notify { "#{success_message}": }
  }
MANIFEST

puppetconf_file = "#{testdir}/puppet.conf"
puppetconf = puppet_conf_for( master )
puppetconf['master']['rest_authconfig'] = "#{testdir}/auth.conf"
puppetconf['master'].delete('node_terminus')
puppetconf['master']['manifest'] = manifest_file
create_remote_file master, puppetconf_file, puppetconf.to_s

on master, "chmod 644 #{authfile} #{manifest_file} #{puppetconf_file}"
on master, "chmod 777 #{testdir}"

on master, "cp #{master['puppetpath']}/puppet.conf #{master['puppetpath']}/puppet.conf.bak"
on master, "cp #{testdir}/puppet.conf #{master['puppetpath']}/puppet.conf"
on master, '/etc/init.d/pe-httpd restart'

with_puppet_running_on master, testdir do

  run_agent_on(agents, "--no-daemonize --verbose --onetime --node_name_value specified_node_name --server #{master}") do
    assert_match(/defined 'message'.*#{success_message}/, stdout)
  end

end
