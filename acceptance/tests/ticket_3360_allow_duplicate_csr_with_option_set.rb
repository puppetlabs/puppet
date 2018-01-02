test_name "#3360: Allow duplicate CSR when allow_duplicate_certs is on"

agent_hostnames = agents.map {|a| a.to_s}
tag 'audit:medium',  # CA functionality
    'audit:refactor', # Use block style `test_name`
    'audit:unit',
    'server'

with_puppet_running_on(master, {'master' => {'allow_duplicate_certs' => true,
                                             'autosign' => false}}) do
  agents_with_cert_name = {}
  agents.each do |agent|
    step "Collect fqdn for the agent"
    fqdn = on(agent, facter("fqdn")).stdout.strip
    agents_with_cert_name[fqdn] = agent
  end

  agents_with_cert_name.each do |fqdn, agent|
    step "Generate a certificate request for the agent"
    on(agent, puppet("certificate generate #{fqdn} --ca-location remote --server #{master}"))
  end

  step "Collect the original certs"
  on(master, puppet_cert("--sign --all"))
  original_certs = on(master, puppet_cert("--list --all"))

  old_certs = {}
  original_certs.stdout.each_line do |line|
    if line =~ /^\+ \"(\S+)\" \(?(.+)\)?$/ && agents_with_cert_name[$1]
      old_certs[$1] = $2
      puts "old cert: #{$1} #{$2}"
    end
  end

  assert_equal(agents.count, old_certs.count,
               "Expected original number of agent csrs on master to equal number of agents")

  agents_with_cert_name.each do |fqdn, agent|
    step "Make another request with the same certname"
    on(agent, puppet("certificate generate #{fqdn} --ca-location remote --server #{master}"))
  end

  step "Collect the new certs"
  on(master, puppet_cert("--sign --all"))
  new_cert_list = on(master, puppet_cert("--list --all"))

  new_certs = {}
  new_cert_list.stdout.each_line do |line|
    if line =~ /^\+ \"(\S+)\" \(?(.+)\)?$/ && agents_with_cert_name[$1]
      new_certs[$1] = $2
      puts "new cert: #{$1} #{$2}"
    end
  end

  assert_equal(agents.count, new_certs.count,
               "Expected new number of agent csrs on master to equal number of agents")

  # using the agent name as the key may cause errors;
  # agent name from cfg file is likely to have short name
  # where certs might be signed with long names.
  old_certs.each_key { |key|
    refute_equal(old_certs[key], new_certs[key], "Expected #{key} to have a changed key")
  }
end
