test_name "puppet module uninstall (with modulepath)"

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

codedir = puppet_config(master, 'codedir', section: 'master')

teardown do
  on master, "rm -rf #{codedir}/modules2"
end

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '#{codedir}/modules2',
    '#{codedir}/modules2/crakorn',
    '#{codedir}/modules2/absolute',
  ]: ensure => directory;
  '#{codedir}/modules2/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
  '#{codedir}/modules2/absolute/metadata.json':
    content => '{
      "name": "jimmy/absolute",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
}
PP

on master, "[ -d #{codedir}/modules2/crakorn ]"
on master, "[ -d #{codedir}/modules2/absolute ]"

step "Try to uninstall the module jimmy-crakorn using relative modulepath"
on master, "cd #{codedir}/modules2 && puppet module uninstall jimmy-crakorn --modulepath=." do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from #{codedir}/modules2
  OUTPUT
end

on master, "[ ! -d #{codedir}/modules2/crakorn ]"

step "Try to uninstall the module jimmy-absolute using an absolute modulepath"
on master, "cd #{codedir}/modules2 && puppet module uninstall jimmy-absolute --modulepath=#{codedir}/modules2" do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to uninstall 'jimmy-absolute' ...\e[0m
Removed 'jimmy-absolute' (\e[0;36mv0.4.0\e[0m) from #{codedir}/modules2
  OUTPUT
end
on master, "[ ! -d #{codedir}/modules2/absolute ]"
