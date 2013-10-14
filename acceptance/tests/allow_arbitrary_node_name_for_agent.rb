test_name "node_name_value should be used as the node name for puppet agent"

success_message = "node_name_value setting was correctly used as the node name"
in_testdir = master.tmpdir('nodenamevalue')

authfile = "#{in_testdir}/auth.conf"
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

manifest_file = "#{in_testdir}/manifest.pp"
create_remote_file master, manifest_file, <<MANIFEST
  Exec { path => "/usr/bin:/bin" }
  node default {
    notify { "false": }
  }
  node specified_node_name {
    notify { "#{success_message}": }
  }
MANIFEST

on master, "chmod 644 #{authfile} #{manifest_file}"
on master, "chmod 777 #{in_testdir}"

with_these_opts = {
  'master' => {
    'rest_authconfig' => "#{in_testdir}/auth.conf",
    'node_terminus'   => 'plain',
    'manifest'        => manifest_file,
  }
}

with_puppet_running_on master, with_these_opts, in_testdir do

  on(agents, puppet('agent', "-t --node_name_value specified_node_name --server #{master}"), :acceptable_exit_codes => [0,2]) do
    assert_match(/defined 'message'.*#{success_message}/, stdout)
  end

end
