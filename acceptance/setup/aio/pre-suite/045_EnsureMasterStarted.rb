on(master, puppet('resource', 'service', master['puppetservice'], "ensure=running"))
