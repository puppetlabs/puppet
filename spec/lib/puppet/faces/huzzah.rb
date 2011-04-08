require 'puppet/faces'
Puppet::Faces.define(:huzzah, '2.0.1') do
  action :bar do "is where beer comes from" end
end
