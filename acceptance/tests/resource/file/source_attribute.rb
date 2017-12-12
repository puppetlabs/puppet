test_name "The source attribute" do
  require 'puppet/acceptance/module_utils'
  extend Puppet::Acceptance::ModuleUtils

  tag 'audit:high',
      'audit:acceptance',
      'server'

  @target_file_on_windows = 'C:/windows/temp/source_attr_test'
  @target_file_on_nix     = '/tmp/source_attr_test'
  @target_dir_on_windows  = 'C:/windows/temp/source_attr_test_dir'
  @target_dir_on_nix      = '/tmp/source_attr_test_dir'

  # In case any of the hosts happens to be fips enabled we limit to the lowest
  # common denominator.
  checksums_fips = [nil, 'sha256', 'sha256lite', 'ctime', 'mtime']
  checksums_no_fips = [nil, 'md5', 'md5lite', 'sha256', 'sha256lite', 'ctime', 'mtime']
 
  fips_host_present = hosts.any? { |host| on(host, facter("fips_enabled")).stdout =~ /true/ }
  
  if fips_host_present
    checksums = checksums_fips
  else
    checksums = checksums_no_fips
  end

  orig_installed_modules = get_installed_modules_for_hosts hosts
  teardown do
    rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
    hosts.each do |host|
      file_to_rm = host['platform'] =~ /windows/ ? @target_file_on_windows : @target_file_on_nix
      dir_to_rm = host['platform'] =~ /windows/ ? @target_dir_on_windows : @target_dir_on_nix

      checksums.each do |checksum_type|
        on(host, "rm #{file_to_rm}#{checksum_type}", :acceptable_exit_codes => [0,1])
        on(host, "rm -r #{dir_to_rm}#{checksum_type}", :acceptable_exit_codes => [0,1])
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
    manifest = <<-EOF
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

  mod_manifest = <<-EOF
  class source_test_module {
  #{checksums.collect { |checksum_type| mod_manifest_entry(checksum_type) }.join("\n")}
  }
  EOF

  env_manifest = <<-EOF
  filebucket { \\'main\\':
    server => \\'#{master}\\',
    path   => false,
  }

  File { backup => \\'main\\' }

  node default {
    include source_test_module
  }
  EOF

  # apply manifests to setup environment and modules
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

  step "When using a puppet:/// URI with a master/agent setup"
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
            assert_match(/the content is present/, stdout, "Result file not created #{checksum_type}")
          end

          on agent, "cat #{dir_to_check}#{checksum_type}/source_dir_file" do
            assert_match(/the content is present/, stdout, "Result file not created #{checksum_type}")
          end
        end
      end

      step "second run should not update file"
      on(agent, puppet('agent', "--test --server #{master}"), :acceptable_exit_codes => [0,2]) do
        assert_no_match(/content changed.*(md5|sha256)/, stdout, "Shouldn't have overwritten any files")

        # When using ctime/mtime, the agent compares the values from its
        # local file with the values on the master to determine if the
        # file is insync or not. If during the first run, the agent
        # creates the files, and the resulting ctime/mtime are still
        # behind the times on the master, then the 2nd agent run will
        # consider the file to not be insync, and will update it
        # again. This process will repeat until the agent updates the
        # file, and the resulting ctime/mtime are after the values on
        # the master, at which point it will have converged.
        if stdout =~ /content changed.*ctime/
          Log.warn "Agent did not converge using ctime"
        end

        if stdout =~ /content changed.*mtime/
          Log.warn "Agent did not converge using mtime"
        end
      end
    end

