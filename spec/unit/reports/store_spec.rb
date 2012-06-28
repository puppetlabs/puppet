#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/reports'
require 'time'

processor = Puppet::Reports.report(:store)

describe processor do
  describe "#process" do
    include PuppetSpec::Files
    before :each do
      Puppet[:reportdir] = tmpdir('reports') << '/reports' 
      @report = YAML.load_file(File.join(PuppetSpec::FIXTURE_DIR, 'yaml/report2.6.x.yaml')).extend processor
    end

    it "should create a report directory for the client if one doesn't exist" do
      @report.process

      File.should be_directory(File.join(Puppet[:reportdir], @report.host))
    end

    it "should write the report to the file in YAML" do
      Time.stubs(:now).returns(Time.parse("2011-01-06 12:00:00 UTC"))
      @report.process

      File.read(File.join(Puppet[:reportdir], @report.host, "201101061200.yaml")).should == @report.to_yaml
    end

    ['..', 'hello/', '/hello', 'he/llo', 'hello/..', '.'].each do |node|
      it "rejects #{node.inspect}" do
        @report.host = node
        expect { @report.process }.to raise_error(ArgumentError, /Invalid node/)
      end
    end

    ['.hello', 'hello.', '..hi', 'hi..'].each do |node|
      it "accepts #{node.inspect}" do
        @report.host = node
        @report.process
      end
    end
  end
end
