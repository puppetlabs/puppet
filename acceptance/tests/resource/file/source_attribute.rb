test_name "The source attribute"

step "when using a puppet:/// URI with a master/agent setup"
testdir = master.tmpdir('file_source_attr')

source_path = "#{testdir}/modules/source_test_module/files/source_file"
on master, "mkdir -p #{File.dirname(source_path)}"
create_remote_file master, source_path, <<EOF
the content is present
EOF

target_file_on_windows = 'C:/windows/temp/source_attr_test'
target_file_on_nix     = '/tmp/source_attr_test'

mod_manifest = "#{testdir}/modules/source_test_module/manifests/init.pp"
on master, "mkdir -p #{File.dirname(mod_manifest)}"
create_remote_file master, mod_manifest, <<EOF
class source_test_module {
  $target_file = $::kernel ? {
    'windows' => '#{target_file_on_windows}',
    default   => '#{target_file_on_nix}'
  }

  file { $target_file:
    source => 'puppet:///modules/source_test_module/source_file',
    ensure => present
  }
}
EOF

manifest = "#{testdir}/site.pp"
create_remote_file master, manifest, <<EOF
node default {
  include source_test_module
}
EOF

on master, "chmod -R 777 #{testdir}"
on master, "chmod -R 644 #{mod_manifest} #{source_path} #{manifest}"
on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"

master_opts = {
  'master' => {
    'manifest' => manifest,
    'node_terminus' => 'plain',
    'modulepath' => "#{testdir}/modules"
  }
}
with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet('agent', "--test --server #{master}"), :acceptable_exit_codes => [2]) do
      file_to_check = agent['platform'] =~ /windows/ ? target_file_on_windows : target_file_on_nix
      on agent, "cat #{file_to_check}" do
        assert_match(/the content is present/, stdout, "Result file not created")
      end
    end
  end
end


# TODO: Add tests for puppet:// URIs with multi-master/agent setups.
# step "when using a puppet://$server/ URI with a master/agent setup"
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