=begin
    # Disable flaky test until PUP-4115 is addressed.
    step "touch files and verify they're updated with ctime/mtime"
    # wait until we're not at the mtime of files on the agents
    # this could be done cross-platform using Puppet, but a single puppet query is unlikely to be less than a second,
    # and iterating over all agents would be much slower
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
=end
  end

  # TODO: Add tests for puppet:// URIs with multi-master/agent setups.
  step "When using puppet apply"
  agents.each do |agent|
    step "Setup testing local file sources"

    # create one larger manifest with all the files so we don't have to run
    # puppet apply per each checksum_type
    localsource_testdir = agent.tmpdir('local_source_file_test')
    source = "#{localsource_testdir}/source_mod/files/source"
    on agent, "mkdir -p #{File.dirname(source)}"
    # don't put a 'z' in this content
    source_content = 'Yay, this is the local file. I have to be bigger than 512 bytes so that my masters. yadda yadda yadda not a nice thing. lorem ipsem. alice bob went to fetch a pail of water. Lorem ipsum dolor sit amet, pede ipsum nam wisi lectus eget, sociis sed, commodo vitae velit eleifend. Vestibulum orci feugiat erat etiam pellentesque sed, imperdiet a integer nulla, mi tincidunt suscipit. Nec sed, mi tortor, in a consequat mattis proin scelerisque eleifend. In lectus magna quam. Magna quam vitae sociosqu. Adipiscing laoreet.'
    create_remote_file agent, source, source_content

    local_apply_manifest = ""
    target = {}
    checksums.each do |checksum_type|
      target[checksum_type] = "#{localsource_testdir}/target#{checksum_type}"
      checksum = if checksum_type then "checksum => #{checksum_type}," else "" end
      local_apply_manifest.concat("file { '#{target[checksum_type]}': source => '#{source}', ensure => present, #{checksum} }\n")
    end

    apply_manifest_on agent, local_apply_manifest

    checksums.each do |checksum_type|
      step "Using a local file path. #{checksum_type}"
      on agent, "cat #{target[checksum_type]}" do
        assert_match(/Yay, this is the local file./, stdout, "FIRST: File contents not matched on #{agent}")
      end
    end

    step "second run should not update any files"
    apply_manifest_on agent, local_apply_manifest do
      assert_no_match(/content changed/, stdout, "Shouldn't have overwrote any files")
    end

    # changes in source file producing updates is tested elsewhere
    step "subsequent run should not update file using <checksum>lite if only after byte 512 is changed"
    byte_after_md5lite = 513
    source_content[byte_after_md5lite] = 'z'
    create_remote_file agent, source, source_content
    
    if fips_host_present == 1
      apply_manifest_on agent, "file { '#{localsource_testdir}/targetsha256lite': source => '#{source}', ensure => present, checksum => sha256lite }" do
        assert_no_match(/(content changed|defined content)/, stdout, "Shouldn't have overwrote any files")
      end
    else
      apply_manifest_on agent, "file { '#{localsource_testdir}/targetmd5lite': source => '#{source}', ensure => present, checksum => md5lite } file { '#{localsource_testdir}/targetsha256lite': source => '#{source}', ensure => present, checksum => sha256lite }" do
        assert_no_match(/(content changed|defined content)/, stdout, "Shouldn't have overwrote any files")
      end
    end 

    local_module_manifest = ""
    checksums.each do |checksum_type|
      on agent, "rm -rf #{target[checksum_type]}"
      checksum = if checksum_type then "checksum => #{checksum_type}," else "" end
      local_module_manifest.concat("file { '#{target[checksum_type]}': source => 'puppet:///modules/source_mod/source', ensure => present, #{checksum} }\n")
    end

    localsource_test_manifest = agent.tmpfile('local_source_test_manifest')
    create_remote_file agent, localsource_test_manifest, local_module_manifest
    on agent, puppet( %{apply --modulepath=#{localsource_testdir} #{localsource_test_manifest}} )

    checksums.each do |checksum_type|
      step "Using a puppet:/// URI with checksum type: #{checksum_type}"
      on agent, "cat #{target[checksum_type]}" do
        assert_match(/Yay, this is the local file./, stdout, "FIRST: File contents not matched on #{agent}")
      end
    end

    step "second run should not update any files using apply with puppet:/// URI source"
    on agent, puppet( %{apply --modulepath=#{localsource_testdir} #{localsource_test_manifest}} ) do
      assert_no_match(/content changed/, stdout, "Shouldn't have overwrote any files")
    end
  end

end
