test_name "should allow managed macOS users to login" do

  confine :to, :platform => /osx/

  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test


  # Two different test cases, with additional environment setup inbetween,
  # were added in the same file to save on test run time (managing macOS users
  # takes around a minute or so because when retrieving plist data from all users with
  # `dscl readall` we also receive thousands of bytes of user avatar image)
  agents.each do |agent|
    teardown do
      on(agent, puppet("resource", "user", 'testuser', "ensure=absent"))
    end

    # Checking if we can create a user with password, salt and iterations
    step "create the test user with password and salt" do
      # The password is 'helloworld'
      apply_manifest_on(agent, <<-MANIFEST, :catch_failures => true)
          user { 'testuser':
            ensure => present,
            password => '6ce97688468f231845d9d982f1f10832ca0c6c728a77bac51c548af99ebd9b9c62bcba15112a0c7a7e34effbb2e92635650c79c51517d72b083a4eb2a513f51ad1f8ea9556cef22456159c341d8bcd382a91708afaf253c2b727d4c6cd3d29cc26011d5d511154037330ecea0263b1be8c1c13086d029c57344291bd37952b56',
            salt       => '377e8b60e5fdfe509cad188d5b1b9e40e78b418f8c3f0127620ea69d4c32789c',
            iterations => 40000,
          }
        MANIFEST
    end

    step "verify the password was set correctly and is able to log in" do
      on(agent, "dscl /Local/Default -authonly testuser helloworld", :acceptable_exit_codes => 0)
    end

    unless agent['platform'] =~ /osx-11/
      skip_test "AuthenticationAuthority field fix test is not valid for macOS older than Big Sur (11.0)"
    end

    # Setting up environment to mimic situation on macOS 11 BigSur
    # Prior to macOS BigSur, `dscl . -create` was populating more fields with
    # default values, including AuthenticationAuthority which contains the
    # ShadowHash type
    # Withouth this field, login is not allowed
    step "remove AuthenticationAuthority field from user" do
      on(agent, "dscl /Local/Default -delete Users/testuser AuthenticationAuthority", :acceptable_exit_codes => 0)
    end

    step "expect user without AuthenticationAuthority to not be able to log in" do
      on(agent, "dscl /Local/Default -authonly testuser helloworld", :acceptable_exit_codes => (1..255))
    end

    # Expecting Puppet to pick up the missing field and add it to
    # make the user usable again
    step "change password with different salt and expect AuthenticationAuthority field to be readded" do
      # The password is still 'helloworld' but with different salt
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user { 'testuser':
            ensure => present,
            password   => '7e8e82542a0c06595e99bfe10c6bd219d19dede137c5c2f84bf10d98d83b77302d3c9c7f7e3652d420f562613f582ab62b26a52b9b26d0d032efbd486fd865b3ba4fd8a3512137681ce87d190f8fa7848d941c6080c588528dcb682c763c040ff54992dce204c3e5dda973e7b36f7f50a774e55e99fe4c8ed6b6464614838c13',
            salt       => '8005b8855a187086a3b59eff925a611ec61d2d66d2e786b7598fe0a0b4b8ffba',
            iterations => 40000
          }
        MANIFEST
        
        assert_match(/User 'testuser' is missing the 'SALTED-SHA512-PBKDF2' AuthenticationAuthority key for ShadowHash/, result.stdout)
        assert_match(/Adding 'SALTED-SHA512-PBKDF2' AuthenticationAuthority key for ShadowHash to user 'testuser'/, result.stdout)
      end
    end

    step "verify the password was set correctly and is able to log in" do
      on(agent, "dscl /Local/Default -authonly testuser helloworld", :acceptable_exit_codes => 0)
    end
  end
end
