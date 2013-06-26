test_name "Write to Windows eventlog"

confine :to, :platform => 'windows'

def get_cmd(host)
  if options[:type] =~ /pe/
    "#{host['puppetbindir']}/ruby"
  else
    'ruby'
  end
end

agents.each do |agent|
  # get remote time
  now = on(agent, "#{get_cmd(agent)} -e \"puts Time.now.utc.strftime('%m/%d/%Y %H:%M:%S')\"").stdout.chomp

  # it should fail to start since parent directories don't exist
  confdir = "/does/not/exist"

  # generate an error, no master on windows boxes
  on agent, puppet_agent('--server', '127.0.0.1', '--test', '--confdir', confdir), :acceptable_exit_codes => [1]

  # make sure there's a Puppet error message in the log
  # cygwin + ssh + wmic hangs trying to read stdin, so echo '' |
  on agent, "cmd /c echo '' | wmic ntevent where \"LogFile='Application' and SourceName='Puppet' and TimeWritten >= '#{now}'\"  get Message,Type /format:csv" do
    fail_test "Event not found in Application event log" unless
      stdout =~ /Cannot create [a-z]:\/does\/not\/exist.*,Error/mi
  end
end
