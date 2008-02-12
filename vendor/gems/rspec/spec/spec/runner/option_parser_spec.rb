require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "OptionParser" do
  before(:each) do
    @out = StringIO.new
    @err = StringIO.new
    @parser = Spec::Runner::OptionParser.new
  end

  def parse(args)
    @parser.parse(args, @err, @out, true)
  end

  def behaviour_runner(args)
    @parser.create_behaviour_runner(args, @err, @out, true)
  end

  it "should accept dry run option" do
    options = parse(["--dry-run"])
    options.dry_run.should be_true
  end

  it "should eval and use custom formatter when none of the builtins" do
    options = parse(["--format", "Custom::Formatter"])
    options.formatters[0].class.should be(Custom::Formatter)
  end
  
  it "should support formatters with relative and absolute paths, even on windows" do
    options = parse([
      "--format", "Custom::Formatter:C:\\foo\\bar",
      "--format", "Custom::Formatter:foo/bar",
      "--format", "Custom::Formatter:foo\\bar",
      "--format", "Custom::Formatter:/foo/bar"
    ])
    options.formatters[0].where.should eql("C:\\foo\\bar")
    options.formatters[1].where.should eql("foo/bar")
    options.formatters[2].where.should eql("foo\\bar")
    options.formatters[3].where.should eql("/foo/bar")
  end

  it "should not be verbose by default" do
    options = parse([])
    options.verbose.should be_nil
  end

  it "should not use colour by default" do
    options = parse([])
    options.colour.should == false
  end

  it "should print help to stdout" do
    options = parse(["--help"])
    @out.rewind
    @out.read.should match(/Usage: spec \(FILE\|DIRECTORY\|GLOB\)\+ \[options\]/m)
  end

  it "should print instructions about how to require missing formatter" do
    lambda { options = parse(["--format", "Custom::MissingFormatter"]) }.should raise_error(NameError)
    @err.string.should match(/Couldn't find formatter class Custom::MissingFormatter/n)
  end

  it "should print usage to err if no dir specified" do
    options = parse([])
    @err.string.should match(/Usage: spec/)
  end

  it "should print version to stdout" do
    options = parse(["--version"])
    @out.rewind
    @out.read.should match(/RSpec-\d+\.\d+\.\d+.*\(r\d+\) - BDD for Ruby\nhttp:\/\/rspec.rubyforge.org\/\n/n)
  end
  
  it "should require file when require specified" do
    lambda do
      parse(["--require", "whatever"])
    end.should raise_error(LoadError)
  end

  it "should support c option" do
    options = parse(["-c"])
    options.colour.should be_true
  end

  it "should support queens colour option" do
    options = parse(["--colour"])
    options.colour.should be_true
  end

  it "should support us color option" do
    options = parse(["--color"])
    options.colour.should be_true
  end

  it "should support single example with -e option" do
    options = parse(["-e", "something or other"])
    options.examples.should eql(["something or other"])
  end

  it "should support single example with -s option (will be removed when autotest supports -e)" do
    options = parse(["-s", "something or other"])
    options.examples.should eql(["something or other"])
  end

  it "should support single example with --example option" do
    options = parse(["--example", "something or other"])
    options.examples.should eql(["something or other"])
  end

  it "should read several example names from file if --example is given an existing file name" do
    options = parse(["--example", File.dirname(__FILE__) + '/examples.txt'])
    options.examples.should eql([
      "Sir, if you were my husband, I would poison your drink.", 
      "Madam, if you were my wife, I would drink it."])
  end
  
  it "should read no examples if given an empty file" do
    options = parse(["--example", File.dirname(__FILE__) + '/empty_file.txt'])
    options.examples.should eql([])
  end

  it "should use html formatter when format is h" do
    options = parse(["--format", "h"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::HtmlFormatter)
  end

  it "should use html formatter when format is html" do
    options = parse(["--format", "html"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::HtmlFormatter)
  end

  it "should use html formatter with explicit output when format is html:test.html" do
    FileUtils.rm 'test.html' if File.exist?('test.html')
    options = parse(["--format", "html:test.html"])
    File.should be_exist('test.html')
    options.formatters[0].class.should equal(Spec::Runner::Formatter::HtmlFormatter)
    options.formatters[0].close
    FileUtils.rm 'test.html'
  end

  it "should use noisy backtrace tweaker with b option" do
    options = parse(["-b"])
    options.backtrace_tweaker.should be_instance_of(Spec::Runner::NoisyBacktraceTweaker)
  end

  it "should use noisy backtrace tweaker with backtrace option" do
    options = parse(["--backtrace"])
    options.backtrace_tweaker.should be_instance_of(Spec::Runner::NoisyBacktraceTweaker)
  end

  it "should use quiet backtrace tweaker by default" do
    options = parse([])
    options.backtrace_tweaker.should be_instance_of(Spec::Runner::QuietBacktraceTweaker)
  end

  it "should use progress bar formatter by default" do
    options = parse([])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::ProgressBarFormatter)
  end

  it "should use rdoc formatter when format is r" do
    options = parse(["--format", "r"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::RdocFormatter)
  end

  it "should use rdoc formatter when format is rdoc" do
    options = parse(["--format", "rdoc"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::RdocFormatter)
  end

  it "should use specdoc formatter when format is s" do
    options = parse(["--format", "s"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::SpecdocFormatter)
  end

  it "should use specdoc formatter when format is specdoc" do
    options = parse(["--format", "specdoc"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::SpecdocFormatter)
  end

  it "should support diff option when format is not specified" do
    options = parse(["--diff"])
    options.diff_format.should == :unified
  end

  it "should use unified diff format option when format is unified" do
    options = parse(["--diff", "unified"])
    options.diff_format.should == :unified
    options.differ_class.should equal(Spec::Expectations::Differs::Default)
  end

  it "should use context diff format option when format is context" do
    options = parse(["--diff", "context"])
    options.diff_format.should == :context
    options.differ_class.should == Spec::Expectations::Differs::Default
  end

  it "should use custom diff format option when format is a custom format" do
    options = parse(["--diff", "Custom::Formatter"])
    options.diff_format.should == :custom
    options.differ_class.should == Custom::Formatter
  end

  it "should print instructions about how to fix missing differ" do
    lambda { parse(["--diff", "Custom::MissingFormatter"]) }.should raise_error(NameError)
    @err.string.should match(/Couldn't find differ class Custom::MissingFormatter/n)
  end

  it "should support --line to identify spec" do
    spec_parser = mock("spec_parser")
    @parser.instance_variable_set('@spec_parser', spec_parser)

    file_factory = mock("File")
    file_factory.should_receive(:file?).and_return(true)
    file_factory.should_receive(:open).and_return("fake_io")
    @parser.instance_variable_set('@file_factory', file_factory)

    spec_parser.should_receive(:spec_name_for).with("fake_io", 169).and_return("some spec")

    options = parse(["some file", "--line", "169"])
    options.examples.should eql(["some spec"])
    File.rspec_verify
  end

  it "should fail with error message if file is dir along with --line" do
    spec_parser = mock("spec_parser")
    @parser.instance_variable_set('@spec_parser', spec_parser)

    file_factory = mock("File")
    file_factory.should_receive(:file?).and_return(false)
    file_factory.should_receive(:directory?).and_return(true)
    @parser.instance_variable_set('@file_factory', file_factory)

    options = parse(["some file", "--line", "169"])
    @err.string.should match(/You must specify one file, not a directory when using the --line option/n)
  end

  it "should fail with error message if file is dir along with --line" do
    spec_parser = mock("spec_parser")
    @parser.instance_variable_set('@spec_parser', spec_parser)

    file_factory = mock("File")
    file_factory.should_receive(:file?).and_return(false)
    file_factory.should_receive(:directory?).and_return(false)
    @parser.instance_variable_set('@file_factory', file_factory)

    options = parse(["some file", "--line", "169"])
    @err.string.should match(/some file does not exist/n)
  end

  it "should fail with error message if more than one files are specified along with --line" do
    spec_parser = mock("spec_parser")
    @parser.instance_variable_set('@spec_parser', spec_parser)

    options = parse(["some file", "some other file", "--line", "169"])
    @err.string.should match(/Only one file can be specified when using the --line option/n)
  end

  it "should fail with error message if --example and --line are used simultaneously" do
    spec_parser = mock("spec_parser")
    @parser.instance_variable_set('@spec_parser', spec_parser)

    options = parse(["some file", "--example", "some example", "--line", "169"])
    @err.string.should match(/You cannot use both --line and --example/n)
  end

  if [/mswin/, /java/].detect{|p| p =~ RUBY_PLATFORM}
    it "should barf when --heckle is specified (and platform is windows)" do
      lambda do
        options = parse(["--heckle", "Spec"])
      end.should raise_error(StandardError, "Heckle not supported on Windows")
    end
  else
    it "should heckle when --heckle is specified (and platform is not windows)" do
      options = parse(["--heckle", "Spec"])
      options.heckle_runner.should be_instance_of(Spec::Runner::HeckleRunner)
    end
  end

  it "should read options from file when --options is specified" do
    Spec::Runner::CommandLine.should_receive(:run).with(["--diff", "--colour"], @err, @out, true, true)
    options = parse(["--options", File.dirname(__FILE__) + "/spec.opts"])
  end

  it "should append options from file when --options is specified" do
    Spec::Runner::CommandLine.should_receive(:run).with(["some/spec.rb", "--diff", "--colour"], @err, @out, true, true)
    options = parse(["some/spec.rb", "--options", File.dirname(__FILE__) + "/spec.opts"])
  end
  
  it "should read spaced and multi-line options from file when --options is specified" do
    Spec::Runner::CommandLine.should_receive(:run).with(["--diff", "--colour", "--format", "s"], @err, @out, true, true)
    options = parse(["--options", File.dirname(__FILE__) + "/spec_spaced.opts"])
  end
   
  it "should save config to file when --generate-options is specified" do
    FileUtils.rm 'test.spec.opts' if File.exist?('test.spec.opts')
    options = parse(["--colour", "--generate-options", "test.spec.opts", "--diff"])
    IO.read('test.spec.opts').should == "--colour\n--diff\n"
    FileUtils.rm 'test.spec.opts'
  end

  it "should call DrbCommandLine when --drb is specified" do
    Spec::Runner::DrbCommandLine.should_receive(:run).with(["some/spec.rb", "--diff", "--colour"], @err, @out, true, true)
    options = parse(["some/spec.rb", "--diff", "--drb", "--colour"])
  end
  
  it "should not return an Options object when --drb is specified" do
    Spec::Runner::DrbCommandLine.stub!(:run)
    parse(["some/spec.rb", "--drb"]).should be_nil
  end

  it "should reverse spec order when --reverse is specified" do
    options = parse(["some/spec.rb", "--reverse"])
  end

  it "should set an mtime comparator when --loadby mtime" do
    behaviour_runner = behaviour_runner(["--loadby", 'mtime'])
    Dir.chdir(File.dirname(__FILE__)) do
      FileUtils.touch "most_recent_spec.rb"
      all_files = ['command_line_spec.rb', 'most_recent_spec.rb']
      sorted_files = behaviour_runner.sort_paths(all_files)
      sorted_files.should == ["most_recent_spec.rb", "command_line_spec.rb"]
      FileUtils.rm "most_recent_spec.rb"
    end
  end

  it "should use the standard runner by default" do
    options = parse([])
    options.create_behaviour_runner.class.should equal(Spec::Runner::BehaviourRunner)
  end

  it "should use a custom runner when given" do
    options = parse(["--runner", "Custom::BehaviourRunner"])
    options.create_behaviour_runner.class.should equal(Custom::BehaviourRunner)
  end

  it "should use a custom runner with extra options" do
    options = parse(["--runner", "Custom::BehaviourRunner:something"])
    options.create_behaviour_runner.class.should equal(Custom::BehaviourRunner)
  end

  it "should return the correct default behaviour runner" do
    @parser.create_behaviour_runner([], @err, @out, true).should be_instance_of(Spec::Runner::BehaviourRunner)
  end

  it "should return the correct default behaviour runner" do
    @parser.create_behaviour_runner(["--runner", "Custom::BehaviourRunner"], @err, @out, true).should be_instance_of(Custom::BehaviourRunner)
  end

end
