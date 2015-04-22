if master['passenger']
  master.uses_passenger!
else
  master['use-service'] = true
end
