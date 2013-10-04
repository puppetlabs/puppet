require 'puppet/util/feature'

# We have a version of RDoc compatible with our module documentation tool.
# That is to say, we have the version that comes with Ruby 1.8.7 and earlier,
# and not the version that comes with Ruby 1.9.1 or later.
#
# 1.8 => require 'rdoc/rdoc'; p RDoc::RDoc::VERSION_STRING
#        => "RDoc V1.0.1 - 20041108"
# 1.9 => require 'rdoc'; p RDoc::VERSION
#        => "3.9.4"  # 1.9.2 has 2.5, 1.9.3 has 3.9
#
# Anything above that whole 1.0.1 thing is no good for us, and since that
# ships with anything in the 1.8 series that we care about (eg: .5, ,7) we can
# totally just use that as a proxy for the correct version of rdoc being
# available. --daniel 2012-03-08
Puppet.features.add(:rdoc1) { RUBY_VERSION[0,3] == "1.8" }
