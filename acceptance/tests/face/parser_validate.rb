test_name 'parser validate' do

tag 'audit:medium',
    'audit:unit'   # Parser validation should be core to ruby
                   # and platform agnostic.

  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils
  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  app_type = File.basename(__FILE__, '.*')

  agents.each do |agent|

    step 'manifest with parser function call' do
      if agent.platform !~ /windows/
        tmp_environment   = mk_tmp_environment_with_teardown(agent, app_type)

        create_sitepp(agent, tmp_environment, <<-SITE)
function validate_this() {
  notice('hello, puppet')
}
validate_this()
        SITE
        on(agent, puppet("parser validate --environment #{tmp_environment}"), :pty => true) # default manifest
      end

      # manifest with Type aliases
      create_test_file(agent, "#{app_type}.pp", <<-PP)
function validate_this() {
  notice('hello, puppet')
}
validate_this()
type MyInteger = Integer
notice 42 =~ MyInteger
      PP
      tmp_manifest = get_test_file_path(agent, "#{app_type}.pp")
      on(agent, puppet("parser validate #{tmp_manifest}"))
    end

    step 'manifest with bad syntax' do
      create_test_file(agent, "#{app_type}_broken.pp", "notify 'hello there'")
      tmp_manifest = get_test_file_path(agent, "#{app_type}_broken.pp")
      on(agent, puppet("parser validate #{tmp_manifest}"), :accept_all_exit_codes => true) do |result|
        assert_equal(result.exit_code, 1, 'parser validate did not exit with 1 upon parse failure')
        expected = /Error: Could not parse for environment production: This Name has no effect\. A value was produced and then forgotten \(one or more preceding expressions may have the wrong form\) \(file: .*_broken\.pp, line: 1, column: 1\)/
        assert_match(expected, result.output, "parser validate did not output correctly: '#{result.output}'. expected: '#{expected.to_s}'") unless agent['locale'] == 'ja'
      end
    end

    step '(large) manifest with exported resources' do
      fixture_path = File.join(File.dirname(__FILE__), '..', '..', 'fixtures/manifest_large_exported_classes_node.pp')
      create_test_file(agent, "#{app_type}_exported.pp", File.read(fixture_path))
      tmp_manifest = get_test_file_path(agent, "#{app_type}_exported.pp")
      on(agent, puppet("parser validate #{tmp_manifest}"))
    end

  end

end
