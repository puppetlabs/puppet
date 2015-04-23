if master['passenger']
  if master['platform'] =~ /^el-|^fedora-/
    master.uses_passenger!('httpd')
  else
    master.uses_passenger!('apache2')
  end
else
  master['use-service'] = true
end
