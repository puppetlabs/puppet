require 'puppet/acceptance/common_utils'
require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::CAUtils
extend Puppet::Acceptance::TempFileUtils

initialize_temp_dirs

test_name "certificate extensions available as trusted data" do
  teardown do
    reset_agent_ssl
  end

  hostname = master.execute('facter hostname')
  fqdn = master.execute('facter fqdn')
  site_pp = get_test_file_path(master, "site.pp")
  master_config = {
    'master' => {
      'autosign' => '/bin/true',
      'dns_alt_names' => "puppet,#{hostname},#{fqdn}",
      'manifest' => site_pp,
      'trusted_node_data' => true,
    }
  }

  csr_attributes = YAML.dump({
    'extension_requests' => {
      # registered puppet extensions
      'pp_uuid' => 'b5e63090-5167-11e3-8f96-0800200c9a66',
      'pp_instance_id' => 'i-3fkva',
      # private (arbitrary) extensions
      '1.3.6.1.4.1.34380.1.2.1' => 'db-server', # node role
      '1.3.6.1.4.1.34380.1.2.2' => 'webops' # node group
    }
  })

  create_test_file(master, "site.pp", <<-SITE)
  file { "$test_dir/trusted.yaml":
    ensure => file,
    content => inline_template("<%= YAML.dump(@trusted) %>")
  }
  SITE

  reset_agent_ssl(false)
  with_puppet_running_on(master, master_config) do
    agents.each do |agent|
      next if agent == master

      agent_csr_attributes = get_test_file_path(agent, "csr_attributes.yaml")
      create_remote_file(agent, agent_csr_attributes, csr_attributes)

      on(agent, puppet("agent", "--test",
                       "--server", master,
                       "--waitforcert", 0,
                       "--csr_attributes", agent_csr_attributes,
                       "--certname #{agent}-extensions",
                       'ENV' => { "FACTER_test_dir" => get_test_file_path(agent, "") }),
        :acceptable_exit_codes => [0, 2])

      trusted_data = YAML.load(on(agent, "cat #{get_test_file_path(agent, 'trusted.yaml')}").stdout)

      assert_equal({
          'authenticated' => 'remote',
          'certname' => "#{agent}-extensions",
          'extensions' => {
            'pp_uuid' => 'b5e63090-5167-11e3-8f96-0800200c9a66',
            'pp_instance_id' => 'i-3fkva',
            '1.3.6.1.4.1.34380.1.2.1' => 'db-server',
            '1.3.6.1.4.1.34380.1.2.2' => 'webops'
          }
        },
        trusted_data)
    end
  end
end
