test_name "should correctly manage the attributes property for the User resource (AIX only)" do
  confine :to, :platform => /aix/
  
  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test
  
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

  run_attribute_management_tests('user', :uid, initial_attributes, changed_attributes)

end
