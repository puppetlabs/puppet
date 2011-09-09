require 'puppet/face'
Puppet::Face.define(:huzzah, '2.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"
  summary "life is a thing for celebration"
  script :bar do |options| "is where beer comes from" end
  script :call_older do |_| method_on_older end
end
