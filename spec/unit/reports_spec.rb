require 'spec_helper'

require 'puppet/reports'

describe Puppet::Reports do
  it "should instance-load report types" do
    expect(Puppet::Reports.instance_loader(:report)).to be_instance_of(Puppet::Util::Autoload)
  end

  it "should have a method for registering report types" do
    expect(Puppet::Reports).to respond_to(:register_report)
  end

  it "should have a method for retrieving report types by name" do
    expect(Puppet::Reports).to respond_to(:report)
  end

  it "should provide a method for returning documentation for all reports" do
    expect(Puppet::Reports).to receive(:loaded_instances).with(:report).and_return([:one, :two])
    one = double('one', :doc => "onedoc")
    two = double('two', :doc => "twodoc")
    expect(Puppet::Reports).to receive(:report).with(:one).and_return(one)
    expect(Puppet::Reports).to receive(:report).with(:two).and_return(two)

    doc = Puppet::Reports.reportdocs
    expect(doc.include?("onedoc")).to be_truthy
    expect(doc.include?("twodoc")).to be_truthy
  end
end

describe Puppet::Reports, " when loading report types" do
  it "should use the instance loader to retrieve report types" do
    expect(Puppet::Reports).to receive(:loaded_instance).with(:report, :myreporttype)
    Puppet::Reports.report(:myreporttype)
  end
end

describe Puppet::Reports, " when registering report types" do
  it "should evaluate the supplied block as code for a module" do
    expect(Puppet::Reports).to receive(:genmodule).and_return(Module.new)
    Puppet::Reports.register_report(:testing) { }
  end

  it "should allow a successful report to be reloaded" do
    Puppet::Reports.register_report(:testing) { }
    Puppet::Reports.register_report(:testing) { }
  end

  it "should allow a failed report to be reloaded and show the correct exception both times" do
    expect { Puppet::Reports.register_report(:testing) { raise TypeError, 'failed report' } }.to raise_error(TypeError)
    expect { Puppet::Reports.register_report(:testing) { raise TypeError, 'failed report' } }.to raise_error(TypeError)
  end

  it "should extend the report type with the Puppet::Util::Docs module" do
    mod = double('module', :define_method => true)

    expect(Puppet::Reports).to receive(:genmodule).with(anything, hash_including(extend: Puppet::Util::Docs)).and_return(mod)
    Puppet::Reports.register_report(:testing) { }
  end

  it "should define a :report_name method in the module that returns the name of the report" do
    mod = double('module')
    expect(mod).to receive(:define_method).with(:report_name)

    expect(Puppet::Reports).to receive(:genmodule).and_return(mod)
    Puppet::Reports.register_report(:testing) { }
  end
end
