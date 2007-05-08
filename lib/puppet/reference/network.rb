network = Puppet::Util::Reference.newreference :network, :depth => 2, :doc => "Available network handlers and clients" do
    ret = ""
    Puppet::Network::Handler.subclasses.sort { |a,b| a.to_s <=> b.to_s }.each do |name|
        handler = Puppet::Network::Handler.handler(name)

        next if ! handler.doc or handler.doc == ""

        interface = handler.interface

        ret += h(name, 2)

        ret += scrub(handler.doc)
        ret += "\n\n"
        ret += option(:prefix, interface.prefix)
        ret += option(:side, handler.side.to_s.capitalize)
        ret += option(:methods, interface.methods.collect { |ary| ary[0] }.join(", ") )
        ret += "\n\n"
    end

    ret
end

network.header = "
This is a list of all Puppet network interfaces.  Each interface is
implemented in the form of a client and a handler; the handler is loaded
on the server, and the client knows how to call the handler's methods
appropriately.

Most handlers are meant to be started on the server, usually within
``puppetmasterd``, and the clients are mostly started on the client,
usually within ``puppetd``.

You can find the server-side handler for each interface at
``puppet/network/handler/<name>.rb`` and the client class at
``puppet/network/client/<name>.rb``.

"
