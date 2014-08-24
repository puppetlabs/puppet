if master['platform'] =~ /debian|ubuntu/
  master.uses_passenger!
elsif master['platform'] =~ /redhat|el|centos|scientific/
  master['use-service'] = true
end
