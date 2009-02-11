# This is just syntactic sugar for a collection, although it will generally
# be a good bit faster.

Puppet::Parser::Functions::newfunction(:realize, :doc => "Make a virtual object real.  This is useful
        when you want to know the name of the virtual object and don't want to
        bother with a full collection.  It is slightly faster than a collection,
        and, of course, is a bit shorter.  You must pass the object using a
        reference; e.g.: ``realize User[luke]``." ) do |vals|
        coll = Puppet::Parser::Collector.new(self, :nomatter, nil, nil, :virtual)
        vals = [vals] unless vals.is_a?(Array)
        coll.resources = vals.flatten

        compiler.add_collection(coll)
end
