require File.dirname(__FILE__) + "/../autotest_helper"

class Autotest
  
  module AutotestHelper
    def rspec_output
      <<-HERE
.............PPF

1)
'false should be false' FAILED
expected: true,
     got: false (using ==)
./spec/autotest/rspec_spec.rb:203:

Finished in 0.158674 seconds

16 examples, 1 failure, 2 pending

Pending:
Autotest::Rspec handling failed results should return an array of failed examples and errors (TODO)
Autotest::Rspec tests/specs for a given file should find all the specs for a given file (TODO)
HERE
    end
    
    
    def common_setup
      @proc = mock Proc
      @kernel = mock Kernel
      @kernel.stub!(:proc).and_return @proc

      File.stub!(:exists).and_return true
      @windows_alt_separator = "\\"
      @posix_separator = '/'

      @rspec_output = rspec_output
    end
  end

  describe Rspec, "rspec_commands" do
    it "should contain the various commands, ordered by preference" do
      Rspec.new.spec_commands.should == ["bin/spec", "#{Config::CONFIG['bindir']}/spec"]
    end
  end
  
  describe Rspec, "selection of rspec command" do
    include AutotestHelper
    
    before :each do
      common_setup
      @rspec_autotest = Rspec.new(@kernel)
    end
    
    it "should try to find the spec command if it exists in ./bin and use it above everything else" do
      File.stub!(:exists?).and_return true

      File.should_receive(:exists?).with("bin/spec").and_return true
      @rspec_autotest.spec_command.should == "bin/spec"
    end

    it "should otherwise select the default spec command in gem_dir/bin/spec" do
      @rspec_autotest.stub!(:spec_commands).and_return ["/foo/spec"]
      Config::CONFIG.stub!(:[]).and_return "/foo"
      File.should_receive(:exists?).with("/foo/spec").and_return(true)

      @rspec_autotest.spec_command.should == "/foo/spec"
    end
    
    it "should raise an error if no spec command is found at all" do
      File.stub!(:exists?).and_return false
      
      lambda {
        @rspec_autotest.spec_command
      }.should raise_error(RspecCommandError, "No spec command could be found!")
    end
    
  end
  
  describe Rspec, "selection of rspec command (windows compatibility issues)" do
    include AutotestHelper
    
    before :each do
      common_setup
    end
    
    it "should use the ALT_SEPARATOR if it is non-nil" do
      @rspec_autotest = Rspec.new(@kernel, @posix_separator, @windows_alt_separator)
      @rspec_autotest.stub!(:spec_commands).and_return [File.join('bin', 'spec')]
      @rspec_autotest.spec_command.should == "bin\\spec"
    end
    
    it "should not use the ALT_SEPATOR if it is nil" do
      @windows_alt_separator = nil
      @rspec_autotest = Rspec.new(@kernel, @posix_separator, @windows_alt_separator)
      @rspec_autotest.stub!(:spec_commands).and_return [File.join('bin', 'spec')]
      @rspec_autotest.spec_command.should == "bin/spec"
    end
  end

  describe Rspec, "adding spec.opts --options" do 
    before :each do
      @rspec_autotest = Rspec.new
    end

    it "should return the command line option to add spec.opts if the options file exists" do
      File.stub!(:exist?).and_return true
      @rspec_autotest.add_options_if_present.should == "-O spec/spec.opts "
    end

    it "should return an empty string if no spec.opts exists" do
      File.stub!(:exist?).and_return false
      Rspec.new.add_options_if_present.should == ""
    end
  end  
  
  describe Rspec do
    before :each do
      @rspec_autotest = Rspec.new
      @rspec_autotest.stub!(:ruby).and_return "ruby"
      @rspec_autotest.stub!(:add_options_if_present).and_return "-O spec/spec.opts"
      
      @ruby = @rspec_autotest.ruby
      @spec_command = @rspec_autotest.spec_command
      @options = @rspec_autotest.add_options_if_present
      @files_to_test = {
        :spec => ["file_one", "file_two"]
      }
      # this is not the inner representation of Autotest!
      @rspec_autotest.stub!(:files_to_test).and_return @files_to_test
      @files_to_test.stub!(:keys).and_return @files_to_test[:spec]
      @to_test = @files_to_test.keys.flatten.join ' '
    end
    
    it "should make the apropriate test command" do
      @rspec_autotest.make_test_cmd(@files_to_test).should == "#{@ruby} -S #{@spec_command} #{@options} #{@to_test}"
    end
  end
  
  describe Rspec, "test mappings" do
    before :each do
      @proc = mock Proc
      @kernel = mock Kernel
      @kernel.stub!(:proc).and_return @proc
      @rspec_autotest = Rspec.new(@kernel)
    end
      
    it "should map all filenames in spec/ which end in .rb" do
      @rspec_autotest.test_mappings[%r%^spec/.*\.rb$%].should == @proc
    end
    
    it "should map all names in lib which end in .rb to the corresponding ones in spec/" do
      @rspec_autotest.test_mappings[%r%^lib/(.*)\.rb$%].should == @proc
    end
    
    it "should find all files in spec/shares/* and the spec helper in spec/spec_helper"  do
      @rspec_autotest.test_mappings[%r%^spec/(spec_helper|shared/.*)\.rb$%].should == @proc
    end
  end
  
  describe Rspec, "handling results" do
    include AutotestHelper
    
    before :each do
      common_setup
      @rspec_autotest = Rspec.new(@kernel, @posix_separator, @windows_alt_separator)
      @rspec_autotest.stub!(:hook)
      
      @results = mock String
      @results.stub!(:scan).and_return ""
    end
    
    it "should call hook(:red) if there are failures" do
      @rspec_autotest.stub!(:consolidate_failures).and_return ["spec/some_spec.rb"]
      
      @rspec_autotest.should_receive(:hook).with(:red)
      @rspec_autotest.handle_results(@results)
    end
    
    it "should call hook(:green) if there are no failures" do
      @rspec_autotest.stub!(:consolidate_failures).and_return []
      @rspec_autotest.should_receive(:hook).with(:green)
      @rspec_autotest.handle_results(@results)
    end
  end
  
  describe Rspec, "handling failed results" do
    include AutotestHelper
    
    before :each do
      common_setup
    end
    
    it %(should scan the output into a multi-dimensional array, 
        consisting of the failing spec's name as the first element, 
        and the failure as the second) do
      @rspec_autotest = Rspec.new
      @rspec_autotest.failed_results(@rspec_output).should == [
        [
          "false should be false", 
          "expected: true,\n     got: false (using ==)\n./spec/autotest/rspec_spec.rb:203:"
        ]
      ]
    end
  end
  
  describe Rspec, "specs for a given file" do
    before :each do
      @lib_file = "lib/something.rb"
      @spec_file = "spec/something_spec.rb"
      @rspec_autotest = Rspec.new

      @rspec_autotest.instance_variable_set("@files", {@lib_file => Time.now, @spec_file => Time.now})
      @rspec_autotest.stub!(:find_files_to_test).and_return true
    end
    
    it "should find the spec file for a given lib file" do
      @rspec_autotest.specs_for_file(@lib_file).should == [@spec_file]
    end
    
    it "should find the spec file if given a spec file" do
      @rspec_autotest.specs_for_file(@spec_file).should == [@spec_file]
    end
    
    it "should only find the file if the file is being tracked (in @file)"  do
      @other_file = "lib/some_non_tracked_file"
      @rspec_autotest.specs_for_file(@other_file).should == []
    end
  end
  
  describe Rspec, "consolidating failures" do
    include AutotestHelper
    
    before :each do
      common_setup
      @rspec_autotest = Rspec.new
      
      @spec_file = "./spec/autotest/rspec_spec.rb"
      @rspec_autotest.instance_variable_set("@files", {@spec_file => Time.now})
      @rspec_autotest.stub!(:find_files_to_test).and_return true
    end
    
    it "should return no failures if no failures were given in the output" do
      @rspec_autotest.stub!(:failed_results).and_return [[]]
      @rspec_autotest.consolidate_failures(@rspec_autotest.failed_results).should == {}
    end
    
    it "should return a hash with the spec filename => spec name for each failure or error" do
      @rspec_autotest.stub!(:failed_results).and_return([
        [
          "false should be false", 
          "expected: true,\n     got: false (using ==)\n./spec/autotest/rspec_spec.rb:203:"
        ]
      ])
      @rspec_autotest.consolidate_failures(@rspec_autotest.failed_results).should == {@spec_file => ["false should be false"]}
    end
    
  end
end
