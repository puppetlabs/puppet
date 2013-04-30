test_name "ENC still allows a node to override a topscope var"

testdir = master.tmpdir('scoping_deprecation')

create_remote_file(master, "#{testdir}/puppet.conf", <<END)
[main]
node_terminus = exec
external_nodes = "#{testdir}/enc"
manifest = "#{testdir}/site.pp"
modulepath = "#{testdir}/modules"
END

on master, "mkdir -p #{testdir}/modules/a/manifests"

create_remote_file(master, "#{testdir}/enc", <<-PP)
#!/usr/bin/env sh

cat <<END
---
classes:
  - a
parameters:
  enc_var: "Set from ENC."
END
exit 0
PP

agent_names = agents.map { |agent| "'#{agent.to_s}'" }.join(', ')
create_remote_file(master, "#{testdir}/site.pp", <<-PP)
$top_scope = "set from site.pp"
node default {
  $enc_var = "ENC overridden in default node."
}

node #{agent_names} inherits default {
  $top_scope = "top_scope overridden in agent node."
}
PP
create_remote_file(master, "#{testdir}/modules/a/manifests/init.pp", <<-PP)
class a {
  notify { "from enc": message => $enc_var }
  notify { "from site.pp": message => $top_scope }
}
PP

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"
on master, "chmod -R a+x #{testdir}/enc"

assert_log_on_master_contains = lambda do |string|
  on master, "grep '#{string}' #{testdir}/log"
end

assert_log_on_master_does_not_contain = lambda do |string|
  on master, "grep -v '#{string}' #{testdir}/log"
end

with_master_running_on(master, "--config #{testdir}/puppet.conf --debug --verbose --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do
  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --verbose --server #{master}")

    assert_match("top_scope overridden in agent node.", stdout)
    assert_match("ENC overridden in default node.", stdout)
  end
end

on master, "rm -rf #{testdir}"
