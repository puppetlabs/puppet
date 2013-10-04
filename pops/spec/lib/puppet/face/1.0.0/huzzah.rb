require 'puppet/face'
Puppet::Face.define(:huzzah, '1.0.0') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"
  summary "life is a thing for celebration"
  script :obsolete_in_core do |_| "you are in obsolete core now!" end
  script :call_newer do |_| method_on_newer end
end
