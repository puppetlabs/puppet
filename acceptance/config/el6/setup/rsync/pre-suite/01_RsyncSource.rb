test_name "Rsync Source" do

  hosts.each do |host|
    step "rsyncing local puppet source to #{host}" do
      filter_opt = "--filter='merge #{ENV['RSYNC_FILTER_FILE']}'" if ENV['RSYNC_FILTER_FILE']
      destination_dir = case host['platform']
      when /debian|ubuntu/
        then '/usr/lib/ruby/vendor_ruby'
      else
        raise "We should actually do some #{host['platform']} platform specific rsyncing here..."
      end
      cmd = "rsync -r --exclude '.*.swp' #{filter_opt} --size-only -i -e'ssh -i id_rsa-acceptance' ../../../lib/* root@#{host}:#{destination_dir}"
      puts "RSYNC: #{cmd}"
      result = `#{cmd}`
      raise("Failed rsync execution:\n#{result}") if $? != 0
      puts result
    end
  end
end
