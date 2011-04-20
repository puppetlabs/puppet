test_name "#3360: Allow duplicate CSR when allow_duplicate_certs is on"

agent_hostnames = agents.map {|a| a.to_s}

# Kill running Puppet Master -- should not be running at this point
step "Master: kill running Puppet Master"
on master, "ps -U puppet | awk '/puppet/ { print \$1 }' | xargs kill || echo \"Puppet Master not running\""

step "Master: Start Puppet Master"
on master, puppet_master("--allow_duplicate_certs --certdnsnames=\"puppet:$(hostname -s):$(hostname -f)\" --verbose --noop")

step "Generate a certificate request for the agent"
on agents, "puppet certificate generate `hostname -f` --ca-location remote --server #{master}"

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

step "Make another request with the same certname"
on agents, "puppet certificate generate `hostname -f` --ca-location remote --server #{master}"

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
  fail_test("#{key} does not have a new signed certificate") if old_certs[key] == new_certs[key]
}
