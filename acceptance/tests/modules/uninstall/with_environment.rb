test_name 'puppet module uninstall (with environment)'

teardown do
on master, "rm -rf #{master['puppetpath']}/testenv #{master['puppetpath']}/puppet2.conf"
end

step 'Setup'

stub_forge_on(master)

# Configure a non-default environment
on master, "rm -rf #{master['puppetpath']}/testenv"
apply_manifest_on master, %Q{
  file {
    [
      '#{master['puppetpath']}/testenv',
      '#{master['puppetpath']}/testenv/modules',
      '#{master['puppetpath']}/testenv/modules/crakorn',
    ]:
      ensure => directory,
  }
  file {
    '#{master['puppetpath']}/testenv/modules/crakorn/metadata.json':
      content => '{
        "name": "jimmy/crakorn",
        "version": "0.4.0",
        "source": "",
        "author": "jimmy",
        "license": "MIT",
        "dependencies": []
      }',
  }
  file {
    '#{master['puppetpath']}/puppet2.conf':
      source => $settings::config,
  }
}
on master, %Q{{ echo "[testenv]"; echo "modulepath=#{master['puppetpath']}/testenv/modules"; } >> #{master['puppetpath']}/puppet2.conf}

step 'Uninstall a module from a non default environment'
on master, "puppet module uninstall jimmy-crakorn --config=#{master['puppetpath']}/puppet2.conf --environment=testenv" do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from #{master['puppetpath']}/testenv/modules
  OUTPUT
end
on master, "[ ! -d #{master['puppetpath']}/testenv/modules/crakorn ]"
