test_name "add parser=#{ENV['PARSER']} to all puppet.conf (only if $PARSER is set)" do

  parser = ENV['PARSER']
  next if parser.nil?

  hosts.each do |host|
    step "adjust #{host} puppet.conf" do
      # Future parser tests execute against `git` style
      # acceptance, which does not create a default puppet.conf.
      # And due to PUP-4755, we can't use `puppet config set`
      # otherwise the setting is created outside of any section
      # which makes it appear future parser is not enabled.
      puppet_conf = host.puppet['config']
      on(host, "grep '[main]' #{puppet_conf}", :acceptable_exit_codes => [0,1,2]) do |result|
        case result.exit_code
        when 0
          # there is an assumption here that if a [main] section is present, it
          # has settings otherwise PUP-4755 comes back into play, though
          # 'global' settings should still end up in main when Puppet parses
          on(host, puppet("config set --section main parser #{parser}"))
        else
          # not found (1), or file not present (2)
          on(host, "echo \"[main]\nparser=future\n\" >> '#{puppet_conf}'")
        end
      end
    end
  end
end
