#! /usr/bin/env ruby
shared_examples_for "Puppet::Indirector::FileServerTerminus" do
  # This only works if the shared behaviour is included before
  # the 'before' block in the including context.
  before do
    Puppet::FileServing::Configuration.instance_variable_set(:@configuration, nil)
    Puppet::FileSystem.stubs(:exist?).returns true
    Puppet::FileSystem.stubs(:exist?).with(Puppet[:fileserverconfig]).returns(true)

    @path = Tempfile.new("file_server_testing")
    path = @path.path
    @path.close!
    @path = path

    Dir.mkdir(@path)
    File.open(File.join(@path, "myfile"), "w") { |f| f.print "my content" }

    # Use a real mount, so the integration is a bit deeper.
    @mount1 = Puppet::FileServing::Configuration::Mount::File.new("one")
    @mount1.path = @path

    @parser = stub 'parser', :changed? => false
    @parser.stubs(:parse).returns("one" => @mount1)

    Puppet::FileServing::Configuration::Parser.stubs(:new).returns(@parser)

    # Stub out the modules terminus
    @modules = mock 'modules terminus'

    @request = Puppet::Indirector::Request.new(:indirection, :method, "puppet://myhost/one/myfile", nil)
  end

  it "should use the file server configuration to find files" do
    @modules.stubs(:find).returns(nil)
    @terminus.indirection.stubs(:terminus).with(:modules).returns(@modules)

    path = File.join(@path, "myfile")

    expect(@terminus.find(@request)).to be_instance_of(@test_class)
  end
end
