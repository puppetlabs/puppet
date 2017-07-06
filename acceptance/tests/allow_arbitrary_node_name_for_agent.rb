test_name "node_name_value should be used as the node name for puppet agent"

success_message = "node_name_value setting was correctly used as the node name"
in_testdir = master.tmpdir('nodenamevalue')

authfile = "#{in_testdir}/auth.conf"
authconf = <<-AUTHCONF
path /puppet/v3/catalog/specified_node_name
auth yes
allow *

path /puppet/v3/node/specified_node_name
auth yes
allow *

path /puppet/v3/report/specified_node_name
auth yes
allow *
AUTHCONF

manifest_file = "#{in_testdir}/environments/production/manifests/manifest.pp"
manifest = <<-MANIFEST
  Exec { path => "/usr/bin:/bin" }
  node default {
    notify { "false": }
  }
  node specified_node_name {
    notify { "#{success_message}": }
  }
MANIFEST

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode => '0777',
  }

  file {
    '#{in_testdir}':;
    '#{in_testdir}/environments':;
    '#{in_testdir}/environments/production':;
    '#{in_testdir}/environments/production/manifests':;
  }

  file { '#{manifest_file}':
    ensure => file,
    mode => '0644',
    content => '#{manifest}',
  }

  file { '#{authfile}':
    ensure => file,
    mode => '0644',
    content => '#{authconf}',
  }
MANIFEST

with_these_opts = {
  'main' => {
    'environmentpath' => "#{in_testdir}/environments",
  },
  'master' => {
    'rest_authconfig' => "#{in_testdir}/auth.conf",
    'node_terminus'   => 'plain',
  },
}

with_puppet_running_on master, with_these_opts, in_testdir do

  on(agents, puppet('agent', "-t --node_name_value specified_node_name --server #{master}"), :acceptable_exit_codes => [0,2]) do
    assert_match(/defined 'message'.*#{success_message}/, stdout)
  end

end
