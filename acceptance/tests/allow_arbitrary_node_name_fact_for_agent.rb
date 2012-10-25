test_name "node_name_fact should be used to determine the node name for puppet agent"

success_message = "node_name_fact setting was correctly used to determine the node name"

node_names = []

on agents, facter('kernel') do
  node_names << stdout.chomp
end

node_names.uniq!

authfile = "/tmp/auth.conf-2128-#{$$}"
authconf = node_names.map do |node_name|
  %Q[
path /catalog/#{node_name}
auth yes
allow *

path /node/#{node_name}
auth yes
allow *
]
end.join("\n")

manifest_file = "/tmp/node_name_value-test-#{$$}.pp"
manifest = %Q[
  Exec { path => "/usr/bin:/bin" }
  node default {
    notify { "false": }
  }
]
manifest << node_names.map do |node_name|
  %Q[
    node "#{node_name}" {
      notify { "#{success_message}": }
    }
  ]
end.join("\n")

create_remote_file master, authfile, authconf
create_remote_file master, manifest_file, manifest

on master, "chmod 644 #{authfile} #{manifest_file}"

with_master_running_on(master, "--rest_authconfig #{authfile} --manifest #{manifest_file} --daemonize --dns_alt_names=\"puppet, $(facter hostname), $(facter fqdn)\" --autosign true") do
  run_agent_on(agents, "--no-daemonize --verbose --onetime --node_name_fact kernel --server #{master}") do
    assert_match(/defined 'message'.*#{success_message}/, stdout)
  end
end
