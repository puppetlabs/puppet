test_name "Can enumerate environments via an HTTP endpoint"

tag 'audit:high',
    'audit:integration',
    'server'

confine :except, :platform => /osx/ # see PUP-4820

def master_port(agent)
  setting_on(agent, "agent", "masterport")
end

def setting_on(host, section, name)
  on(host, puppet("config", "print", name, "--section", section)).stdout.chomp
end

def full_path(host, path)
  if host['platform'] =~ /win/
    on(host, "cygpath '#{path}'").stdout.chomp
  else
    path
  end
end

def curl_master_from(agent, path, headers = '', &block)
  url = "https://#{master}:#{master_port(agent)}#{path}"
  cert_path = full_path(agent, setting_on(agent, "agent", "hostcert"))
  key_path = full_path(agent, setting_on(agent, "agent", "hostprivkey"))
  curl_base = "curl --tlsv1 -sg --cert \"#{cert_path}\" --key \"#{key_path}\" -k -H '#{headers}'"

  on agent, "#{curl_base} '#{url}'", &block
end

master_user = puppet_config(master, 'user', section: 'master')
environments_dir = create_tmpdir_for_user master, "environments"
apply_manifest_on(master, <<-MANIFEST)
File {
  ensure => directory,
  owner => #{master_user},
  group => #{master.puppet['group']},
  mode => "0770",
}

file {
  "#{environments_dir}":;
  "#{environments_dir}/env1":;
  "#{environments_dir}/env2":;
}
MANIFEST

master_opts =  {
  :master => {
    :environmentpath => environments_dir
  }
}
if master.is_pe?
  master_opts[:master][:basemodulepath] = master['sitemoduledir']
end

with_puppet_running_on(master, master_opts) do
  step "Ensure that an unauthenticated client cannot access the environments list" do
    on master, "curl --tlsv1 -ksv https://#{master}:#{master_port(master)}/puppet/v3/environments", :acceptable_exit_codes => [0,7] do
      assert_match(/< HTTP\/1\.\d 403/, stderr)
    end
  end

  step "Ensure that an authenticated client can retrieve the list of environments" do
    curl_master_from(master, '/puppet/v3/environments') do
      data = JSON.parse(stdout)
      assert_equal(["env1", "env2", "production"], data["environments"].keys.sort)
    end
  end
end
