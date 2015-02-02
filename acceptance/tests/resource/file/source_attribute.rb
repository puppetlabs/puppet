test_name "The source attribute"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

@target_file_on_windows = 'C:/windows/temp/source_attr_test'
@target_file_on_nix     = '/tmp/source_attr_test'
@target_dir_on_windows  = 'C:/windows/temp/source_attr_test_dir'
@target_dir_on_nix      = '/tmp/source_attr_test_dir'

checksums = [nil, 'md5', 'md5lite', 'sha256', 'sha256lite', 'ctime', 'mtime']

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
  hosts.each do |host|
    file_to_rm = host['platform'] =~ /windows/ ? @target_file_on_windows : @target_file_on_nix
    dir_to_rm = host['platform'] =~ /windows/ ? @target_dir_on_windows : @target_dir_on_nix

    checksums.each do |checksum_type|
      on(host, "rm #{file_to_rm}#{checksum_type}", :acceptable_exit_codes => [0,1])
      on(host, "rm -r #{file_to_rm}#{checksum_type}", :acceptable_exit_codes => [0,1])
    end
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
mod_source_dir = "#{test_module_files_dir}/source_dir"
mod_source_dir_file = "#{mod_source_dir}/source_dir_file"

mod_source = ' the content is present'

def mod_manifest_entry(checksum_type = nil)
  checksum = if checksum_type then "checksum => #{checksum_type}," else "" end
  manifest = <<EOF
  $target_file#{checksum_type} = $::kernel ? {
    \\'windows\\' => \\'#{@target_file_on_windows}#{checksum_type}\\',
    default   => \\'#{@target_file_on_nix}#{checksum_type}\\'
  }

  file { $target_file#{checksum_type}:
    source => \\'puppet:///modules/source_test_module/source_file\\',
    #{checksum}
    ensure => present
  }

  $target_dir#{checksum_type} = $::kernel ? {
    \\'windows\\' => \\'#{@target_dir_on_windows}#{checksum_type}\\',
    default   => \\'#{@target_dir_on_nix}#{checksum_type}\\'
  }

  file { $target_dir#{checksum_type}:
    source => \\'puppet:///modules/source_test_module/source_dir\\',
    #{checksum}
    ensure => directory,
    recurse => true
  }
EOF
  manifest
end

mod_manifest = <<EOF
class source_test_module {
#{checksums.collect { |checksum_type| mod_manifest_entry(checksum_type) }.join("\n")}
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

  file { '#{mod_source_dir}':
    ensure => directory,
    mode => '0755'
  }

  file { '#{mod_source_dir_file}':
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
    # accept an exit code of 2 which is returned if there are changes
    step "create file the first run"
    on(agent, puppet('agent', "--test --server #{master}"), :acceptable_exit_codes => [0,2]) do
      file_to_check = agent['platform'] =~ /windows/ ? @target_file_on_windows : @target_file_on_nix
      dir_to_check = agent['platform'] =~ /windows/ ? @target_dir_on_windows : @target_dir_on_nix

      checksums.each do |checksum_type|
        on agent, "cat #{file_to_check}#{checksum_type}" do
          assert_match(/the content is present/, stdout, "Result file not created")
        end

        on agent, "cat #{dir_to_check}#{checksum_type}/source_dir_file" do
          assert_match(/the content is present/, stdout, "Result file not created")
        end
      end
    end

    step "second run should not update file"
    on(agent, puppet('agent', "--test --server #{master}")) do
      assert_no_match(/content changed/, stdout, "Shouldn't have overwrote any files")
    end
  end

  step "touch files and verify they're updated with ctime/mtime"
  sleep(1)
  on master, "touch #{mod_source_file} #{mod_source_dir_file}"
  agents.each do |agent|
    on(agent, puppet('agent', "--test --server #{master}"), :acceptable_exit_codes => [0,2]) do
      file_to_check = agent['platform'] =~ /windows/ ? @target_file_on_windows : @target_file_on_nix
      dir_to_check = agent['platform'] =~ /windows/ ? @target_dir_on_windows : @target_dir_on_nix
      ['ctime', 'mtime'].each do |time_type|
        assert_match(/File\[#{file_to_check}#{time_type}\]\/content: content changed/, stdout, "Should have updated files")
        assert_match(/File\[#{dir_to_check}#{time_type}\/source_dir_file\]\/content: content changed/, stdout, "Should have updated files")
      end
    end
  end
end

new_mod_manifest = <<EOF
class source_test_module {
#{mod_manifest_entry}
}
EOF
apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  file { '#{mod_manifest_file}':
    ensure => file,
    mode => '0644',
    content => '#{new_mod_manifest}',
  }
MANIFEST

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
