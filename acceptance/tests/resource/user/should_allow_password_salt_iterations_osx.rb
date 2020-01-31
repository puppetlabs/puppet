test_name "should allow password, salt, and iteration attributes in OSX"

confine :to, :platform => /osx/

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

agents.each do |agent|
  teardown do
    puppet_resource("user", 'testuser', "ensure=absent")
  end

  step "create the test user with password and salt" do
    # The password is 'helloworld'
    apply_manifest_on(agent, <<-MANIFEST, :catch_failures => true)
  user { 'testuser':
    ensure => present,
    home   => '/Users/testuser',
    password => '6ce97688468f231845d9d982f1f10832ca0c6c728a77bac51c548af99ebd9b9c62bcba15112a0c7a7e34effbb2e92635650c79c51517d72b083a4eb2a513f51ad1f8ea9556cef22456159c341d8bcd382a91708afaf253c2b727d4c6cd3d29cc26011d5d511154037330ecea0263b1be8c1c13086d029c57344291bd37952b56',
    salt       => '377e8b60e5fdfe509cad188d5b1b9e40e78b418f8c3f0127620ea69d4c32789c',
    iterations => 40000,
  }
MANIFEST
  end

  step "verify the password was set correctly" do
    on(agent, "dscl /Local/Default -authonly testuser helloworld", :acceptable_exit_codes => 0)
  end
end
