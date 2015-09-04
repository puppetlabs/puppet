test_name "Calling Hiera function from inside templates"

# Global variables

$module_name = "hieratest"
$coderoot = master.tmpdir("#{$module_name}")
$resultdir = "#{$coderoot}/results"

$msg_default = 'message from default.yaml'
$msg_production = 'message from production.yaml'
$msg1os = 'message1 from {osfamily}.yaml'
$msg2os = 'message2 from {osfamily}.yaml'
$msg_fqdn = 'messsage from {fqdn}.yaml'

$k1 = 'key1'
$k2 = 'key2'
$k3 = 'key3'

$val1p = 'value1 from production.yaml'
$val2p = 'value2 from production.yaml'
$val2os = 'value2 from {osfamily}.yaml'
$val3os = 'value3 from {osfamily}.yaml'

$hval3os = 'hash_value3 from production.yaml'
$hval2os = 'hash_value2 from production.yaml'
$hval1p = 'hash_value1 from {osfamily}.yaml'
$hval2p = 'hash_value2 from {osfamily}.yaml'

$h_m_call = "hiera\\('message'\\)"
$h_h_call = "hiera\\('hash_value'\\)"
$h_i_call = "hiera\\('includes'\\)"
$ha_m_call = "hiera_array\\('message'\\)"
$ha_i_call = "hiera_array\\('includes'\\)"
$hh_h_call = "hiera_hash\\('hash_value'\\)"

$mod_default_msg = 'This file created by mod_default.'
$mod_osfamily_msg = 'This file created by mod_osfamily.'
$mod_production_msg = 'This file created by mod_production.'
$mod_fqdn_msg = 'This file created by mod_fqdn.'


def create_environment

  #    Creates a directory tree like this on the master, under /tmp/hieratest/
  #    .
  #    ├── environments
  #    │   └── production
  #    │       ├── manifests
  #    │       │   └── site.pp
  #    │       └── modules
  #    │           └── hieratest
  #    │               ├── examples
  #    │               │   └── init.pp
  #    │               ├── manifests
  #    │               │   ├── init.pp
  #    │               │   ├── mod_default.pp
  #    │               │   ├── mod_fqdn.pp
  #    │               │   ├── mod_osfamily.pp
  #    │               │   └── mod_production.pp
  #    │               └── templates
  #    │                   ├── hieratest_results_epp.erb
  #    │                   └── hieratest_results_erb.erb
  #    ├── hieradata
  #    │   ├── default.yaml
  #    │   ├── production.yaml
  #    │   └── RedHat.yaml
  #    ├── hiera.yaml
  #    └── puppet.conf



  envroot = "#{$coderoot}/environments"
  production = "#{envroot}/production"
  modroot = "#{production}/modules"
  moduledir = "#{modroot}/#{$module_name}"
  hieradir = "#{$coderoot}/hieradata"

  # {
  environ = <<ENV

File {
  ensure => file,
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
  mode   => "0644",
}

file {
  [
    "#{$coderoot}",
    "#{envroot}",
    "#{production}",
    "#{production}/modules",
    "#{production}/manifests",
    "#{hieradir}",
    "#{moduledir}",
    "#{moduledir}/examples",
    "#{moduledir}/manifests",
    "#{moduledir}/templates",
  ] :
  ensure => directory,
}

file { '#{production}/manifests/site.pp':
  ensure => file,
  content => "
node default {
  \\$msgs = hiera_array('message')
  notify {\\$msgs:}
  include #{$module_name}
}
",
}


file {"#{$coderoot}/hiera.yaml":
  content => "
---
:backends:
  - yaml

:yaml:
  :datadir: #{$coderoot}/hieradata

:hierarchy:
  - \\"%{clientcert}\\"
  - \\"%{environment}\\"
  - \\"%{osfamily}\\"
  - \\"default\\"
"
}

file {"#{hieradir}/default.yaml":
  content => "
---
message: '#{$msg_default}'
includes: '#{$module_name}::mod_default'
"
}

file {"#{hieradir}/${osfamily}.yaml":
  content => "
---
message: [
  '#{$msg1os}',
  '#{$msg2os}',
]
includes: '#{$module_name}::mod_osfamily'
hash_value:
  #{$k3}: '#{$hval3os}'
  #{$k2}: '#{$hval2os}'
"
}

