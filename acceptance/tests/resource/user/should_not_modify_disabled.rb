test_name 'PUP-6586 Ensure puppet does not continually reset password for disabled user' do

  confine :to, :platform => 'windows'

  tag 'audit:medium',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test

  name = "pl#{rand(99999).to_i}"

  teardown do
    agents.each do |agent|
      on(agent, puppet_resource('user', "#{name}", 'ensure=absent'))
    end
  end

  manifest = <<-MANIFEST
user {'#{name}':
  ensure    => present,
  password  => 'P@ssword!',
}
MANIFEST

  agents.each do |agent|
    step "create user #{name} with puppet" do
      apply_manifest_on(agent, manifest, :catch_failures => true)
    end

    step "disable user #{name}" do
      on(agent, "net user #{name} /ACTIVE:NO", :acceptable_exit_codes => 0)
    end

    step "test that password is not reset by puppet" do
      # :catch_changes will fail the test if there were changes during
      # run execution
      apply_manifest_on(agent, manifest, :catch_changes => true)
    end
  end
end


