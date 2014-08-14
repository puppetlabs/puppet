if master.graceful_restarts?
  on(master, puppet('resource', 'service', master['puppetservice'], "ensure=running"))
end
