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

def stub_installer_read(body)
  Puppet::Forge::Forge.stubs(:remote_dependency_info).returns(body)
end

def stub_cache_read(body)
  Puppet::Forge::Cache.any_instance.stubs(:read_retrieve).returns(body)
end

# Return path to temparory directory for testing.
def testdir
  return @testdir ||= tmpdir("module_tool_testdir")
end

# Create a temporary testing directory, change into it, and execute the
# +block+. When the block exists, remove the test directory and change back
# to the previous directory.
def mktestdircd(&block)
  previousdir = Dir.pwd
  rmtestdir
  FileUtils.mkdir_p(testdir)
  Dir.chdir(testdir)
  block.call
ensure
  rmtestdir
  Dir.chdir previousdir
end

# Remove the temporary test directory.
def rmtestdir
  FileUtils.rm_rf(testdir) if File.directory?(testdir)
end
# END helper methods


# Directory that contains sample releases.
RELEASE_FIXTURES_DIR = File.join(PuppetSpec::FIXTURE_DIR, "releases")

# Return the pathname string to the directory containing the release fixture called +name+.
def release_fixture(name)
  return File.join(RELEASE_FIXTURES_DIR, name)
end

# Copy the release fixture called +name+ into the current working directory.
def install_release_fixture(name)
  release_fixture(name)
  FileUtils.cp_r(release_fixture(name), name)
end

