test_name "should correctly manage the attributes property for the Group (AIX only)" do
  confine :to, :platform => /aix/
  
  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test
  
  require 'puppet/acceptance/aix_util'
  extend Puppet::Acceptance::AixUtil

  initial_attributes = {
    'admin' => true
  }
  changed_attributes = {
    'admin' => false
  }

  run_attribute_management_tests('group', :gid, initial_attributes, changed_attributes)

end
