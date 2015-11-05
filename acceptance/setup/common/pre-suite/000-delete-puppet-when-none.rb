test_name "Expunge puppet bits if hypervisor is none"

# Ensure that the any previous installations of puppet
# are removed from the host if it is not managed by a
# provisioning hypervisor.

hosts.each do |host|
  if host[:hypervisor] == "none"
    remove_puppet_on(host)
  end
end
