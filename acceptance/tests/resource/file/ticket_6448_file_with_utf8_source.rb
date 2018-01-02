test_name 'Ensure a file resource can have a UTF-8 source attribute, content, and path when served via a module' do
  tag 'audit:high',
      'broken:images',
      'audit:acceptance'

  skip_test 'requires a master for serving module content' if master.nil?

  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/agent_fqdn_utils'
  extend Puppet::Acceptance::AgentFqdnUtils

  tmp_environment = mk_tmp_environment_with_teardown(master, File.basename(__FILE__, '.*'))
  agent_tmp_dirs  = {}

  agents.each do |agent|
    agent_tmp_dirs[agent_to_fqdn(agent)] = agent.tmpdir(tmp_environment)
  end

  teardown do
    step 'remove all test files on agents' do
      agents.each {|agent| on(agent, "rm -r '#{agent_tmp_dirs[agent_to_fqdn(agent)]}'", :accept_all_exit_codes => true)}
    end
    # note - master teardown is registered by #mk_tmp_environment_with_teardown
  end

  step 'create unicode source file served via module on master' do
    # 静 \u9759 0xE9 0x9D 0x99 http://www.fileformat.info/info/unicode/char/9759/index.htm
    # 的 \u7684 0xE7 0x9A 0x84 http://www.fileformat.info/info/unicode/char/7684/index.htm
    # ☃ \2603 0xE2 0x98 0x83 http://www.fileformat.info/info/unicode/char/2603/index.htm
    setup_module_on_master = <<-MASTER_MANIFEST
      File {
        ensure => directory,
        mode => "0755",
      }

      file {
        '#{environmentpath}/#{tmp_environment}/modules/utf8_file_module':;
        '#{environmentpath}/#{tmp_environment}/modules/utf8_file_module/files':;
      }

      file { '#{environmentpath}/#{tmp_environment}/modules/utf8_file_module/files/\u9759\u7684':
        ensure => file,
        content => "\u2603"
      }
    MASTER_MANIFEST
    apply_manifest_on(master, setup_module_on_master, :expect_changes => true)
  end

  step 'create a site.pp on master containing a unicode file resource' do
    site_pp_contents = <<-SITE_PP
      \$test_path = \$::fqdn ? #{agent_tmp_dirs}
      file { "\$test_path/\uff72\uff67\u30d5\u30eb":
        ensure => present,
        source => "puppet:///modules/utf8_file_module/\u9759\u7684",
      }
    SITE_PP

    create_site_pp = <<-CREATE_SITE_PP
      file { "#{environmentpath}/#{tmp_environment}/manifests/site.pp":
        ensure => file,
        content => @(UTF8)
          #{site_pp_contents}
        | UTF8
      }
    CREATE_SITE_PP
    apply_manifest_on(master, create_site_pp, :expect_changes => true)
  end

  step 'ensure agent can manage unicode file resource' do
    # イ \uff72 0xEF 0xBD 0xB2 http://www.fileformat.info/info/unicode/char/ff72/index.htm
    # ァ \uff67 0xEF 0xBD 0xA7 http://www.fileformat.info/info/unicode/char/ff67/index.htm
    # フ \u30d5 0xE3 0x83 0x95 http://www.fileformat.info/info/unicode/char/30d5/index.htm
    # ル \u30eb 0xE3 0x83 0xAB http://www.fileformat.info/info/unicode/char/30eb/index.htm

    with_puppet_running_on(master, {}) do
      agents.each do |agent|
        on(agent, puppet("agent -t --environment '#{tmp_environment}' --server #{master.hostname}"), :acceptable_exit_codes => 2)

        on(agent, "cat '#{agent_tmp_dirs[agent_to_fqdn(agent)]}/\uff72\uff67\u30d5\u30eb'") do |result|
          assert_match("\u2603", result.stdout, "managed UTF-8 file contents '#{result.stdout}' did not match expected value '\u2603'")
        end
      end
    end
  end
end
