test_name "node_name_fact should be used to determine the node name for puppet agent"

success_message = "node_name_fact setting was correctly used to determine the node name"

testdir = master.tmpdir("nodenamefact")
node_names = []

on agents, facter('kernel') do
  node_names << stdout.chomp
end

node_names.uniq!

authfile = "#{testdir}/auth.conf"
authconf = node_names.map do |node_name|
  %Q[
path /puppet/v3/catalog/#{node_name}
auth yes
allow *

path /puppet/v3/node/#{node_name}
auth yes
allow *

path /puppet/v3/report/#{node_name}
auth yes
allow *
]
end.join("\n")

manifest_file = "#{testdir}/environments/production/manifests/manifest.pp"
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

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode => '0777',
  }

  file {
    '#{testdir}':;
    '#{testdir}/environments':;
    '#{testdir}/environments/production':;
    '#{testdir}/environments/production/manifests':;
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
    'environmentpath' => "#{testdir}/environments",
  },
  'master' => {
    'rest_authconfig' => "#{testdir}/auth.conf",
    'node_terminus'   => 'plain',
  },
}

with_puppet_running_on master, with_these_opts, testdir do

  on(agents, puppet('agent', "--no-daemonize --verbose --onetime --node_name_fact kernel --server #{master}")) do
    assert_match(/defined 'message'.*#{success_message}/, stdout)
  end

end
