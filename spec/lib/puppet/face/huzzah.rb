require 'puppet/face'
Puppet::Face.define(:huzzah, '2.0.1') do
  summary "life is a thing for celebration"
  action :bar do "is where beer comes from" end
end
