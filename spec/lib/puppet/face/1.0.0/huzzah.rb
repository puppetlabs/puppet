require 'puppet/face'
Puppet::Face.define(:huzzah, '1.0.0') do
  copyright "Puppet Inc.", 2011
  license   "Apache 2 license; see COPYING"
  summary "life is a thing for celebration"
  action(:obsolete_in_core) { when_invoked { |_| "you are in obsolete core now!" } }
  action(:call_newer) { when_invoked { |_| method_on_newer } }
end
