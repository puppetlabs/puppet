test_name "C97172: static catalogs support utf8" do
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils

  app_type = File.basename(__FILE__, '.*')
  tmp_environment   = mk_tmp_environment(app_type)

  filenames         = {'windows' => "C:/cygwin64/tmp/#{tmp_environment}_file"}
  filenames.default = "/tmp/#{tmp_environment}_file"
  teardown do
    step 'remove the tmp environment symlink' do
      on master, "rm -rf #{File.join(environmentpath, tmp_environment)}"
    end
    step 'clean out produced resources' do
      on(agents, "rm #{filenames['windows']}; rm #{filenames.default}", :accept_all_exit_codes => true)
    end
  end

  file_contents     = 'Mønti Pythøn ik den Hølie Gräilen, yër? € ‰ ㄘ 万 竹 Ü Ö'
  step 'create site.pp with utf8 chars' do
    manifest = <<MANIFEST
file { '#{environmentpath}/#{tmp_environment}/manifests/site.pp':
  ensure => file,
  content => '
\$test_path = \$::osfamily ? {
  "Windows" => "#{filenames['windows']}",
  default   => "#{filenames.default}",
}

file { \$test_path:
  content => @(UTF8)
    #{file_contents}
    | UTF8
}
  ',
}
MANIFEST
    apply_manifest_on(master, manifest, :catch_failures => true)
  end

  step 'run agent(s)' do
    with_puppet_running_on(master, {}) do
      agents.each do |agent|
        os_type = agent.platform =~ /windows/ ? 'windows' : 'other'
        config_version = ''
        config_version_matcher = /configuration version '(\d+)'/
        on(agent, puppet("agent -t --environment #{tmp_environment} --server #{master.hostname}"),
           :acceptable_exit_codes => 2).stdout do |agent_out|
          config_version = agent_out.match(config_version_matcher)
        end
        on(agent, "cat #{filenames[os_type]}").stdout do |result|
          assert_equal(file_contents, result, 'file contents did not match accepted')
        end
        on(agent, "rm #{filenames['os_type']}", :accept_all_exit_codes => true)
        on(agent, puppet("agent -t --environment #{tmp_environment} --server #{master.hostname} --use_cached_catalog"),
           :acceptable_exit_codes => 2).stdout do |agent_out|
          assert_match(config_version_matcher, result, 'agent did not use cached catalog')
        end
        on(agent, "cat #{filenames[os_type]}").stdout do |result|
          assert_equal(file_contents, result, 'file contents did not match accepted')
        end

      end
    end
  end

end
