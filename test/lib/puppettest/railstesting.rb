module PuppetTest::RailsTesting
    Parser = Puppet::Parser
    AST = Puppet::Parser::AST
    include PuppetTest::ParserTesting

    def teardown
        super

        # If we don't clean up the connection list, then the rails
        # lib will still think it's connected.
        if Puppet.features.rails?
            ActiveRecord::Base.clear_active_connections!
        end
    end

    def railsinit
        Puppet::Rails.init
    end

    def railsteardown
        if Puppet[:dbadapter] != "sqlite3"
            Puppet::Rails.teardown
        end
    end

    def railsresource(type = "file", title = "/tmp/testing", params = {})
        railsteardown
        railsinit

        # We need a host for resources
        #host = Puppet::Rails::Host.new(:name => Facter.value("hostname"))

        # Now build a resource
        resources = []
        resources << mkresource(:type => type, :title => title, :exported => true,
                   :parameters => params)

        # Now collect our facts
        facts = Facter.to_hash

        # Now try storing our crap
        host = nil
        node = mknode(facts["hostname"])
        node.parameters = facts
        assert_nothing_raised {
            host = Puppet::Rails::Host.store(node, resources)
        }

        # Now save the whole thing
        host.save
    end
end

