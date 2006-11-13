module PuppetTest::RailsTesting
    Parser = Puppet::Parser
    AST = Puppet::Parser::AST
    include PuppetTest::ParserTesting

    def railsinit
        Puppet::Rails.init
    end

    def railsresource(type = "file", title = "/tmp/testing", params = {})
        railsinit
        
        # We need a host for resources
        host = Puppet::Rails::Host.new(:name => Facter.value("hostname"))

        # Now build a resource
        resource = host.rails_resources.build(
            :title => title, :restype => type,
            :exported => true
        )

        # Now add some params
        params.each do |param, value|
            resource.rails_parameters.build(
                :name => param, :value => value
            )
        end

        # Now save the whole thing
        host.save
    end
end

# $Id$
