#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

describe Puppet::Type.type(:cron).provider(:crontab) do
    before :each do
        @cron_type = Puppet::Type.type(:cron)
        @provider = @cron_type.provider(:crontab)
    end

    it "should round-trip the name as a comment for @special events" do
        parse = @provider.parse <<-CRON
# Puppet Name: test
@reboot /bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        @provider.to_line(prefetch[0]).should =~ /Puppet Name: test/
    end

end
