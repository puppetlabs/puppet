platforms = hosts.map{|val| val[:platform]}
skip_test "No arista hosts present" unless platforms.any? { |val| /eos/ =~ val }
test_name 'Arista Switch Pre-suite' do
  masters = select_hosts({:roles => ['master', 'compile_master']})
  switchs = select_hosts({:platform => ['eos-4-i386']})

  step 'install Arista Module on masters' do
    masters.each do |node|
      on(node, puppet('module','install','aristanetworks-netdev_stdlib_eos'))
    end
  end

  step 'add puppet user to switch' do
    switchs.each do |switch|
      on(switch, "useradd -M -N -r -s /sbin/nologin -c \"Privileged Puppet account\" -g 0 puppet")
    end
  end
end
