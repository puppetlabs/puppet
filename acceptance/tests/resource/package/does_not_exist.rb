# Redmine (#22529)
test_name "Puppet returns only resource package declaration when querying an uninstalled package" do

  tag 'audit:high',
      'audit:acceptance' # Could be done at the integration (or unit) layer though
                         # actual changing of resources could irreparably damage a
                         # host running this, or require special permissions.

  agents.each do |agent|

    step "test puppet resource package" do
      on(agent, puppet('resource', 'package', 'not-installed-on-this-host')) do
        assert_match(/package.*not-installed-on-this-host.*\n.*ensure.*(?:absent|purged).*\n.*provider/, stdout)
      end
    end

  end

  # Until #3707 is fixed and purged rpm/yum packages no longer give spurious creation notices
  # Also skipping solaris, windows whose providers do not have purgeable implemented.
  confine_block(:to, :platform => /debian|ubuntu/) do
    agents.each do |agent|
      step "test puppet apply" do
        on(agent, puppet('apply', '-e', %Q|"package {'not-installed-on-this-host': ensure => purged }"|)) do
          refute_match(/warning/i, stdout)
        end
      end
    end
  end
end
