# A simple module to provide consistency between how we use PSON and how 
# ruby expects it to be used.  Basically, we don't want to require
# that the sender specify a class.
#  Ruby wants everyone to provide a 'type' field, and the PSON support
# requires such a field to track the class down.  Because we use our URL to
# figure out what class we're working on, we don't need that, and we don't want
# our consumers and producers to need to know anything about our internals.
module Puppet::Util::Pson
    def pson_create(pson)
        raise ArgumentError, "No data provided in pson data" unless pson['data']
        from_pson(pson['data'])
    end
end
