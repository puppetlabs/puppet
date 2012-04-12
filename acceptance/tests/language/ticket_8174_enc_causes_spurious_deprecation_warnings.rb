test_name "#8174: incorrect warning about deprecated scoping"

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
  a
parameters:
  enc_var: "Set from ENC."
END
exit 0
PP

create_remote_file(master, "#{testdir}/site.pp", <<-PP)
$top_scope = "set from site.pp"
node default {
  $node_var = "in node"
}
PP
create_remote_file(master, "#{testdir}/modules/a/manifests/init.pp", <<-PP)
class a {
  $locally = "locally declared"
  $dynamic_for_b = "dynamic and declared in a"
  notify { "fqdn from facts": message => $fqdn }
  notify { "locally declared var": message => $locally }
  notify { "var via enc": message => $enc_var }
  notify { "declared top scope": message => $top_scope }
  notify { "declared node": message => $node_var }

  include a::b
}
PP
create_remote_file(master, "#{testdir}/modules/a/manifests/b.pp", <<-PP)
class a::b {
  notify { "dynamic from elsewhere": message => $dynamic_for_b }
}
PP

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"
on master, "chmod -R a+x #{testdir}/enc"
on master, "touch #{testdir}/log"
on master, "chown puppet #{testdir}/log"

assert_log_on_master_contains = lambda do |string|
  on master, "grep '#{string}' #{testdir}/log"
end

assert_log_on_master_does_not_contain = lambda do |string|
  on master, "grep -v '#{string}' #{testdir}/log"
end

with_master_running_on(master, "--config #{testdir}/puppet.conf --debug --verbose --daemonize --dns_alt_names=\"puppet,$(hostname -s),$(hostname -f)\" --autosign true --logdest #{testdir}/log") do
  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master}")
  end

  assert_log_on_master_contains['Dynamic lookup of $dynamic_for_b']
  assert_log_on_master_does_not_contain['Dynamic lookup of $fqdn']
  assert_log_on_master_does_not_contain['Dynamic lookup of $locally']
  assert_log_on_master_does_not_contain['Dynamic lookup of $enc_var']
  assert_log_on_master_does_not_contain['Dynamic lookup of $top_scope']
  assert_log_on_master_does_not_contain['Dynamic lookup of $node_var']
end

on master, "rm -rf #{testdir}"
