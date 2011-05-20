#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/reports'

processor = Puppet::Reports.report(:rrdgraph)

describe processor do
  include PuppetSpec::Files
  before do
    Puppet[:rrddir] = tmpdir('rrdgraph')
    Puppet.settings.use :master
  end

  after do
    FileUtils.rm_rf(Puppet[:rrddir])
  end

  it "should not error on 0.25.x report format" do
    report = YAML.load_file(File.join(PuppetSpec::FIXTURE_DIR, 'yaml/report0.25.x.yaml')).extend processor
    report.expects(:mkhtml)
    lambda{ report.process }.should_not raise_error
  end

  it "should not error on 2.6.x report format" do
    report = YAML.load_file(File.join(PuppetSpec::FIXTURE_DIR, 'yaml/report2.6.x.yaml')).extend processor
    report.expects(:mkhtml)
    lambda{ report.process }.should_not raise_error
  end
end
