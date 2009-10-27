#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

describe Puppet::Type.type(:cron) do
    before do
        @cron = Puppet::Type.type(:cron).new( :name => "foo" )
    end

    it "it should accept an :environment that looks like a path" do
        lambda do
            @cron[:environment] = 'PATH=/bin:/usr/bin:/usr/sbin'
        end.should_not raise_error
    end

    it "should not accept environment variables that do not contain '='" do
        lambda do
            @cron[:environment] = "INVALID"
        end.should raise_error(Puppet::Error)
    end

    it "should accept empty environment variables that do not contain '='" do
        lambda do
            @cron[:environment] = "MAILTO="
        end.should_not raise_error(Puppet::Error)
    end

    it "should accept 'absent'" do
        lambda do
            @cron[:environment] = 'absent'
        end.should_not raise_error(Puppet::Error)
    end
end
