# Redmine (#22529)
test_name "Puppet returns only resource package declaration when querying an uninstalled package" do

  resource_declaration_regex = %r@package \{ 'not-installed-on-this-host':
  ensure => '(?:purged|absent)',
\}@m

  package_apply_regex = %r@Notice: Compiled catalog for .* in environment production in \d+\.\d{2} seconds(?:\e\[0m)?
(?:\e\[m)?Notice: Finished catalog run in \d+\.\d{2} seconds@m

  agents.each do |agent|

    step "test puppet resource package" do
      on(agent, puppet('resource', 'package', 'not-installed-on-this-host')) do
        assert_match(resource_declaration_regex, stdout)
      end
    end

  end

  # Until #3707 is fixed and purged rpm/yum packages no longer give spurious creation notices
  # Also skipping solaris, windows whose providers do not have purgeable implemented.
  confine_block(:to, :platform => /debian|ubuntu/) do
    agents.each do |agent|
      step "test puppet apply" do
        on(agent, puppet('apply', '-e', %Q|"package {'not-installed-on-this-host': ensure => purged }"|)) do
          assert_match(package_apply_regex, stdout)
          assert_equal('', stderr)
        end
      end
    end
  end
end
