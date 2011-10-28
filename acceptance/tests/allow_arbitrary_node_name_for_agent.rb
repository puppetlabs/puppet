test_name "node_name_value should be used as the node name for puppet agent"

success_message = "node_name_value setting was correctly used as the node name"

authfile = "/tmp/auth.conf-2128-#{$$}"
create_remote_file master, authfile, <<AUTHCONF
path /catalog/specified_node_name
auth yes
allow *
AUTHCONF

manifest_file = "/tmp/node_name_value-test-#{$$}.pp"
create_remote_file master, manifest_file, <<MANIFEST
  Exec { path => "/usr/bin:/bin" }
  node default {
    exec { "false": }
  }
  node specified_node_name {
    exec { "echo #{success_message}": }
  }
MANIFEST

on master, "chmod 644 #{authfile} #{manifest_file}"

on hosts, "rm -rf /etc/puppet/ssl"

with_master_running_on(master, "--rest_authconfig #{authfile} --manifest #{manifest_file} --daemonize --dns_alt_names=\"puppet, $(hostname -s), $(hostname -f)\" --autosign true") do
  run_agent_on(agents, "--no-daemonize --verbose --onetime --node_name_value specified_node_name --server #{master}") do
    assert_match(success_message, stdout)
  end
end
