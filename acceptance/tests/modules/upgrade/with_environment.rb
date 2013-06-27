test_name "puppet module upgrade (with environment)"

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

teardown do
  on master, "rm -rf #{master['puppetpath']}/testenv #{master['puppetpath']}/puppet2.conf"
end

on master, puppet("module install pmtacceptance-java --config=#{master['puppetpath']}/puppet2.conf --version 1.6.0 --environment=testenv")
on master, puppet("module list --config=#{master['puppetpath']}/puppet2.conf --modulepath #{master['puppetpath']}/testenv/modules") do
  assert_output <<-OUTPUT
    #{master['puppetpath']}/testenv/modules
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

step "Upgrade a module that has a more recent version published"
on master, puppet("module upgrade pmtacceptance-java --config=#{master['puppetpath']}/puppet2.conf --environment=testenv") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['puppetpath']}/testenv/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    #{master['puppetpath']}/testenv/modules
    └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
  on master, "[ -d #{master['puppetpath']}/testenv/modules/java ]"
  on master, "[ -f #{master['puppetpath']}/testenv/modules/java/Modulefile ]"
  on master, "grep 1.7.1 #{master['puppetpath']}/testenv/modules/java/Modulefile"
end
