require 'puppet/acceptance/common_utils'
require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::CAUtils
extend Puppet::Acceptance::TempFileUtils
require 'puppet/acceptance/classifier_utils'
extend Puppet::Acceptance::ClassifierUtils

initialize_temp_dirs

test_name "certificate extensions available as trusted data" do
  confine :except, :platform => /^cisco_/ # See PUP-5827

  tag 'audit:high',        # ca/cert core functionality
      'audit:integration',
      'server'             # Ruby implimentation is deprecated

  agent_certnames = []

  teardown do
    step "Cleanup the test agent certs"
    agent_certnames.each do |cn|
      on(master, puppet("cert", "clean", cn), :acceptable_exit_codes => [0,24])
    end
  end

  hostname = master.execute('facter hostname')
  fqdn = master.execute('facter fqdn')
  environments_dir = get_test_file_path(master, "environments")
  master_config = {
    'main' => {
      'environmentpath' => environments_dir,
    },
    'master' => {
      'autosign' => true,
      'dns_alt_names' => "puppet,#{hostname},#{fqdn}",
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

  step "Generate a production environment manifest to dump trusted data"
  apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
    File {
      ensure => directory,
      mode => "0770",
      owner => #{master.puppet['user']},
      group => #{master.puppet['group']},
    }
    file {
      '#{environments_dir}':;
      '#{environments_dir}/production':;
      '#{environments_dir}/production/manifests':;
      '#{environments_dir}/production/manifests/site.pp':
        ensure => file,
        content => '
          file { "$test_dir/trusted.yaml":
            ensure => file,
            content => inline_template("<%= YAML.dump(@trusted) %>")
          }
          ',
        mode => "0640",
    }
  MANIFEST

  with_puppet_running_on(master, master_config) do
    agents.each do |agent|
      next if agent == master

      step "Create agent csr_attributes.yaml on #{agent}"
      agent_csr_attributes = get_test_file_path(agent, "csr_attributes.yaml")
      agent_ssldir = get_test_file_path(agent, "ssldir")
      create_remote_file(agent, agent_csr_attributes, csr_attributes)

      agent_certname = "#{agent}-extensions"
      agent_certnames << agent_certname

      step "Check in as #{agent_certname}"
      on(agent, puppet("agent", "--test",
                       "--server", master,
                       "--waitforcert", 0,
                       "--csr_attributes", agent_csr_attributes,
                       "--certname", agent_certname,
                       "--ssldir", agent_ssldir,
                       'ENV' => { "FACTER_test_dir" => get_test_file_path(agent, "") }),
        :acceptable_exit_codes => [0, 2])

      trusted_data = YAML.load(on(agent, "cat #{get_test_file_path(agent, 'trusted.yaml')}").stdout)
      agent_hostname, agent_domain = agent_certname.split('.', 2)

      step "Verify trusted data"
      assert_equal({
          'authenticated' => 'remote',
          'certname' => agent_certname,
          'extensions' => {
            'pp_uuid' => 'b5e63090-5167-11e3-8f96-0800200c9a66',
            'pp_instance_id' => 'i-3fkva',
            '1.3.6.1.4.1.34380.1.2.1' => 'db-server',
            '1.3.6.1.4.1.34380.1.2.2' => 'webops'
          },
          'hostname' => agent_hostname,
          'domain' => agent_domain
        },
        trusted_data)
    end
  end
end
