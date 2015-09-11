test_name "Expunge puppet bits if hypervisor is none"

confine :to, :platform => 'sparc'

# Ensure that the any previous installations of puppet
# are removed from the host if it is not managed by a
# provisioning hypervisor on sparc solaris.

hosts.each do |host|
  if host[:hypervisor] == "none"
    on(host, "pkginfo | grep puppet | cut -f2 -d ' ' | xargs pkgrm -n -a noask", :acceptable_exit_codes => [0,1])
    on(host, 'find / -name "*puppet*" -print | xargs rm -rf')
  end
end
