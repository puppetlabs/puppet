require 'spec_helper'
require 'tmpdir'
require 'fileutils'

# FIXME This are helper methods that could be used by other tests in the
# future, should we move these to a more central location
def stub_repository_read(code, body)
  kind = Net::HTTPResponse.send(:response_class, code.to_s)
  response = kind.new('1.0', code.to_s, 'HTTP MESSAGE')
  response.stubs(:read_body).returns(body)
  Puppet::Forge::Repository.any_instance.stubs(:read_response).returns(response)
end

describe "module_tool", :fails_on_windows => true do
  include PuppetSpec::Files
  before do
    @tmp_confdir = Puppet[:confdir] = tmpdir("module_tool_test_confdir")
    @tmp_vardir = Puppet[:vardir] = tmpdir("module_tool_test_vardir")
    @mytmpdir = Pathname.new(tmpdir("module_tool_test"))
    @options = {}
    @options[:dir] = @mytmpdir
    @current_dir = Dir.pwd
    Dir.chdir(@mytmpdir)
  end

  after do
    Dir.chdir(@current_dir)
  end

  def build_and_install_module
    Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
    Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

    FileUtils.mv("#{@full_module_name}/pkg/#{@release_name}.tar.gz", "#{@release_name}.tar.gz")
    FileUtils.rm_rf(@full_module_name)

    Puppet::Module::Tool::Applications::Installer.run("#{@release_name}.tar.gz", @options)
  end

  before :all do
    @username = "myuser"
    @module_name  = "mymodule"
    @full_module_name = "#{@username}-#{@module_name}"
    @version = "0.0.1"
    @release_name = "#{@full_module_name}-#{@version}"
  end

  describe "generate" do
    it "should generate a module if given a dashed name" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)

      File.directory?(@full_module_name).should == true
      modulefile = File.join(@full_module_name, "Modulefile")
      File.file?(modulefile).should == true
      metadata = Puppet::Module::Tool::Metadata.new
      Puppet::Module::Tool::ModulefileReader.evaluate(metadata, modulefile)
      metadata.full_module_name.should == @full_module_name
      metadata.username.should == @username
      metadata.name.should == @module_name
    end

    it "should fail if given an undashed name" do
      lambda { Puppet::Module::Tool::Applications::Generator.run("invalid") }.should raise_error(RuntimeError)
    end

    it "should fail if directory already exists" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      lambda { Puppet::Module::Tool::Applications::Generator.run(@full_module_name) }.should raise_error(ArgumentError)
    end

    it "should return an array of Pathname objects representing paths of generated files" do
      return_value = Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      return_value.each do |generated_file|
        generated_file.should be_kind_of(Pathname)
      end
      return_value.should be_kind_of(Array)
    end
  end

  describe "build" do
    it "should build a module in a directory" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

      File.directory?(File.join(@full_module_name, "pkg", @release_name)).should == true
      File.file?(File.join(@full_module_name, "pkg", @release_name + ".tar.gz")).should == true
      metadata_file = File.join(@full_module_name, "pkg", @release_name, "metadata.json")
      File.file?(metadata_file).should == true
      metadata = PSON.parse(File.read(metadata_file))
      metadata["name"].should == @full_module_name
      metadata["version"].should == @version
      metadata["checksums"].should be_a_kind_of(Hash)
      metadata["dependencies"].should == []
      metadata["types"].should == []
    end

    it "should build a module's checksums" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

      metadata_file = File.join(@full_module_name, "pkg", @release_name, "metadata.json")
      metadata = PSON.parse(File.read(metadata_file))
      metadata["checksums"].should be_a_kind_of(Hash)

      modulefile_path = Pathname.new(File.join(@full_module_name, "Modulefile"))
      metadata["checksums"]["Modulefile"].should == Digest::MD5.hexdigest(modulefile_path.read)
    end

    it "should build a module's types and providers" do
      name = "jamtur01-apache"

      release_fixture_dir = File.join(PuppetSpec::FIXTURE_DIR, "releases")
      release_fixture = File.join(release_fixture_dir, name)

      FileUtils.cp_r(release_fixture, name)

      Puppet::Module::Tool::Applications::Builder.run(name)

      metadata_file = File.join(name, "pkg", "#{name}-0.0.1", "metadata.json")
      metadata = PSON.parse(File.read(metadata_file))

      metadata["types"].size.should == 1
      type = metadata["types"].first
      type["name"].should == "a2mod"
      type["doc"].should == "Manage Apache 2 modules"


      type["parameters"].size.should == 1
      type["parameters"].first.tap do |o|
        o["name"].should == "name"
        o["doc"].should == "The name of the module to be managed"
      end

      type["properties"].size.should == 1
      type["properties"].first.tap do |o|
        o["name"].should == "ensure"
        o["doc"].should =~ /present.+absent/
      end

      type["providers"].size.should == 1
      type["providers"].first.tap do |o|
        o["name"].should == "debian"
        o["doc"].should =~ /Manage Apache 2 modules on Debian-like OSes/
      end
    end

    it "should build a module's dependencies" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      modulefile = File.join(@full_module_name, "Modulefile")

      dependency1_name = "anotheruser-anothermodule"
      dependency1_requirement = ">= 1.2.3"
      dependency2_name = "someuser-somemodule"
      dependency2_requirement = "4.2"
      dependency2_repository = "http://some.repo"

      File.open(modulefile, "a") do |handle|
        handle.puts "dependency '#{dependency1_name}', '#{dependency1_requirement}'"
        handle.puts "dependency '#{dependency2_name}', '#{dependency2_requirement}', '#{dependency2_repository}'"
      end

      Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

      metadata_file = File.join(@full_module_name, "pkg", "#{@full_module_name}-#{@version}", "metadata.json")
      metadata = PSON.parse(File.read(metadata_file))

      metadata['dependencies'].size.should == 2
      metadata['dependencies'].sort_by{|t| t['name']}.tap do |dependencies|
        dependencies[0].tap do |dependency1|
          dependency1['name'].should == dependency1_name
          dependency1['version_requirement'].should == dependency1_requirement
          dependency1['repository'].should be_nil
        end

        dependencies[1].tap do |dependency2|
          dependency2['name'].should == dependency2_name
          dependency2['version_requirement'].should == dependency2_requirement
          dependency2['repository'].should == dependency2_repository
        end
      end
    end

    it "should rebuild a module in a directory" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      Puppet::Module::Tool::Applications::Builder.run(@full_module_name)
      Puppet::Module::Tool::Applications::Builder.run(@full_module_name)
    end

    it "should build a module in the current directory" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      Dir.chdir(@full_module_name)
      Puppet::Module::Tool::Applications::Builder.run(Puppet::Module::Tool.find_module_root(nil))

      File.file?(File.join("pkg", @release_name + ".tar.gz")).should == true
    end

    it "should fail to build a module without a Modulefile" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      FileUtils.rm(File.join(@full_module_name, "Modulefile"))

      lambda { Puppet::Module::Tool::Applications::Builder.run(Puppet::Module::Tool.find_module_root(@full_module_name)) }.should raise_error(ArgumentError)
    end

    it "should fail to build a module directory that doesn't exist" do
      lambda { Puppet::Module::Tool::Applications::Builder.run(Puppet::Module::Tool.find_module_root(@full_module_name)) }.should raise_error(ArgumentError)
    end

    it "should fail to build a module in the current directory that's not a module" do
      lambda { Puppet::Module::Tool::Applications::Builder.run(Puppet::Module::Tool.find_module_root(nil)) }.should raise_error(ArgumentError)
    end

    it "should return a Pathname object representing the path to the release archive." do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      Puppet::Module::Tool::Applications::Builder.run(@full_module_name).should be_kind_of(Pathname)
    end
  end

  describe "search" do
    it "should display matching modules" do
      stub_repository_read 200, <<-HERE
        [
          {"full_module_name": "cli", "version": "1.0"},
          {"full_module_name": "web", "version": "2.0"}
        ]
      HERE
      Puppet::Module::Tool::Applications::Searcher.run("mymodule", @options).size.should == 2
    end

    it "should display no matches" do
      stub_repository_read 200, "[]"
      Puppet::Module::Tool::Applications::Searcher.run("mymodule", @options).should == []
    end

    it "should fail if can't get a connection" do
      stub_repository_read 500, "OH NOES!!1!"
      lambda { Puppet::Module::Tool::Applications::Searcher.run("mymodule", @options) }.should raise_error(RuntimeError)
    end

    it "should return an array of module metadata hashes" do
      results = <<-HERE
        [
          {"full_module_name": "cli", "version": "1.0"},
          {"full_module_name": "web", "version": "2.0"}
        ]
      HERE
      expected = [
        {"version"=>"1.0", "full_module_name"=>"cli"},
        {"version"=>"2.0", "full_module_name"=>"web"}
      ]
      stub_repository_read 200, results
      return_value = Puppet::Module::Tool::Applications::Searcher.run("mymodule", @options)
      return_value.should == expected
      return_value.should be_kind_of(Array)
    end
  end

  describe "install" do
    let(:tarball_contents) do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

      contents = File.read("#{@full_module_name}/pkg/#{@release_name}.tar.gz")
      FileUtils.rm_rf(@full_module_name)
      contents
    end

    it "should install a module to the puppet modulepath by default" do
      myothertmpdir = Pathname.new(tmpdir("module_tool_test_myothertmpdir"))
      @options[:dir] = myothertmpdir
      Puppet::Module::Tool.unstub(:dir)

      build_and_install_module

      File.directory?(myothertmpdir + @module_name).should == true
      File.file?(myothertmpdir + @module_name + 'metadata.json').should == true
    end

    it "should install a module from a filesystem path" do
      build_and_install_module

      File.directory?(@mytmpdir + @module_name).should == true
      File.file?(@mytmpdir + @module_name + 'metadata.json').should == true
    end

    it "should install a module from a webserver URL" do
      Puppet::Forge::Cache.any_instance.stubs(:read_retrieve).returns(tarball_contents)

      releases = {
       'myuser/mymodule' => [{
          'file'         => "/foo/bar/#{@release_name}.tar.gz",
          'version'      => @version,
          'dependencies' => []
        }]
      }
      Puppet::Forge::Forge.expects(:remote_dependency_info).returns(releases)

      Puppet::Module::Tool::Applications::Installer.run(@full_module_name, @options)

      File.directory?(@mytmpdir + @module_name).should == true
      File.file?(@mytmpdir + @module_name + 'metadata.json').should == true
    end

    it "should install a module from a webserver URL using a version requirement" # TODO

    it "should fail if module isn't a slashed name" do
      lambda { Puppet::Module::Tool::Applications::Installer.run("invalid") }.should raise_error(RuntimeError)
    end

    it "should fail if module doesn't exist on webserver" do
      Puppet::Forge::Forge.stubs(:remote_dependency_info).returns({})
      lambda { Puppet::Module::Tool::Applications::Installer.run("not-found", @options) }.should raise_error(RuntimeError)
    end

    it "should fail gracefully when receiving invalid PSON" do
      pending "Implement PSON error wrapper" # TODO
      Puppet::Forge::Forge.stubs(:remote_dependency_info).returns('1/0')
      lambda { Puppet::Module::Tool::Applications::Installer.run("not-found") }.should raise_error(SystemExit)
    end

    it "should fail if installing a module that's already installed" do
      name = "myuser-mymodule"
      Dir.mkdir name
      lambda { Puppet::Module::Tool::Applications::Installer.run(name) }.should raise_error(ArgumentError)
    end

    it "should return Pathname objects representing the paths to the installed modules" do
      Puppet::Forge::Cache.any_instance.stubs(:read_retrieve).returns(tarball_contents)

      releases = {
       'myuser/mymodule' => [{
          'file'         => "/foo/bar/#{@release_name}.tar.gz",
          'version'      => @version,
          'dependencies' => []
        }]
      }
      Puppet::Forge::Forge.expects(:remote_dependency_info).returns(releases)

      Puppet::Module::Tool::Applications::Installer.
        run(@full_module_name, @options).
        first.should be_kind_of(Pathname)
    end
  end

  describe "clean" do
    require 'puppet/module_tool'
    it "should clean cache" do
      build_and_install_module
      Puppet::Forge::Cache.base_path.directory?.should == true
      Puppet::Module::Tool::Applications::Cleaner.run
      Puppet::Forge::Cache.base_path.directory?.should == false
    end

    it "should return a status Hash" do
      build_and_install_module
      return_value = Puppet::Module::Tool::Applications::Cleaner.run
      return_value.should include(:msg)
      return_value.should include(:status)
      return_value.should be_kind_of(Hash)
    end
  end

  describe "changes" do
    it "should return an array of modified files" do
      Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
      Puppet::Module::Tool::Applications::Builder.run(@full_module_name)
      Dir.chdir("#{@full_module_name}/pkg/#{@release_name}")
      File.open("Modulefile", "a") do |handle|
        handle.puts
        handle.puts "# Added"
      end
      return_value = Puppet::Module::Tool::Applications::Checksummer.run(".")
      return_value.should include("Modulefile")
      return_value.should be_kind_of(Array)
    end
  end
end
