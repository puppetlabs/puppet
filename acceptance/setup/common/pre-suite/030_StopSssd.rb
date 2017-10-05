test_name "Stop sssd" do
  # The sssd service causes local users/groups to be cached,
  # which can cause unexpected results when tests are trying
  # to restore state. We ensure that it is not running to
  # prevent such caching from occurring.
  hosts.each do |host|
    on(host, puppet('resource', 'service', 'sssd', 'ensure=stopped'), :accept_all_exit_codes => true)
  end
end