describe "module_tool", :fails_on_windows => true do
  include PuppetSpec::Files
  before do
    @tmp_confdir = Puppet[:confdir] = tmpdir("module_tool_test_confdir")
    @tmp_vardir = Puppet[:vardir] = tmpdir("module_tool_test_vardir")
    Puppet[:module_repository] = "http://forge.puppetlabs.com"
    @mytmpdir = Pathname.new(tmpdir("module_tool_test"))
    @options = {}
    @options[:dir] = @mytmpdir
    @options[:module_repository] = "http://forge.puppetlabs.com"
  end

  def build_and_install_module
    Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
    Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

    FileUtils.mv("#{@full_module_name}/pkg/#{@release_name}.tar.gz", "#{@release_name}.tar.gz")
    FileUtils.rm_rf(@full_module_name)

    Puppet::Module::Tool::Applications::Installer.run("#{@release_name}.tar.gz", @options)
  end

  # Return STDOUT and STDERR output generated from +block+ as it's run within a temporary test directory.
  def run(&block)
    mktestdircd do
      block.call
    end
  end

  before :all do
    @username = "myuser"
    @module_name  = "mymodule"
    @full_module_name = "#{@username}-#{@module_name}"
    @version = "0.0.1"
    @release_name = "#{@full_module_name}-#{@version}"
  end

  before :each do
    Puppet.settings.stubs(:parse)
    Puppet::Forge::Cache.clean
  end

  after :each do
    Puppet::Forge::Cache.clean
  end

  describe "generate" do
    it "should generate a module if given a dashed name" do
      run do
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
    end

    it "should fail if given an undashed name" do
      run do
        lambda { Puppet::Module::Tool::Applications::Generator.run("invalid") }.should raise_error(RuntimeError)
      end
    end

    it "should fail if directory already exists" do
      run do
        Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        lambda { Puppet::Module::Tool::Applications::Generator.run(@full_module_name) }.should raise_error(ArgumentError)
      end
    end

    it "should return an array of Pathname objects representing paths of generated files" do
      run do
        return_value = Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        return_value.each do |generated_file|
          generated_file.should be_kind_of(Pathname)
        end
        return_value.should be_kind_of(Array)
      end
    end
  end

  describe "build" do
    it "should build a module in a directory" do
      run do
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
    end

    it "should build a module's checksums" do
      run do
        Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

        metadata_file = File.join(@full_module_name, "pkg", @release_name, "metadata.json")
        metadata = PSON.parse(File.read(metadata_file))
        metadata["checksums"].should be_a_kind_of(Hash)

        modulefile_path = Pathname.new(File.join(@full_module_name, "Modulefile"))
        metadata["checksums"]["Modulefile"].should == Digest::MD5.hexdigest(modulefile_path.read)
      end
    end

    it "should build a module's types and providers" do
      run do
        name = "jamtur01-apache"
        install_release_fixture name
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
    end

    it "should build a module's dependencies" do
      run do
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
    end

    it "should rebuild a module in a directory" do
      run do
        Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        Puppet::Module::Tool::Applications::Builder.run(@full_module_name)
        Puppet::Module::Tool::Applications::Builder.run(@full_module_name)
      end
    end

    it "should build a module in the current directory" do
      run do
        Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        Dir.chdir(@full_module_name)
        Puppet::Module::Tool::Applications::Builder.run(Puppet::Module::Tool.find_module_root(nil))

        File.file?(File.join("pkg", @release_name + ".tar.gz")).should == true
      end
    end

    it "should fail to build a module without a Modulefile" do
      run do
        Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        FileUtils.rm(File.join(@full_module_name, "Modulefile"))

        lambda { Puppet::Module::Tool::Applications::Builder.run(Puppet::Module::Tool.find_module_root(@full_module_name)) }.should raise_error(ArgumentError)
      end
    end

    it "should fail to build a module directory that doesn't exist" do
      run do
        lambda { Puppet::Module::Tool::Applications::Builder.run(Puppet::Module::Tool.find_module_root(@full_module_name)) }.should raise_error(ArgumentError)
      end
    end

    it "should fail to build a module in the current directory that's not a module" do
      run do
        lambda { Puppet::Module::Tool::Applications::Builder.run(Puppet::Module::Tool.find_module_root(nil)) }.should raise_error(ArgumentError)
      end
    end

    it "should return a Pathname object representing the path to the release archive." do
      run do
        Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        Puppet::Module::Tool::Applications::Builder.run(@full_module_name).should be_kind_of(Pathname)
      end
    end
  end

  describe "search" do
    it "should display matching modules" do
      run do
        stub_repository_read 200, <<-HERE
          [
            {"full_module_name": "cli", "version": "1.0"},
            {"full_module_name": "web", "version": "2.0"}
          ]
        HERE
        Puppet::Module::Tool::Applications::Searcher.run("mymodule", @options).size.should == 2
      end
    end

    it "should display no matches" do
      run do
        stub_repository_read 200, "[]"
        Puppet::Module::Tool::Applications::Searcher.run("mymodule", @options).should == []
      end
    end

    it "should fail if can't get a connection" do
      run do
        stub_repository_read 500, "OH NOES!!1!"
        lambda { Puppet::Module::Tool::Applications::Searcher.run("mymodule", @options) }.should raise_error(RuntimeError)
      end
    end

    it "should return an array of module metadata hashes" do
      run do
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
  end

  describe "install" do
    it "should install a module to the puppet modulepath by default" do
      myothertmpdir = Pathname.new(tmpdir("module_tool_test_myothertmpdir"))
      run do
        @options[:dir] = myothertmpdir
        Puppet::Module::Tool.unstub(:dir)

        build_and_install_module

        File.directory?(myothertmpdir + @module_name).should == true
        File.file?(myothertmpdir + @module_name + 'metadata.json').should == true
      end
    end

    it "should install a module from a filesystem path" do
      run do
        build_and_install_module

        File.directory?(@mytmpdir + @module_name).should == true
        File.file?(@mytmpdir + @module_name + 'metadata.json').should == true
      end
    end

    it "should install a module from a webserver URL" do
      run do
        Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

        stub_cache_read File.read("#{@full_module_name}/pkg/#{@release_name}.tar.gz")
        FileUtils.rm_rf(@full_module_name)

        releases = {
           'myuser/mymodule' => [
            {
              'file' => "/foo/bar/#{@release_name}.tar.gz",
              'version' => @version,
              'dependencies' => []
            }]
        }
        Puppet::Forge::Forge.stubs(:remote_dependency_info).returns(releases)

        Puppet::Module::Tool::Applications::Installer.run(@full_module_name, @options)

        File.directory?(@mytmpdir + @module_name).should == true
        File.file?(@mytmpdir + @module_name + 'metadata.json').should == true
      end
    end

    it "should install a module from a webserver URL using a version requirement" # TODO

    it "should fail if module isn't a slashed name" do
      run do
        lambda { Puppet::Module::Tool::Applications::Installer.run("invalid") }.should raise_error(RuntimeError)
      end
    end

    it "should fail if module doesn't exist on webserver" do
      run do
        stub_installer_read "{}"
        lambda { Puppet::Module::Tool::Applications::Installer.run("not-found", @options) }.should raise_error(RuntimeError)
      end
    end

    it "should fail gracefully when receiving invalid PSON" do
      pending "Implement PSON error wrapper" # TODO
      run do
        stub_installer_read "1/0"
        lambda { Puppet::Module::Tool::Applications::Installer.run("not-found") }.should raise_error(SystemExit)
      end
    end

    it "should fail if installing a module that's already installed" do
      run do
        name = "myuser-mymodule"
        Dir.mkdir name
        lambda { Puppet::Module::Tool::Applications::Installer.run(name) }.should raise_error(ArgumentError)
      end
    end

    it "should return Pathname objects representing the paths to the installed modules" do
      run do
        Puppet::Module::Tool::Applications::Generator.run(@full_module_name)
        Puppet::Module::Tool::Applications::Builder.run(@full_module_name)

        stub_cache_read File.read("#{@full_module_name}/pkg/#{@release_name}.tar.gz")
        FileUtils.rm_rf(@full_module_name)

        releases = {
           'myuser/mymodule' => [
            {
              'file' => "/foo/bar/#{@release_name}.tar.gz",
              'version' => @version,
              'dependencies' => []
            }]
        }
        Puppet::Forge::Forge.stubs(:remote_dependency_info).returns(releases)

        Puppet::Module::Tool::Applications::Installer.run(@full_module_name, @options).first.should be_kind_of(Pathname)
      end
    end

  end

  describe "clean" do
    require 'puppet/module_tool'
    it "should clean cache" do
      run do
        build_and_install_module
        Puppet::Forge::Cache.base_path.directory?.should == true
        Puppet::Module::Tool::Applications::Cleaner.run
        Puppet::Forge::Cache.base_path.directory?.should == false
      end
    end

    it "should return a status Hash" do
      run do
        build_and_install_module
        return_value = Puppet::Module::Tool::Applications::Cleaner.run
        return_value.should include(:msg)
        return_value.should include(:status)
        return_value.should be_kind_of(Hash)
      end
    end
  end

  describe "changes" do
    it "should return an array of modified files" do
      run do
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
end
