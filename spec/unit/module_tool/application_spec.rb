require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::Module::Tool::Applications::Application do
  describe 'app' do

    good_versions = %w{ 1.2.4 0.0.1 0.0.0 0.0.2git-8-g3d316d1 0.0.3b1 10.100.10000
                         0.1.2rc1 0.1.2dev-1 0.1.2svn12345 }
    bad_versions = %w{ 0.1.2-3 0.1 0 0.1.2.3 dev }

    before do
      @app = Class.new(described_class).new
    end

    good_versions.each do |ver|
      it "should accept version string #{ver}" do
        @app.instance_eval("@filename=%q{puppetlabs-ntp-#{ver}}")
        @app.parse_filename!
      end
    end

    bad_versions.each do |ver|
      it "should not accept version string #{ver}" do
        @app.instance_eval("@filename=%q{puppetlabs-ntp-#{ver}}")
        lambda { @app.parse_filename! }.should raise_error
      end
    end
  end
end
