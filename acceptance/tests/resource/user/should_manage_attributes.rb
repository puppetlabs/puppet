test_name "should correctly manage the attributes property for the User resource (AIX and Windows only)" do
  confine :to, :platform => /aix|windows/
  
  tag 'audit:medium',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test
  
  require 'puppet/acceptance/common_utils.rb'
  extend Puppet::Acceptance::ManifestUtils

  require 'puppet/acceptance/common_tests.rb'
  extend Puppet::Acceptance::CommonTests::AttributesProperty

  agents.each do |agent|
    case agent['platform']
    when /aix/
      require 'puppet/acceptance/aix_util'
      extend Puppet::Acceptance::AixUtil

      initial_attributes = {
        'nofiles'       => 10000,
        'fsize'         => 100000,
        'data'          => 60000,
      }
      changed_attributes = {
        'nofiles' => -1,
        'data' => 40000
      }
    
      run_aix_attribute_property_tests_on(
        agent,
        'user',
        :uid,
        initial_attributes,
        changed_attributes
      )
    when /windows/
      require 'puppet/acceptance/windows_utils.rb'
      extend Puppet::Acceptance::WindowsUtils

      username="pl#{rand(999999).to_i}"
      agent.user_absent(username)
      teardown { agent.user_absent(username) }

      initial_attributes = {
        'full_name'                   => 'Some Full Name',
        'password_change_required'    => 'false',
        'disabled'                    => 'true',
        'password_change_not_allowed' => 'true'
      }

      changed_attributes = {
        'full_name'                   => 'Another Full Name',
        'password_change_required'    => 'true',
        'disabled'                    => 'false',
        'password_change_not_allowed' => 'false'
      }

      run_common_attributes_property_tests_on(
        agent,
        'user',
        username,
        method(:current_attributes_on),
        initial_attributes,
        changed_attributes
      )

      # Good to ensure that our user's still present in case the
      # common attributes test decides to delete the created user
      # in the future.
      agent.user_present(username)

      step "Verify that Puppet errors when we specify an unmanaged attribute" do
        attributes = initial_attributes.merge('unmanaged_attribute' => 'value')
        manifest = user_manifest(username, attributes: attributes)

        apply_manifest_on(agent, manifest) do |result|
          assert_match(/unmanaged_attribute.*full_name/, result.stderr, 'Puppet does not error if the user specifies an unmanaged Windows attribute')
        end
      end

      step "Verify that Puppet errors when we specify an invalid attribute combination" do
        attributes = {
          'password_change_not_allowed' => 'false',
          'password_change_required'    => 'true',
          'password_never_expires'      => 'true'
        }
        manifest = user_manifest(username, attributes: attributes)

        apply_manifest_on(agent, manifest) do |result|
          assert_match(/password_change_required.*password_never_expires/, result.stderr, 'Puppet does not error if the user specifies an invalid attribute combination')
        end
      end

      step "Verify that Puppet errors when we specify an invalid attribute value" do
        attributes = initial_attributes.merge('disabled' => 'string_value')
        manifest = user_manifest(username, attributes: attributes)

        apply_manifest_on(agent, manifest) do |result|
          assert_match(/disabled.*Boolean/, result.stderr, 'Puppet does not error if the user specifies an invalid Windows attribute value')
        end
      end
    end
  end
end
