# 2010-08-02 Nan Liu
#
# http://projects.puppetlabs.com/issues/4289
#
# NL: Facter should return OS version instead of kernel version for OEL
# test script only applicable to OEL, provided based on ticked info, not verified.

test_name "#4289: facter should recognize OEL operatingsystemrelease"

# REVISIT: We don't actually have support for this yet - we need a "not
# applicable" option, I guess, that can be based on detected stuff, which is
# cleaner than this is... --daniel 2010-12-22
agents.each do |host|
  step "determine the operating system of #{host}"
  on host, facter("operatingsystem")
  if stdout =~ /oel/i then
    step "test operatingsystemrelease fact on OEL host #{host}"
    on host, facter("operatingsystemrelease")
    assert_match(/^\d\.\d$/, stdout, "operatingsystemrelease not as expected on #{host}")
  end
end
