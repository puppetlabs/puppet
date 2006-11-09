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
        resource = host.resources.build(
            :title => title, :exported => true
        )

        # Now add some params
        params.each do |param, value|
            pvalue = ParamValue.new(:value => value)
            resource.param_name.find_or_create_by_name(param).param_values << pvalue
        end

        # Now save the whole thing
        host.save
    end
end

# $Id$
