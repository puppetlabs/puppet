test_name 'puppet module list (with environment)'

step 'Setup'

stub_forge_on(master)

# Configure a non-default environment
on master, "rm -rf #{master['puppetpath']}/testenv"
apply_manifest_on master, %Q{
  file {
    [
      '#{master['puppetpath']}/testenv',
      '#{master['puppetpath']}/testenv/modules',
    ]:
      ensure => directory,
  }
  file {
    '#{master['puppetpath']}/puppet2.conf':
      source => $settings::config,
  }
}
on master, "{ echo '[testenv]'; echo 'modulepath=#{master['puppetpath']}/testenv/modules'; } >> #{master['puppetpath']}/puppet2.conf"
on master, "puppet module install pmtacceptance-nginx --config=#{master['puppetpath']}/puppet2.conf --environment=testenv"

teardown do
  on master, "rm -rf #{master['puppetpath']}/testenv #{master['puppetpath']}/puppet2.conf"
end

step 'List modules in a non default environment'
on master, puppet("module list --config=#{master['puppetpath']}/puppet2.conf --environment=testenv") do
  assert_match(/testenv\/modules/, stdout)
  assert_match(/pmtacceptance-nginx/, stdout)
end