file {"#{hieradir}/production.yaml":
  content => "
---
message: '#{$msg_production}'
includes: '#{$module_name}::mod_production'
hash_value:
  #{$k1}: '#{$hval1p}'
  #{$k2}: '#{$hval2p}'
"
}

file {"#{$hieradir}/#{$fqdn}.yaml":
  content => "
---
message: '#{$msg_fqdn}'
includes: '#{$module_name}::mod_fqdn'
"
}

file {"#{moduledir}/examples/init.pp":
  content => "
include #{$module_name}
"
}

file { "#{moduledir}/manifests/init.pp":
  content => "
class #{$module_name} {
  file {
    [
      '#{$coderoot}',
      '#{$resultdir}',
    ]:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  file {'/#{$resultdir}/#{$module_name}_results_epp':
    ensure  => file,
    owner => 'root',
    group => 'root',
    mode  => '0644',
    content => epp('#{$module_name}/hieratest_results_epp.epp'),
  }
  file {'/#{$resultdir}/#{$module_name}_results_erb':
    ensure  => file,
    owner => 'root',
    group => 'root',
    mode  => '0644',
    content => template('#{$module_name}/hieratest_results_erb.erb'),
  }
}
"
}

file { "#{moduledir}/manifests/mod_default.pp":
  content => "
class #{$module_name}::mod_default {
  notify{\\"module mod_default invoked.\\\\n\\":}
  file {'/#{$resultdir}/mod_default':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => \\\"#{$mod_default_msg}\\\\n\\\",
  }
}
"
}

file { "#{moduledir}/manifests/mod_osfamily.pp":
  content => "
class #{$module_name}::mod_osfamily {
  notify{\\"module mod_osfamily invoked.\\\\n\\":}
  file {'/#{$resultdir}/mod_osfamily':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => \\\"#{$mod_osfamily_msg}\\\\n\\\",
  }
}
"
}

file { "#{moduledir}/manifests/mod_production.pp":
  content => "
class #{$module_name}::mod_production {
  notify{\\"module mod_production invoked.\\\\n\\":}
  file {'/#{$resultdir}/mod_production':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => \\\"#{$mod_production_msg}\\\\n\\\",
  }
}
"
}

file { "#{moduledir}/manifests/mod_fqdn.pp":
  content => "
class #{$module_name}::mod_fqdn {
  notify{\\"module mod_fqdn invoked.\\\\n\\":}
  file {'/#{$resultdir}/mod_fqdn':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => \\\"#{$mod_fqdn_msg}\\\\n\\\",
  }
}
"
}

file { "#{moduledir}/templates/hieratest_results_epp.epp":
  content => "
hiera('message'): <%= hiera('message') %> 
hiera('hash_value'): <%= hiera('hash_value') %>
hiera('includes'): <%= hiera('includes') %>
hiera_array('message'): <%= hiera_array('message') %>
hiera_array('includes'): <%= hiera_array('includes') %>
hiera_hash('hash_value'): <%= hiera_hash('hash_value') %>
hiera_include('includes'): <%= hiera_include('includes') %>
"
}

file { "#{moduledir}/templates/hieratest_results_erb.erb":
  content => "
hiera('message'): <%= scope().call_function('hiera', ['message']) %>
hiera('hash_value'): <%= scope().call_function('hiera', ['hash_value']) %>
hiera('includes'): <%= scope().call_function('hiera', ['includes']) %>
hiera_array('message'): <%= scope().call_function('hiera_array', ['message']) %>
hiera_array('includes'): <%= scope().call_function('hiera_array', ['includes']) %>
hiera_hash('hash_value'): <%= scope().call_function('hiera_hash', ['hash_value']) %>
"
}

ENV
# }
  environ
end

step 'Setup'

env_manifest = create_environment
master_opts = {
  'main' => {
    'environmentpath' => "#{$coderoot}/environments",
    'hiera_config' => "#{$coderoot}/hiera.yaml",
  },
}

