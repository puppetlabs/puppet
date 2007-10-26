require 'autotest'

Autotest.add_discovery do
  "rspec"
end

Autotest.add_discovery do
  "puppet"
end
