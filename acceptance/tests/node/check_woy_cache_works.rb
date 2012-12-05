test_name "ticket #16753 node data should be cached in yaml to allow it to be queried"

require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils

authfile = "/tmp/auth.conf-2128-#{$$}"
create_remote_file master, authfile, <<AUTHCONF
path /catalog/woy_node_name
auth yes
allow *

path /node/woy_node_name
auth yes
allow *
AUTHCONF

on master, "chmod 644 #{authfile}"
# This runs one agent, and checks that the data is written in yaml where expected
with_master_running_on(master, "--rest_authconfig #{authfile} --daemonize --dns_alt_names=\"puppet, $(facter hostname), $(facter fqdn)\" --autosign true") do
  run_agent_on(agents[0], "--no-daemonize --verbose --onetime  --node_name_value woy_node_name --server #{master}") do
    # Only check that the file is actually there
    # Could be paranoid and also check that it is valid yaml for the node in question
    #
    assert(file_exists?(master, "#{master["puppetvardir"]}/yaml/node/woy_node_name.yaml"))
  end
end
