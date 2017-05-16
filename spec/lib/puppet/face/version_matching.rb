require 'puppet/face'

# The set of versions here are used explicitly in the interface_spec; if you
# change this you need to ensure that is still correct. --daniel 2011-04-21
['1.0.0', '1.0.1', '1.1.0', '1.1.1', '2.0.0'].each do |version|
  Puppet::Face.define(:version_matching, version) do
    copyright "Puppet Inc.", 2011
    license   "Apache 2 license; see COPYING"
    summary "version matching face #{version}"
    action(:version) { when_invoked { |options| version } }
  end
end
