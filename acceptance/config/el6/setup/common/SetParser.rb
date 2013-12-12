test_name "add parser=#{ENV['PARSER']} to all puppet.conf (only if $PARSER is set)" do

  parser = ENV['PARSER']
  next if parser.nil?

  hosts.each do |host|
    step "adjust #{host} puppet.conf" do
      temp = host.tmpdir('parser-set')
      opts = {
        'main' => {
           'parser' => parser
        }
      }
      lay_down_new_puppet_conf(host, opts, temp)
    end
  end
end
