platforms = hosts.map{|val| val[:platform]}
skip_test "No cumulus hosts present" unless platforms.any? { |val| /cumulus/ =~ val }
confine :to, {}, hosts.select { |host| host[:roles].include?('master') }

step 'install Cumulus Modules on masters' do
  hosts.each do |node|
    on(node, puppet('module','install','cumuluslinux-cumulus_license'))
    on(node, puppet('module','install','cumuluslinux-cumulus_interfaces'))
    on(node, puppet('module','install','cumuluslinux-cumulus_interface_policy'))
    on(node, puppet('module','install','cumuluslinux-cumulus_ports'))
  end
end
