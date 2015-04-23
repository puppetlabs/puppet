if master['platform'] =~ /^el-|^fedora-/
  master.uses_passenger!('httpd')
  master['graceful-restarts'] = false # workaround BKR-221
else
  master.uses_passenger!('apache2')
end
