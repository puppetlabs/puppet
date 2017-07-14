# (PA-466) The env_windows_installdir fact is set as an environment variable
# fact via environment.bat on Windows systems. Test to ensure it is both
# present and accurate.
test_name 'PA-466: Ensure env_windows_installdir fact is present and correct' do

  tag 'audit:low',       # important runtime environment/packaging integration, rarely changed?
      'audit:delete',    # Move to puppet-agent suite
      'audit:acceptance'

  confine :to, :platform => 'windows'

  require 'json'

  agents.each do |agent|
    step "test for presence/accuracy of fact on #{agent}" do
      platform = agent[:platform]
      ruby_arch = agent[:ruby_arch] || 'x86' # ruby_arch defaults to x86 if nil

      install_dir = platform =~ /-64$/ && ruby_arch == 'x86' ?
        "C:\\Program Files (x86)\\Puppet Labs\\Puppet" :
        "C:\\Program Files\\Puppet Labs\\Puppet"

      on agent, puppet('facts', '--render-as json') do |result|
        facts = JSON.parse(result.stdout)
        actual_value = facts["values"]["env_windows_installdir"]
        assert_equal(install_dir, actual_value, "env_windows_installdir fact did not match expected output")
      end
    end
  end
end
