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
      on(host, "echo \"[main]\nparser=future\n\" >> '#{puppet_conf}'")
    end
  end
end
