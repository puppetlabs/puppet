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

      if !options[:install].empty? and parser == 'future'
        # We are installing from source rather than packages and need the following:
        win_cmd_prefix = 'cmd /c ' if host['platform'] =~ /windows/
        on(host, "#{win_cmd_prefix}gem install rgen")
      end
    end
  end
end
