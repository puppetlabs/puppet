shared_examples_for "Puppet::Indirector::FileServerTerminus" do
  # This only works if the shared behaviour is included before
  # the 'before' block in the including context.
  before do
    Puppet::FileServing::Configuration.instance_variable_set(:@configuration, nil)
    allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
    allow(Puppet::FileSystem).to receive(:exist?).with(Puppet[:fileserverconfig]).and_return(true)

    @path = Tempfile.new("file_server_testing")
    path = @path.path
    @path.close!
    @path = path

    Dir.mkdir(@path)
    File.open(File.join(@path, "myfile"), "w") { |f| f.print "my content" }

    # Use a real mount, so the integration is a bit deeper.
    @mount1 = Puppet::FileServing::Configuration::Mount::File.new("one")
    @mount1.path = @path

    @parser = double('parser', :changed? => false)
    allow(@parser).to receive(:parse).and_return("one" => @mount1)

    allow(Puppet::FileServing::Configuration::Parser).to receive(:new).and_return(@parser)

    # Stub out the modules terminus
    @modules = double('modules terminus')

    @request = Puppet::Indirector::Request.new(:indirection, :method, "puppet://myhost/one/myfile", nil)
  end

  it "should use the file server configuration to find files" do
    allow(@modules).to receive(:find).and_return(nil)
    allow(@terminus.indirection).to receive(:terminus).with(:modules).and_return(@modules)

    expect(@terminus.find(@request)).to be_instance_of(@test_class)
  end
end
