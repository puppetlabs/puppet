test_name "The source attribute"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

target_file_on_windows = 'C:/windows/temp/source_attr_test'
target_file_on_nix     = '/tmp/source_attr_test'

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
  hosts.each do |host|
    file_to_rm = host['platform'] =~ /windows/ ? target_file_on_windows : target_file_on_nix
    on(host, "rm #{file_to_rm}", :acceptable_exit_codes => [0,1])
  end
end

step "Setup - create environment and test module"
# set directories
testdir = master.tmpdir('file_source_attr')
env_dir = "#{testdir}/environments"
prod_dir = "#{env_dir}/production"
manifest_dir = "#{prod_dir}/manifests"
manifest_file = "#{prod_dir}/manifests/site.pp"
module_dir = "#{prod_dir}/modules"
test_module_dir = "#{module_dir}/source_test_module"
test_module_manifests_dir = "#{test_module_dir}/manifests"
test_module_files_dir = "#{test_module_dir}/files"
mod_manifest_file = "#{test_module_manifests_dir}/init.pp"
mod_source_file = "#{test_module_files_dir}/source_file"

mod_source = ' the content is present'

mod_manifest = <<EOF
class source_test_module {
  $target_file = $::kernel ? {
    \\'windows\\' => \\'#{target_file_on_windows}\\',
    default   => \\'#{target_file_on_nix}\\'
  }

  file { $target_file:
    source => \\'puppet:///modules/source_test_module/source_file\\',
    ensure => present
  }
}
EOF

env_manifest = <<EOF
filebucket { \\'main\\':
  server => \\'#{master}\\',
  path   => false,
}

File { backup => \\'main\\' }

node default {
  include source_test_module
}
EOF

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode => '0755',
  }

  file {
    '#{testdir}':;
    '#{env_dir}':;
    '#{prod_dir}':;
    '#{manifest_dir}':;
    '#{module_dir}':;
    '#{test_module_dir}':;
    '#{test_module_manifests_dir}':;
    '#{test_module_files_dir}':;
  }

  file { '#{mod_manifest_file}':
    ensure => file,
    mode => '0644',
    content => '#{mod_manifest}',
  }
  file { '#{mod_source_file}':
    ensure => file,
    mode => '0644',
    content => '#{mod_source}',
  }

  file { '#{manifest_file}':
    ensure => file,
    mode => '0644',
    content => '#{env_manifest}',
  }
MANIFEST

step "when using a puppet:/// URI with a master/agent setup"
master_opts = {
  'main' => {
    'environmentpath' => "#{env_dir}",
  },
}
with_puppet_running_on(master, master_opts, testdir) do
  agents.each do |agent|
    # accept an exit code of 2 which is returned if thre are changes
    on(agent, puppet('agent', "--test --server #{master}"), :acceptable_exit_codes => [0,2]) do
      file_to_check = agent['platform'] =~ /windows/ ? target_file_on_windows : target_file_on_nix
      on agent, "cat #{file_to_check}" do
        assert_match(/the content is present/, stdout, "Result file not created")
      end
    end
  end
end

# TODO: Add tests for puppet:// URIs with multi-master/agent setups.
step "when using a puppet://$server/ URI with a master/agent setup"
agents.each do |agent|
  step "Setup testing local file sources"
  a_testdir = agent.tmpdir('local_source_file_test')

  source = "#{a_testdir}/source_mod/files/source"
  target = "#{a_testdir}/target"

  on agent, "mkdir -p #{File.dirname(source)}"
  create_remote_file agent, source, 'Yay, this is the local file.'

  step "Using a local file path"
  apply_manifest_on agent, "file { '#{target}': source => '#{source}', ensure => present }"
  on agent, "cat #{target}" do
    assert_match(/Yay, this is the local file./, stdout, "FIRST: File contents not matched on #{agent}")
  end

  step "Using a puppet:/// URI with puppet apply"
  on agent, "rm -rf #{target}"

  manifest = %{"file { '#{target}': source => 'puppet:///modules/source_mod/source', ensure => 'present' }"}
  on agent, puppet( %{apply --modulepath=#{a_testdir} -e #{manifest}})
  on agent, "cat #{target}" do
    assert_match(/Yay, this is the local file./, stdout, "FIRST: File contents not matched on #{agent}")
  end
end
