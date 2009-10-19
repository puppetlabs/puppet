#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

provider = Puppet::Type.type(:package).provider(:dpkg)

describe provider do
    before do
        @resource = stub 'resource', :[] => "asdf"
        @provider = provider.new(@resource)

        @fakeresult = "install ok installed asdf 1.0\n"
    end

    it "should have documentation" do
        provider.doc.should be_instance_of(String)
    end

    describe "when listing all instances" do
        before do
            provider.stubs(:command).with(:dpkgquery).returns "myquery"
        end

        it "should use dpkg-query" do
            provider.expects(:command).with(:dpkgquery).returns "myquery"
            provider.expects(:execpipe).with("myquery -W --showformat '${Status} ${Package} ${Version}\\n'").returns @fakeresult

            provider.instances
        end

        it "should create and return an instance with each parsed line from dpkg-query" do
            pipe = mock 'pipe'
            pipe.expects(:each).yields @fakeresult
            provider.expects(:execpipe).yields pipe

            asdf = mock 'pkg1'
            provider.expects(:new).with(:ensure => "1.0", :error => "ok", :desired => "install", :name => "asdf", :status => "installed", :provider => :dpkg).returns asdf

            provider.instances.should == [asdf]
        end

        it "should warn on and ignore any lines it does not understand" do
            pipe = mock 'pipe'
            pipe.expects(:each).yields "foobar"
            provider.expects(:execpipe).yields pipe

            Puppet.expects(:warning)
            provider.expects(:new).never

            provider.instances.should == []
        end
    end

    describe "when querying the current state" do
        it "should use dpkg-query" do
            @provider.expects(:dpkgquery).with("-W", "--showformat",'${Status} ${Package} ${Version}\\n', "asdf").returns @fakeresult

            @provider.query
        end

        it "should consider the package purged if dpkg-query fails" do
            @provider.expects(:dpkgquery).raises Puppet::ExecutionFailure.new("eh")

            @provider.query[:ensure].should == :purged
        end

        it "should return a hash of the found status with the desired state, error state, status, name, and 'ensure'" do
            @provider.expects(:dpkgquery).returns @fakeresult

            @provider.query.should == {:ensure => "1.0", :error => "ok", :desired => "install", :name => "asdf", :status => "installed", :provider => :dpkg}
        end

        it "should consider the package absent if the dpkg-query result cannot be interpreted" do
            @provider.expects(:dpkgquery).returns "somebaddata"

            @provider.query[:ensure].should == :absent
        end

        it "should fail if an error is discovered" do
            @provider.expects(:dpkgquery).returns @fakeresult.sub("ok", "error")

            lambda { @provider.query }.should raise_error(Puppet::Error)
        end

        it "should consider the package purged if it is marked 'not-installed'" do
            @provider.expects(:dpkgquery).returns @fakeresult.sub("installed", "not-installed")

            @provider.query[:ensure].should == :purged
        end

        it "should consider the package absent if its status is neither 'installed' nor 'not-installed'" do
            @provider.expects(:dpkgquery).returns @fakeresult.sub("installed", "foo")

            @provider.query[:ensure].should == :absent
        end
    end

    it "should be able to install" do
        @provider.should respond_to(:install)
    end

    describe "when installing" do
        before do
            @resource.stubs(:[]).with(:source).returns "mypkg"
        end

        it "should fail to install if no source is specified in the resource" do
            @resource.expects(:[]).with(:source).returns nil

            lambda { @provider.install }.should raise_error(ArgumentError)
        end

        it "should use 'dpkg -i' to install the package" do
            @resource.expects(:[]).with(:source).returns "mypackagefile"
            @provider.expects(:dpkg).with { |*command| command[-1] == "mypackagefile"  and command[-2] == "-i" }

            @provider.install
        end

        it "should keep old config files if told to do so" do
            @resource.expects(:[]).with(:configfiles).returns :keep
            @provider.expects(:dpkg).with { |*command| command[0] == "--force-confold" }

            @provider.install
        end

        it "should replace old config files if told to do so" do
            @resource.expects(:[]).with(:configfiles).returns :replace
            @provider.expects(:dpkg).with { |*command| command[0] == "--force-confnew" }

            @provider.install
        end
    end

    it "should use :install to update" do
        @provider.expects(:install)
        @provider.update
    end

    describe "when determining latest available version" do
        it "should return the version found by dpkg-deb" do
            @resource.expects(:[]).with(:source).returns "myfile"
            @provider.expects(:dpkg_deb).with { |*command| command[-1] == "myfile" }.returns "asdf\t1.0"
            @provider.latest.should == "1.0"
        end

        it "should warn if the package file contains a different package" do
            @provider.expects(:dpkg_deb).returns("foo\tversion")
            @provider.expects(:warning)
            @provider.latest
        end

        it "should cope with names containing ++" do
            @resource = stub 'resource', :[] => "asdf++"
            @provider = provider.new(@resource)
            @provider.expects(:dpkg_deb).returns "asdf++\t1.0"
            @provider.latest.should == "1.0"
        end
    end

    it "should use 'dpkg -r' to uninstall" do
        @provider.expects(:dpkg).with("-r", "asdf")
        @provider.uninstall
    end

    it "should use 'dpkg --purge' to purge" do
        @provider.expects(:dpkg).with("--purge", "asdf")
        @provider.purge
    end
end