with_puppet_running_on master, master_opts, $coderoot do
  apply_manifest_on(master, env_manifest, :catch_failures => true)
  agents.each do |agent|
    step "Applying catalog to agent: #{agent}."
    on(
      agent,
      puppet('agent', "-t --server #{master}"),
      :acceptable_exit_codes => [2]
    )

    step "####### Verifying hiera calls from erb template #######"
    on(agent, "cat #{$coderoot}/results/hieratest_results_erb")

    step "Verifying hiera() call #1."
    assert_match(/#{$h_m_call}: #{$msg_production}/, stdout)

    step "Verifying hiera() call #2."
    assert_match(/#{$h_h_call}.*\"#{$k1}\"=>\"#{$hval1p}\"/, stdout)

    step "Verifying hiera() call #3."
    assert_match(/#{$h_h_call}.*\"#{$k2}\"=>\"#{$hval2p}\"/, stdout)

    step "Verifying hiera() call #4."
    assert_match(/#{$h_i_call}: #{$module_name}::mod_production/, stdout)

    step "Verifying hiera_array() call. #1"
    assert_match(
/#{$ha_m_call}: \[\"#{$msg_production}\", \"#{$msg1os}\", \"#{$msg2os}\", \"#{$msg_default}\"\]/,
      stdout 
    )

    step "Verifying hiera_array() call. #2"
    assert_match(
/#{$ha_i_call}: \[\"#{$module_name}::mod_production\", \"#{$module_name}::mod_osfamily\", \"#{$module_name}::mod_default\"\]/,
      stdout
    )

    step "Verifying hiera_hash() call. #1"
    assert_match(/#{$hh_h_call}:.*\"#{$k1}\"=>\"#{$hval1p}\"/, stdout )

    step "Verifying hiera_hash() call. #2"
    assert_match(/#{$hh_h_call}:.*\"#{$k2}\"=>\"#{$hval2p}\"/, stdout)

    step "Verifying hiera_hash() call. #3"
    assert_match(/#{$hh_h_call}:.*\"#{$k3}\"=>\"#{$hval3os}\"/, stdout)

    on(agent, "cat #{$coderoot}/results/mod_default")
    step "Verifying hiera_include() call. #1"
    assert_match("#{$mod_default_msg}", stdout)

    on(agent, "cat #{$coderoot}/results/mod_osfamily")
    step "Verifying hiera_include() call. #2"
    assert_match("#{$mod_osfamily_msg}", stdout)

    on(agent, "cat #{$coderoot}/results/mod_production")
    step "Verifying hiera_include() call. #3"
    assert_match("#{$mod_production_msg}", stdout)

    step "####### Verifying hiera calls from epp template #######"
    on(agent, "cat #{$coderoot}/results/hieratest_results_epp")

    step "Verifying hiery() call #1."
    assert_match(/#{$h_m_call}: #{$msg_production}/, stdout)

    step "Verifying hiera() call #2."
    assert_match(/#{$h_h_call}.*#{$k1} => #{$hval1p}/, stdout)

    step "Verifying hiera() call #3."
    assert_match(/#{$h_h_call}.*#{$k2} => #{$hval2p}/, stdout)

    step "Verifying hiera() call #4."
    assert_match(/#{$h_i_call}: #{$module_name}::mod_production/, stdout)

    step "Verifying hiera_array() call. #1"
    assert_match(
/#{$ha_m_call}: \[#{$msg_production}, #{$msg1os}, #{$msg2os}, #{$msg_default}\]/,
      stdout 
    )

    step "Verifying hiera_array() call. #2"
    assert_match(
/#{$ha_i_call}: \[#{$module_name}::mod_production, #{$module_name}::mod_osfamily, #{$module_name}::mod_default\]/,
      stdout
    )

    step "Verifying hiera_hash() call. #1"
    assert_match(/#{$hh_h_call}:.*#{$k1} => #{$hval1p}/, stdout )

    step "Verifying hiera_hash() call. #2"
    assert_match(/#{$hh_h_call}:.*#{$k2} => #{$hval2p}/, stdout)

    step "Verifying hiera_hash() call. #3"
    assert_match(/#{$hh_h_call}:.*#{$k3} => #{$hval3os}/, stdout)
  end
end
