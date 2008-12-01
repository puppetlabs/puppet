#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

zone = Puppet::Type.type(:zone)

describe zone do
    before do
        @provider = stub 'provider'
        @resource = stub 'resource', :resource => nil, :provider => @provider, :line => nil, :file => nil
    end

    parameters = [:create_args, :install_args]

    parameters.each do |parameter|
        it "should have a %s parameter" % parameter do
            zone.attrclass(parameter).ancestors.should be_include(Puppet::Parameter)
        end
    end
end
