# Check for the existance of keys found in puppet.conf in
# --configprint all output
#
# Checking against key=>val pairs will cause erroneous errors:
#
# classfile
# Puppet.conf           --configprint
# $vardir/classes.txt  /var/opt/lib/pe-puppet/classes.txt

test_name "Validate keys found in puppet.conf vs.--configprint all"

puppet_conf_h  = Hash.new
config_print_h = Hash.new

# Run tests against Master first
step "Master: get puppet.conf file contents"
on master, "cat #{master['puppetpath']}/puppet.conf | tr -d \" \"" do
  stdout.split("\n").select{ |v| v =~ /=/ }.each do |line|
    k,v = line.split("=")
    puppet_conf_h[k]=v 
  end
end

step "Master: get --configprint all output"
on master, puppet_master("--configprint all | tr -d \" \"") do
  stdout.split("\n").select{ |v| v =~ /=/ }.each do |line|
    k,v = line.split("=")
    config_print_h[k]=v 
  end
end

step "Master: compare puppet.conf to --configprint output"
puppet_conf_h.each do |k,v|
  puts "#{k}: #{puppet_conf_h[k]}  #{config_print_h[k]}"
  fail_test "puppet.conf contains a key not found in configprint" unless config_print_h.include?(k) 
  # fail_test "puppet.conf: #{puppet_conf_h[k]} differs from --configprintall: #{config_print_h[k]}" if ( puppet_conf_h[k] != config_print_h[k] )
end

# Run test on Agents
agents.each { |agent|
  puppet_conf_h.clear
  config_print_h.clear
  step "Agent #{agent}: get puppet.conf file contents"
  on agent, "cat #{master['puppetpath']}/puppet.conf | tr -d \" \"" do
    stdout.split("\n").select{ |v| v =~ /=/ }.each do |line|
      k,v = line.split("=")
      puppet_conf_h[k]=v 
    end
  end

  step "Agent #{agent}: get --configprint all output"
  on agent, puppet_agent("--configprint all | tr -d \" \"") do
    stdout.split("\n").select{ |v| v =~ /=/ }.each do |line|
      k,v = line.split("=")
      config_print_h[k]=v 
    end
  end

  step "Agent #{agent}: compare puppet.conf to --configprint output"
  puppet_conf_h.each do |k,v|
    puts "#{k}: #{puppet_conf_h[k]}  #{config_print_h[k]}"
    fail_test "puppet.conf contains a key not found in configprint" unless config_print_h.include?(k)
    # fail_test "puppet.conf: #{puppet_conf_h[k]} differs from --configprintall: #{config_print_h[k]}" if ( puppet_conf_h[k] != config_print_h[k] )
  end
}
