require 'securerandom'
require 'puppet/acceptance/temp_file_utils'
require 'yaml'
extend Puppet::Acceptance::TempFileUtils

test_name "ticket #16753 node data should be cached in yaml to allow it to be queried"

tag 'audit:medium',
    'audit:integration',
    'server'

node_name = "woy_node_#{SecureRandom.hex}"

# Only used when running under webrick
authfile = get_test_file_path master, "auth.conf"

temp_dirs = initialize_temp_dirs
temp_yamldir = File.join(temp_dirs[master.name], "yamldir")

on master, "mkdir -p #{temp_yamldir}"
user = puppet_user master
group = puppet_group master
on master, "chown #{user}:#{group} #{temp_yamldir}"

if @options[:is_puppetserver]
  step "Prepare for custom tk-auth rules" do
    on master, 'cp /etc/puppetlabs/puppetserver/conf.d/auth.conf /etc/puppetlabs/puppetserver/conf.d/auth.bak'
    modify_tk_config(master, options['puppetserver-config'], {'jruby-puppet' => {'use-legacy-auth-conf' => false}})
  end

  teardown do
    modify_tk_config(master, options['puppetserver-config'], {'jruby-puppet' => {'use-legacy-auth-conf' => true}})
    on master, 'cp /etc/puppetlabs/puppetserver/conf.d/auth.bak /etc/puppetlabs/puppetserver/conf.d/auth.conf'
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
                path: "/puppet/v3/catalog/#{node_name}"
                type: path
                method: [get, post]
            }
            allow: "*"
            sort-order: 500
            name: "puppetlabs catalog"
        },
        {
            match-request: {
                path: "/puppet/v3/node/#{node_name}"
                type: path
                method: get
            }
            allow: "*"
            sort-order: 500
            name: "puppetlabs node"
        },
        {
            match-request: {
                path: "/puppet/v3/report/#{node_name}"
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
  step "setup legacy auth.conf rules" do
    auth_contents = <<-AUTHCONF
path /puppet/v3/catalog/#{node_name}
auth yes
allow *

path /puppet/v3/node/#{node_name}
auth yes
allow *

path /puppet/v3/report/#{node_name}
auth yes
allow *
    AUTHCONF

    create_test_file master, "auth.conf", auth_contents, {}

    on master, "chmod 644 #{authfile}"
  end
end

master_opts = {
  'master' => {
    'rest_authconfig' => authfile,
    'yamldir' => temp_yamldir,
    'node_cache_terminus' => 'write_only_yaml',
  }
}

with_puppet_running_on master, master_opts do

  # only one agent is needed because we only care about the file written on the master
  run_agent_on(agents[0], "--no-daemonize --verbose --onetime --node_name_value #{node_name} --server #{master}")

  yamldir = puppet_config(master, 'yamldir', section: 'master')
  on master, puppet('node', 'search', '"*"', '--node_terminus', 'yaml', '--clientyamldir', yamldir, '--render-as', 'json') do
    assert_match(/"name":["\s]*#{node_name}/, stdout,
                 "Expect node name '#{node_name}' to be present in node yaml content written by the WriteOnlyYaml terminus")
  end
end
