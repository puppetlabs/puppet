test_name "node_name_fact should be used to determine the node name for puppet agent"

success_message = "node_name_fact setting was correctly used to determine the node name"

testdir = master.tmpdir("nodenamefact")
node_names = []

on agents, facter('kernel') do
  node_names << stdout.chomp
end

node_names.uniq!

step "Setup auth.conf" do
  authfile = "#{testdir}/auth.conf"
  authconf = node_names.map do |node_name|
    <<-MANIFEST
path /puppet/v3/catalog/#{node_name}
auth yes
allow *

path /puppet/v3/node/#{node_name}
auth yes
allow *

path /puppet/v3/report/#{node_name}
auth yes
allow *
    MANIFEST
  end.join("\n")

  apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  file { '#{authfile}':
    ensure => file,
    mode => '0644',
    content => '#{authconf}',
  }
  MANIFEST
end

step "Setup site.pp for node name based classification" do

  site_manifest = <<-SITE_MANIFEST
node default {
  notify { "false": }
}

node #{node_names.map { |name| %Q["#{name}"] }.join(", ")} {
  notify { "#{success_message}": }
}
SITE_MANIFEST

  apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
    $directories = [
      '#{testdir}',
      '#{testdir}/environments',
      '#{testdir}/environments/production',
      '#{testdir}/environments/production/manifests',
    ]

    file { $directories:
      ensure => directory,
      mode => '0755',
    }

    file { '#{testdir}/environments/production/manifests/manifest.pp':
      ensure => file,
      mode => '0644',
      content => '#{site_manifest}',
    }
  MANIFEST
end

step "Ensure nodes are classified based on the node name fact" do
  master_opts = {
    'main' => {
      'environmentpath' => "#{testdir}/environments",
    },
    'master' => {
      'rest_authconfig' => "#{testdir}/auth.conf",
      'node_terminus'   => 'plain',
    },
  }

  with_puppet_running_on(master, master_opts, testdir) do
    on(agents, puppet('agent', "--no-daemonize --verbose --onetime --node_name_fact kernel --server #{master}")) do
      assert_match(/defined 'message'.*#{success_message}/, stdout)
    end
  end
end
