test_name 'C99578: hiera5 lookup config with interpolated scoped nested variables' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:medium',
    'audit:integration',
    'audit:refactor',  # This test specifically tests interpolation on the master.
                       # Recommend adding an additonal test that validates
                       # lookup in a masterless setup.
    'server'

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type + '1')
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"

  step "create environment hiera5.yaml and environment data" do

    create_remote_file(master, "#{fq_tmp_environmentpath}/hiera.yaml", <<-HIERA)
---
version: 5
defaults:
  datadir: 'hieradata'
  data_hash: yaml_data
hierarchy:
  - name: "Global settings"
    path: "global.yaml"
  - name: "Role specific settings"
    paths:
      - "roles/%{::roles.0}.yaml"
  - name: "Other Role specific settings"
    paths:
      - "roles/%{roles2.0}.yaml"
  - name: "scoped variable"
    paths:
      - "roles/%{::myclass::myvar.0}.yaml"
  - name: "nested hash variable"
    paths:
      - "roles/%{::hash_array.key1.0}.yaml"
    HIERA

    on(master, "mkdir -p #{fq_tmp_environmentpath}/hieradata/roles")
    create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/global.yaml", <<-YAML)
roles:
  - test1
roles2:
  - test2
data:
  - "from global"
    YAML

    create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/roles/test1.yaml", <<-YAML)
data:
  - 'from test1'
    YAML

    create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/roles/test2.yaml", <<-YAML)
data:
  - 'from test2'
    YAML

    create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/roles/test3.yaml", <<-YAML)
data:
  - 'from test3'
    YAML

    create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/roles/test4.yaml", <<-YAML)
data:
  - 'from test4'
    YAML

    create_sitepp(master, tmp_environment, <<-SITE)
class myclass {
  $myvar = ['test3']
}
include myclass

$hash_array = {key1 => ['test4']}

$roles = lookup('roles')
$data = lookup('data', Array[String], 'unique')
notify{"data: ${data}":}
$hiera_array_data = hiera_array('data')
notify{"hiera_array_data: ${hiera_array_data}":}

$roles2 = lookup('roles2')
$data2 = lookup('data', Array[String], 'unique')
notify{"data2: ${data2}":}
$hiera_array_data2 = hiera_array('data')
notify{"hiera_array_data2: ${hiera_array_data2}":}
    SITE

    on(master, "chmod -R 775 #{fq_tmp_environmentpath}")
  end

  with_puppet_running_on(master,{}) do
    agents.each do |agent|
      step "agent lookups: #{agent.hostname}, hiera5" do
        on(agent, puppet('agent', "-t --server #{master.hostname} --environment #{tmp_environment}"),
           :accept_all_exit_codes => true) do |result|
          assert(result.exit_code == 2, "agent lookup didn't exit properly: (#{result.exit_code})")
          assert_match(/data: \[from global, from test1/, result.stdout,
                       "agent lookup didn't interpolate with hiera value")
          assert_match(/hiera_array_data: \[from global, from test1/, result.stdout,
                       "agent hiera_array didn't interpolate with hiera value")

          assert_match(/data2: \[from global, from test1, from test2/, result.stdout,
                       "agent lookup didn't interpolate non-global scope with hiera value")
          assert_match(/hiera_array_data2: \[from global, from test1, from test2/, result.stdout,
                       "agent hiera_array didn't interpolate non-global scope with hiera value")

          assert_match(/data2: \[from global, from test1, from test2, from test3/, result.stdout,
                       "agent lookup didn't interpolate class scope with hiera value")
          assert_match(/hiera_array_data2: \[from global, from test1, from test2, from test3/, result.stdout,
                       "agent hiera_array didn't interpolate class scope with hiera value")

          assert_match(/data2: \[from global, from test1, from test2, from test3, from test4\]/, result.stdout,
                       "agent lookup didn't interpolate nested hashes with hiera value")
          assert_match(/hiera_array_data2: \[from global, from test1, from test2, from test3, from test4\]/, result.stdout,
                       "agent hiera_array didn't interpolate nested hashes with hiera value")
        end
      end
    end

  end

end
