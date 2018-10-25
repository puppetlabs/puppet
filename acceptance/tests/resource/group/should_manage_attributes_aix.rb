test_name "should correctly manage the attributes property for the Group (AIX only)" do
  confine :to, :platform => /aix/
  
  tag 'audit:medium',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test
  
  require 'puppet/acceptance/common_tests.rb'
  require 'puppet/acceptance/aix_util'
  extend Puppet::Acceptance::CommonTests::AttributesProperty
  extend Puppet::Acceptance::AixUtil

  initial_attributes = {
    'admin' => true
  }
  changed_attributes = {
    'admin' => false
  }

  agents.each do |agent|
    run_aix_attribute_property_tests_on(
      agent,
      'group',
      :gid,
      initial_attributes,
      changed_attributes
    )
  end

end
