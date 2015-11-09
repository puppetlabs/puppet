test_name "add parser=#{ENV['PARSER']} to all puppet.conf (only if $PARSER is set)" do

  parser = ENV['PARSER']
  next if parser.nil?

  hosts.each do |host|
    step "adjust #{host} puppet.conf" do
      on(host, puppet("config set --section main parser #{parser}"))
    end
  end
end
