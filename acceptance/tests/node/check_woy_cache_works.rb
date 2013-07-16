test_name "ticket #16753 node data should be cached in yaml to allow it to be queried"

require 'securerandom'
require 'puppet/acceptance/temp_file_utils'
require 'yaml'
extend Puppet::Acceptance::TempFileUtils

node_name = "woy_node_#{SecureRandom.hex}"
auth_contents = <<AUTHCONF
path /catalog/#{node_name}
auth yes
allow *

path /node/#{node_name}
auth yes
allow *
AUTHCONF

initialize_temp_dirs

create_test_file master, "auth.conf", auth_contents, {}

authfile = get_test_file_path master, "auth.conf"

on master, "chmod 644 #{authfile}"
with_master_running_on(master, "--rest_authconfig #{authfile} --daemonize --dns_alt_names=\"puppet, $(facter hostname), $(facter fqdn)\" --autosign true") do

  # only one agent is needed because we only care about the file written on the master
  run_agent_on(agents[0], "--no-daemonize --verbose --onetime --node_name_value #{node_name} --server #{master}")


  yamldir = on(master, puppet('master', '--configprint', 'yamldir')).stdout.chomp
  on master, puppet('node', 'search', '"*"', '--node_terminus', 'yaml', '--clientyamldir', yamldir, '--render-as', 'json') do
    assert_match(/"name":["\s]*#{node_name}/, stdout,
                 "Expect node name '#{node_name}' to be present in node yaml content written by the WriteOnlyYaml terminus")
  end
end
