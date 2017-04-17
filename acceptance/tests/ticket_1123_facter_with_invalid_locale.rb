test_name "ticket 1123  facter should not crash with invalid locale setting"
confine :except, :platform => 'windows'
agents.each do |host|
  step "set an invalid value for locale and run facter"
  on host,( "LANG=ABCD facter facterversion"), :acceptable_exit_codes => [ 0 , 2 ]
end

