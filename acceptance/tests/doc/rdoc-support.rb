test_name "Verify that puppet RDOC support is available"
# See:
#     https://jira.puppetlabs.com/browse/PE-1329
#     https://jira.puppetlabs.com/browse/QA-508

step "Run puppet doc --mode rdoc" do
  manifestdir = master.tmpdir('manifestdir')
  on(master, "puppet doc --mode rdoc --manifestdir #{manifestdir} --modulepath #{master['distmoduledir']} --outputdir doc")
end
