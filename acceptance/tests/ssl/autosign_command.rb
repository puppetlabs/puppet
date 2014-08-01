require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CAUtils

test_name "autosign command and csr attributes behavior (#7243,#7244)" do

  def assert_key_generated(name)
    assert_match(/Creating a new SSL key for #{name}/, stdout, "Expected agent to create a new SSL key for autosigning")
  end

  testdirs = {}
  step "generate tmp dirs on all hosts" do
    hosts.each { |host| testdirs[host] = host.tmpdir('autosign_command') }
  end

  teardown do
    step "Remove autosign configuration"
    testdirs.each do |host,testdir|
      on(host, host_command("rm -rf '#{testdir}'") )
    end
    reset_agent_ssl
  end

  hostname = master.execute('facter hostname')
  fqdn = master.execute('facter fqdn')

  reset_agent_ssl(false)

  step "Step 1: ensure autosign command can approve CSRs" do
    master_opts = {
      'master' => {
        'autosign' => '/bin/true',
        'dns_alt_names' => "puppet,#{hostname},#{fqdn}",
      }
    }
    with_puppet_running_on(master, master_opts) do
      agents.each do |agent|
        next if agent == master

        on(agent, puppet("agent --test --server #{master} --waitforcert 0 --certname #{agent}-autosign"))
        assert_key_generated(agent)
        assert_match(/Caching certificate for #{agent}/, stdout, "Expected certificate to be autosigned")
      end
    end
  end

  reset_agent_ssl(false)

  step "Step 2: ensure autosign command can reject CSRs" do
    master_opts = {
      'master' => {
        'autosign' => '/bin/false',
        'dns_alt_names' => "puppet,#{hostname},#{fqdn}",
      }
    }
    with_puppet_running_on(master, master_opts) do
      agents.each do |agent|
        next if agent == master

        on(agent, puppet("agent --test --server #{master} --waitforcert 0 --certname #{agent}-reject"), :acceptable_exit_codes => [1])
        assert_key_generated(agent)
        assert_match(/no certificate found/, stdout, "Expected certificate to not be autosigned")
      end
    end
  end

  autosign_inspect_csr_path = "#{testdirs[master]}/autosign_inspect_csr.rb"
  step "Step 3: setup an autosign command that inspects CSR attributes" do
    autosign_inspect_csr = <<-END
#!/usr/bin/env ruby
require 'openssl'

def unwrap_attr(attr)
  set = attr.value
  str = set.value.first
  str.value
end

csr_text = STDIN.read
csr = OpenSSL::X509::Request.new(csr_text)
passphrase = csr.attributes.find { |a| a.oid == '1.3.6.1.4.1.34380.2.1' }
# And here we jump hoops to unwrap ASN1's Attr Set Str
if unwrap_attr(passphrase) == 'my passphrase'
  exit 0
end
exit 1
    END
    create_remote_file(master, autosign_inspect_csr_path, autosign_inspect_csr)
    on master, "chmod 777 #{testdirs[master]}"
    on master, "chmod 777 #{autosign_inspect_csr_path}"
  end

  agent_csr_attributes = {}
  step "Step 4: create attributes for inclusion on csr on agents" do
    csr_attributes = <<-END
custom_attributes:
  1.3.6.1.4.1.34380.2.0: hostname.domain.com
  1.3.6.1.4.1.34380.2.1: my passphrase
  1.3.6.1.4.1.34380.2.2: # system IPs in hex
    - 0xC0A80001 # 192.168.0.1
    - 0xC0A80101 # 192.168.1.1
    END

    agents.each do |agent|
      agent_csr_attributes[agent] = "#{testdirs[agent]}/csr_attributes.yaml"
      create_remote_file(agent, agent_csr_attributes[agent], csr_attributes)
    end
  end

  reset_agent_ssl(false)

  step "Step 5: successfully obtain a cert" do
    master_opts = {
      'master' => {
        'autosign' => autosign_inspect_csr_path,
        'dns_alt_names' => "puppet,#{hostname},#{fqdn}",
      },
      :__commandline_args__ => '--debug --trace',
    }
    with_puppet_running_on(master, master_opts) do
      agents.each do |agent|
        next if agent == master

        step "attempting to obtain cert for #{agent}"
        on(agent, puppet("agent --test --server #{master} --waitforcert 0 --csr_attributes '#{agent_csr_attributes[agent]}' --certname #{agent}-attrs"), :acceptable_exit_codes => [0])
        assert_key_generated(agent)
      end
    end
  end
end
