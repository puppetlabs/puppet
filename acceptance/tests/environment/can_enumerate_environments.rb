test_name "Can enumerate environments via an HTTP endpoint"

def master_port(agent)
  setting_on(agent, "agent", "masterport")
end

def setting_on(host, section, name)
  on(host, puppet("config", "pring", name, "--section", section)).stdout.chomp
end

def curl_master_from(agent, path, headers = '', &block)
  url = "https://#{master}:#{master_port(agent)}#{path}"
  cert_path = setting_on(agent, "agent", "hostcert")
  key_path = setting_on(agent, "agent", "hostprivkey")
  curl_base = "curl -g --cert \"#{cert_path}\" --key \"#{key_path}\" -k -H '#{headers}'"

  on agent, "#{curl_base} '#{url}'", &block
end

with_puppet_running_on(master, {}) do
  agents.each do |agent|
    step "Ensure that an unauthenticated client cannot access the environments list" do
      on agent, "curl -ksv https://#{master}:#{master_port(agent)}/v2.0/environments", :acceptable_exit_codes => [0,7] do
        assert_match(/< HTTP\/1\.\d 403/, stderr)
      end
    end

    step "Ensure that an authenticated client can retrieve the list of environments" do
      curl_master_from(agent, '/v2.0/environments') do
        data = JSON.parse(stdout)
        assert_equal(["production"], data["environments"].keys)
      end
    end
  end
end
