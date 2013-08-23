test_name "#3360: Allow duplicate CSR when allow_duplicate_certs is on"

agent_hostnames = agents.map {|a| a.to_s}

with_puppet_running_on master, {'master' => {'allow_duplicate_certs' => true}} do
  agents.each do |agent|
    if agent['platform'].include?('windows')
      Log.warn("Pending: Windows does not support facter fqdn")
      next
    end

    step "Generate a certificate request for the agent"
    fqdn = on(agent, facter("fqdn")).stdout.strip
    on agent, "puppet certificate generate #{fqdn} --ca-location remote --server #{master}"
  end

  step "Collect the original certs"
  on master, puppet_cert("--sign --all")
  original_certs = on master, puppet_cert("--list --all")

  old_certs = {}
  original_certs.stdout.each_line do |line|
    if line =~ /^\+ (\S+) \((.+)\)$/
      old_certs[$1] = $2
      puts "old cert: #{$1} #{$2}"
    end
  end

  agents.each do |agent|
    if agent['platform'].include?('windows')
      Log.warn("Pending: Windows does not support facter fqdn")
      next
    end

    fqdn = on(agent, facter("fqdn")).stdout.strip
    step "Make another request with the same certname"
    on agent, "puppet certificate generate #{fqdn} --ca-location remote --server #{master}"
  end

  step "Collect the new certs"
  on master, puppet_cert("--sign --all")
  new_cert_list = on master, puppet_cert("--list --all")

  new_certs = {}
  new_cert_list.stdout.each_line do |line|
    if line =~ /^\+ (\S+) \((.+)\)$/
      new_certs[$1] = $2
      puts "new cert: #{$1} #{$2}"
    end
  end

  step "Verify the certs have changed"
  # using the agent name as the key may cause errors;
  # agent name from cfg file is likely to have short name
  # where certs might be signed with long names.
  old_certs.each_key { |key|
    next if key.include? master # skip the masters cert, only care about agents
    assert_not_equal(old_certs[key], new_certs[key], "Expected #{key} to have a changed key")
  }
end
