test_name "node_name_value should be used as the node name for puppet agent"

tag 'audit:medium',
    'audit:integration',  # Tests that the server properly overrides certname with node_name fact.
                          # Testing of passenger master is no longer needed.
    'server'

success_message = "node_name_value setting was correctly used as the node name"
testdir = master.tmpdir('nodenamevalue')

if @options[:is_puppetserver]
  step "Prepare for custom tk-auth rules" do
    on master, 'cp /etc/puppetlabs/puppetserver/conf.d/auth.conf /etc/puppetlabs/puppetserver/conf.d/auth.bak'
    modify_tk_config(master, options['puppetserver-config'], {'jruby-puppet' => {'use-legacy-auth-conf' => false}})
  end

  teardown do
    on master, 'cp /etc/puppetlabs/puppetserver/conf.d/auth.bak /etc/puppetlabs/puppetserver/conf.d/auth.conf'
    modify_tk_config(master, options['puppetserver-config'], {'jruby-puppet' => {'use-legacy-auth-conf' => true}})
  end

  step "Setup tk-auth rules" do
    tk_auth = <<-TK_AUTH
authorization: {
    version: 1
    rules: [
        {
            match-request: {
                path: "/puppet/v3/file"
                type: path
            }
            allow: "*"
            sort-order: 500
            name: "puppetlabs file"
        },
        {
            match-request: {
                path: "/puppet/v3/catalog/specified_node_name"
                type: path
                method: [get, post]
            }
            allow: "*"
            sort-order: 500
            name: "puppetlabs catalog"
        },
        {
            match-request: {
                path: "/puppet/v3/node/specified_node_name"
                type: path
                method: get
            }
            allow: "*"
            sort-order: 500
            name: "puppetlabs node"
        },
        {
            match-request: {
                path: "/puppet/v3/report/specified_node_name"
                type: path
                method: put
            }
            allow: "*"
            sort-order: 500
            name: "puppetlabs report"
        },
        {
          match-request: {
            path: "/"
            type: path
          }
          deny: "*"
          sort-order: 999
          name: "puppetlabs deny all"
        }
    ]
}
    TK_AUTH

    apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
      file { '/etc/puppetlabs/puppetserver/conf.d/auth.conf':
        ensure => file,
        mode => '0644',
        content => '#{tk_auth}',
      }
    MANIFEST
  end
else
  step "setup auth.conf rules" do
    authfile = "#{testdir}/auth.conf"
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

    apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
      file { '#{authfile}':
        ensure => file,
        mode => '0644',
        content => '#{authconf}',
      }
    MANIFEST
  end
end

step "Setup site.pp for node name based classification" do

  site_manifest = <<-SITE_MANIFEST
node default {
  notify { "false": }
}
node specified_node_name {
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
    on(agents, puppet('agent', "-t --node_name_value specified_node_name --server #{master}"), :acceptable_exit_codes => [0,2]) do
      assert_match(/defined 'message'.*#{success_message}/, stdout)
    end
  end
end
