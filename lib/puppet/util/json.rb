# A simple module to provide consistency between how we use JSON and how 
# ruby expects it to be used.  Basically, we don't want to require
# that the sender specify a class.
#  Ruby wants everyone to provide a 'json_class' field, and the JSON support
# requires such a field to track the class down.  Because we use our URL to
# figure out what class we're working on, we don't need that, and we don't want
# our consumers and producers to need to know anything about our internals.
module Puppet::Util::Json
    def json_create(json)
        raise ArgumentError, "No data provided in json data" unless json['data']
        from_json(json['data'])
    end
end
