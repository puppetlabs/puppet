#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:exec) do
  include PuppetSpec::Files

  def exec_tester(command, exitstatus = 0, rest = {})
    Puppet.features.stubs(:root?).returns(true)

    output = rest.delete(:output) || ''

    output = Puppet::Util::Execution::ProcessOutput.new(output, exitstatus)
    tries  = rest[:tries] || 1

    args = {
      :name      => command,
      :path      => @example_path,
      :logoutput => false,
      :loglevel  => :err,
      :returns   => 0
    }.merge(rest)

    exec = Puppet::Type.type(:exec).new(args)

    status = stub "process", :exitstatus => exitstatus
    Puppet::Util::Execution.expects(:execute).times(tries).
      with() { |*args|
        args[0] == command &&
        args[1][:override_locale] == false &&
        args[1].has_key?(:custom_environment)
      }.returns(output)

    return exec
  end

  before do
    @command = make_absolute('/bin/true whatever')
    @executable = make_absolute('/bin/true')
    @bogus_cmd = make_absolute('/bogus/cmd')
  end

  describe "when not stubbing the provider" do
    before do
      path = tmpdir('path')
      ext = Puppet.features.microsoft_windows? ? '.exe' : ''
      true_cmd = File.join(path, "true#{ext}")
      false_cmd = File.join(path, "false#{ext}")

      FileUtils.touch(true_cmd)
      FileUtils.touch(false_cmd)

      File.chmod(0755, true_cmd)
      File.chmod(0755, false_cmd)

      @example_path = [path]
    end

    it "should return :executed_command as its event" do
      resource = Puppet::Type.type(:exec).new :command => @command
      expect(resource.parameter(:returns).event.name).to eq(:executed_command)
    end

    describe "when execing" do
      it "should use the 'execute' method to exec" do
        expect(exec_tester("true").refresh).to eq(:executed_command)
      end

      it "should report a failure" do
        expect { exec_tester('false', 1).refresh }.
          to raise_error(Puppet::Error, /^false returned 1 instead of/)
      end

      it "should not report a failure if the exit status is specified in a returns array" do
        expect { exec_tester("false", 1, :returns => [0, 1]).refresh }.to_not raise_error
      end

      it "should report a failure if the exit status is not specified in a returns array" do
        expect { exec_tester('false', 1, :returns => [0, 100]).refresh }.
          to raise_error(Puppet::Error, /^false returned 1 instead of/)
      end

      it "should log the output on success" do
        output = "output1\noutput2\n"
        exec_tester('false', 0, :output => output, :logoutput => true).refresh
        output.split("\n").each do |line|
          log = @logs.shift
          expect(log.level).to eq(:err)
          expect(log.message).to eq(line)
        end
      end

      it "should log the output on failure" do
        output = "output1\noutput2\n"
        expect { exec_tester('false', 1, :output => output, :logoutput => true).refresh }.
          to raise_error(Puppet::Error)

        output.split("\n").each do |line|
          log = @logs.shift
          expect(log.level).to eq(:err)
          expect(log.message).to eq(line)
        end
      end
    end

    describe "when logoutput=>on_failure is set" do
      it "should log the output on failure" do
        output = "output1\noutput2\n"
        expect { exec_tester('false', 1, :output => output, :logoutput => :on_failure).refresh }.
          to raise_error(Puppet::Error, /^false returned 1 instead of/)

        output.split("\n").each do |line|
          log = @logs.shift
          expect(log.level).to eq(:err)
          expect(log.message).to eq(line)
        end
      end

      it "should log the output on failure when returns is specified as an array" do
        output = "output1\noutput2\n"

        expect {
          exec_tester('false', 1, :output => output, :returns => [0, 100],
               :logoutput => :on_failure).refresh
        }.to raise_error(Puppet::Error, /^false returned 1 instead of/)

        output.split("\n").each do |line|
          log = @logs.shift
          expect(log.level).to eq(:err)
          expect(log.message).to eq(line)
        end
      end

      it "shouldn't log the output on success" do
        exec_tester('true', 0, :output => "a\nb\nc\n", :logoutput => :on_failure).refresh
        expect(@logs).to eq([])
      end
    end

    it "shouldn't log the output on success when non-zero exit status is in a returns array" do
      exec_tester("true", 100, :output => "a\n", :logoutput => :on_failure, :returns => [1, 100]).refresh
      expect(@logs).to eq([])
    end

    describe " when multiple tries are set," do
      it "should repeat the command attempt 'tries' times on failure and produce an error" do
        tries = 5
        resource = exec_tester("false", 1, :tries => tries, :try_sleep => 0)
        expect { resource.refresh }.to raise_error(Puppet::Error)
      end
    end
  end

  it "should be able to autorequire files mentioned in the command" do
    foo = make_absolute('/bin/foo')
    catalog = Puppet::Resource::Catalog.new
    tmp = Puppet::Type.type(:file).new(:name => foo)
    execer = Puppet::Type.type(:exec).new(:name => foo)

    catalog.add_resource tmp
    catalog.add_resource execer
    dependencies = execer.autorequire(catalog)

    expect(dependencies.collect(&:to_s)).to eq([Puppet::Relationship.new(tmp, execer).to_s])
  end

  describe "when handling the path parameter" do
    expect = %w{one two three four}
    { "an array"                                      => expect,
      "a path-separator delimited list"               => expect.join(File::PATH_SEPARATOR),
      "both array and path-separator delimited lists" => ["one", "two#{File::PATH_SEPARATOR}three", "four"],
    }.each do |test, input|
      it "should accept #{test}" do
        type = Puppet::Type.type(:exec).new(:name => @command, :path => input)
        expect(type[:path]).to eq(expect)
      end
    end

    describe "on platforms where path separator is not :" do
      before :each do
        @old_verbosity = $VERBOSE
        $VERBOSE = nil
        @old_separator = File::PATH_SEPARATOR
        File::PATH_SEPARATOR = 'q'
      end

      after :each do
        File::PATH_SEPARATOR = @old_separator
        $VERBOSE = @old_verbosity
      end

      it "should use the path separator of the current platform" do
        type = Puppet::Type.type(:exec).new(:name => @command, :path => "fooqbarqbaz")
        expect(type[:path]).to eq(%w[foo bar baz])
      end
    end
  end

  describe "when setting user" do
    describe "on POSIX systems", :if => Puppet.features.posix? do
      it "should fail if we are not root" do
        Puppet.features.stubs(:root?).returns(false)
        expect {
          Puppet::Type.type(:exec).new(:name => '/bin/true whatever', :user => 'input')
        }.to raise_error Puppet::Error, /Parameter user failed/
      end

      it "accepts the current user" do
        Puppet.features.stubs(:root?).returns(false)
        Etc.stubs(:getpwuid).returns(Struct::Passwd.new('input'))

        type = Puppet::Type.type(:exec).new(:name => '/bin/true whatever', :user => 'input')

        expect(type[:user]).to eq('input')
      end

      ['one', 2, 'root', 4294967295, 4294967296].each do |value|
        it "should accept '#{value}' as user if we are root" do
          Puppet.features.stubs(:root?).returns(true)
          type = Puppet::Type.type(:exec).new(:name => '/bin/true whatever', :user => value)
          expect(type[:user]).to eq(value)
        end
      end
    end

    describe "on Windows systems", :if => Puppet.features.microsoft_windows? do
      before :each do
        Puppet.features.stubs(:root?).returns(true)
      end

      it "should reject user parameter" do
        expect {
          Puppet::Type.type(:exec).new(:name => 'c:\windows\notepad.exe', :user => 'input')
        }.to raise_error Puppet::Error, /Unable to execute commands as other users on Windows/
      end
    end
  end

  describe "when setting group" do
    shared_examples_for "exec[:group]" do
      ['one', 2, 'wheel', 4294967295, 4294967296].each do |value|
        it "should accept '#{value}' without error or judgement" do
          type = Puppet::Type.type(:exec).new(:name => @command, :group => value)
          expect(type[:group]).to eq(value)
        end
      end
    end

    describe "when running as root" do
      before :each do Puppet.features.stubs(:root?).returns(true) end
      it_behaves_like "exec[:group]"
    end

    describe "when not running as root" do
      before :each do Puppet.features.stubs(:root?).returns(false) end
      it_behaves_like "exec[:group]"
    end
  end

  describe "when setting cwd" do
    it_should_behave_like "all path parameters", :cwd, :array => false do
      def instance(path)
        # Specify shell provider so we don't have to care about command validation
        Puppet::Type.type(:exec).new(:name => @executable, :cwd => path, :provider => :shell)
      end
    end
  end

  shared_examples_for "all exec command parameters" do |param|
    { "relative" => "example", "absolute" => "/bin/example" }.sort.each do |name, command|
      describe "if command is #{name}" do
        before :each do
          @param = param
        end

        def test(command, valid)
          if @param == :name then
            instance = Puppet::Type.type(:exec).new()
          else
            instance = Puppet::Type.type(:exec).new(:name => @executable)
          end
          if valid then
            instance.provider.expects(:validatecmd).returns(true)
          else
            instance.provider.expects(:validatecmd).raises(Puppet::Error, "from a stub")
          end
          instance[@param] = command
        end

        it "should work if the provider calls the command valid" do
          expect { test(command, true) }.to_not raise_error
        end

        it "should fail if the provider calls the command invalid" do
          expect { test(command, false) }.
            to raise_error Puppet::Error, /Parameter #{@param} failed on Exec\[.*\]: from a stub/
        end
      end
    end
  end

  shared_examples_for "all exec command parameters that take arrays" do |param|
    describe "when given an array of inputs" do
      before :each do
        @test = Puppet::Type.type(:exec).new(:name => @executable)
      end

      it "should accept the array when all commands return valid" do
        input = %w{one two three}
        @test.provider.expects(:validatecmd).times(input.length).returns(true)
        @test[param] = input
        expect(@test[param]).to eq(input)
      end

      it "should reject the array when any commands return invalid" do
        input = %w{one two three}
        @test.provider.expects(:validatecmd).with(input.first).returns(false)
        input[1..-1].each do |cmd|
          @test.provider.expects(:validatecmd).with(cmd).returns(true)
        end
        @test[param] = input
        expect(@test[param]).to eq(input)
      end

      it "should reject the array when all commands return invalid" do
        input = %w{one two three}
        @test.provider.expects(:validatecmd).times(input.length).returns(false)
        @test[param] = input
        expect(@test[param]).to eq(input)
      end
    end
  end

  describe "when setting command" do
    subject { described_class.new(:name => @command) }
    it "fails when passed an Array" do
      expect { subject[:command] = [] }.to raise_error Puppet::Error, /Command must be a String/
    end

    it "fails when passed a Hash" do
      expect { subject[:command] = {} }.to raise_error Puppet::Error, /Command must be a String/
    end
  end

  describe "when setting refresh" do
    it_should_behave_like "all exec command parameters", :refresh
  end

  describe "for simple parameters" do
    before :each do
      @exec = Puppet::Type.type(:exec).new(:name => @executable)
    end

    describe "when setting environment" do
      { "single values"   => "foo=bar",
        "multiple values" => ["foo=bar", "baz=quux"],
      }.each do |name, data|
        it "should accept #{name}" do
          @exec[:environment] = data
          expect(@exec[:environment]).to eq(data)
        end
      end

      { "single values" => "foo",
        "only values"   => ["foo", "bar"],
        "any values"    => ["foo=bar", "baz"]
      }.each do |name, data|
        it "should reject #{name} without assignment" do
          expect { @exec[:environment] = data }.
            to raise_error Puppet::Error, /Invalid environment setting/
        end
      end
    end

    describe "when setting timeout" do
      [0, 0.1, 1, 10, 4294967295].each do |valid|
        it "should accept '#{valid}' as valid" do
          @exec[:timeout] = valid
          expect(@exec[:timeout]).to eq(valid)
        end

        it "should accept '#{valid}' in an array as valid" do
          @exec[:timeout] = [valid]
          expect(@exec[:timeout]).to eq(valid)
        end
      end

      ['1/2', '', 'foo', '5foo'].each do |invalid|
        it "should reject '#{invalid}' as invalid" do
          expect { @exec[:timeout] = invalid }.
            to raise_error Puppet::Error, /The timeout must be a number/
        end

        it "should reject '#{invalid}' in an array as invalid" do
          expect { @exec[:timeout] = [invalid] }.
            to raise_error Puppet::Error, /The timeout must be a number/
        end
      end

      describe 'when timeout is exceeded' do
        subject do
          ruby_path = Puppet::Util::Execution.ruby_path()
          Puppet::Type.type(:exec).new(:name => "#{ruby_path} -e 'sleep 1'", :timeout => '0.1')
        end

        context 'on POSIX', :unless => Puppet.features.microsoft_windows? do
          it 'sends a SIGTERM and raises a Puppet::Error' do
            Process.expects(:kill).at_least_once
            expect { subject.refresh }.to raise_error Puppet::Error, "Command exceeded timeout"
          end
        end

        context 'on Windows', :if => Puppet.features.microsoft_windows? do
          it 'raises a Puppet::Error' do
            expect { subject.refresh }.to raise_error Puppet::Error, "Command exceeded timeout"
          end
        end
      end

      it "should convert timeout to a float" do
        command = make_absolute('/bin/false')
        resource = Puppet::Type.type(:exec).new :command => command, :timeout => "12"
        expect(resource[:timeout]).to be_a(Float)
        expect(resource[:timeout]).to eq(12.0)
      end

      it "should munge negative timeouts to 0.0" do
        command = make_absolute('/bin/false')
        resource = Puppet::Type.type(:exec).new :command => command, :timeout => "-12.0"
        expect(resource.parameter(:timeout).value).to be_a(Float)
        expect(resource.parameter(:timeout).value).to eq(0.0)
      end
    end

    describe "when setting tries" do
      [1, 10, 4294967295].each do |valid|
        it "should accept '#{valid}' as valid" do
          @exec[:tries] = valid
          expect(@exec[:tries]).to eq(valid)
        end

        if "REVISIT: too much test log spam" == "a good thing" then
          it "should accept '#{valid}' in an array as valid" do
            pending "inconsistent, but this is not supporting arrays, unlike timeout"
            @exec[:tries] = [valid]
            expect(@exec[:tries]).to eq(valid)
          end
        end
      end

      [-3.5, -1, 0, 0.2, '1/2', '1_000_000', '+12', '', 'foo'].each do |invalid|
        it "should reject '#{invalid}' as invalid" do
          expect { @exec[:tries] = invalid }.
            to raise_error Puppet::Error, /Tries must be an integer/
        end

        if "REVISIT: too much test log spam" == "a good thing" then
          it "should reject '#{invalid}' in an array as invalid" do
            pending "inconsistent, but this is not supporting arrays, unlike timeout"
            expect { @exec[:tries] = [invalid] }.
              to raise_error Puppet::Error, /Tries must be an integer/
          end
        end
      end
    end

    describe "when setting try_sleep" do
      [0, 0.2, 1, 10, 4294967295].each do |valid|
        it "should accept '#{valid}' as valid" do
          @exec[:try_sleep] = valid
          expect(@exec[:try_sleep]).to eq(valid)
        end

        if "REVISIT: too much test log spam" == "a good thing" then
          it "should accept '#{valid}' in an array as valid" do
            pending "inconsistent, but this is not supporting arrays, unlike timeout"
            @exec[:try_sleep] = [valid]
            expect(@exec[:try_sleep]).to eq(valid)
          end
        end
      end

      { -3.5        => "cannot be a negative number",
        -1          => "cannot be a negative number",
        '1/2'       => 'must be a number',
        '1_000_000' => 'must be a number',
        '+12'       => 'must be a number',
        ''          => 'must be a number',
        'foo'       => 'must be a number',
      }.each do |invalid, error|
        it "should reject '#{invalid}' as invalid" do
          expect { @exec[:try_sleep] = invalid }.
            to raise_error Puppet::Error, /try_sleep #{error}/
        end

        if "REVISIT: too much test log spam" == "a good thing" then
          it "should reject '#{invalid}' in an array as invalid" do
            pending "inconsistent, but this is not supporting arrays, unlike timeout"
            expect { @exec[:try_sleep] = [invalid] }.
              to raise_error Puppet::Error, /try_sleep #{error}/
          end
        end
      end
    end

    describe "when setting refreshonly" do
      [:true, :false].each do |value|
        it "should accept '#{value}'" do
          @exec[:refreshonly] = value
          expect(@exec[:refreshonly]).to eq(value)
        end
      end

      [1, 0, "1", "0", "yes", "y", "no", "n"].each do |value|
        it "should reject '#{value}'" do
          expect { @exec[:refreshonly] = value }.
            to raise_error(Puppet::Error,
              /Invalid value #{value.inspect}\. Valid values are true, false/
            )
        end
      end
    end
  end

  describe "when setting creates" do
    it_should_behave_like "all path parameters", :creates, :array => true do
      def instance(path)
        # Specify shell provider so we don't have to care about command validation
        Puppet::Type.type(:exec).new(:name => @executable, :creates => path, :provider => :shell)
      end
    end
  end

  describe "when setting unless" do
    it_should_behave_like "all exec command parameters", :unless
    it_should_behave_like "all exec command parameters that take arrays", :unless
  end

  describe "when setting onlyif" do
    it_should_behave_like "all exec command parameters", :onlyif
    it_should_behave_like "all exec command parameters that take arrays", :onlyif
  end

  describe "#check" do
    before :each do
      @test = Puppet::Type.type(:exec).new(:name => @executable)
    end

    describe ":refreshonly" do
      { :true => false, :false => true }.each do |input, result|
        it "should return '#{result}' when given '#{input}'" do
          @test[:refreshonly] = input
          expect(@test.check_all_attributes).to eq(result)
        end
      end
    end

    describe ":creates" do
      before :each do
        @exist   = tmpfile('exist')
        FileUtils.touch(@exist)
        @unexist = tmpfile('unexist')
      end

      context "with a single item" do
        it "should run when the item does not exist" do
          @test[:creates] = @unexist
          expect(@test.check_all_attributes).to eq(true)
        end

        it "should not run when the item exists" do
          @test[:creates] = @exist
          expect(@test.check_all_attributes).to eq(false)
        end
      end

      context "with an array with one item" do
        it "should run when the item does not exist" do
          @test[:creates] = [@unexist]
          expect(@test.check_all_attributes).to eq(true)
        end

        it "should not run when the item exists" do
          @test[:creates] = [@exist]
          expect(@test.check_all_attributes).to eq(false)
        end
      end

      context "with an array with multiple items" do
        it "should run when all items do not exist" do
          @test[:creates] = [@unexist] * 3
          expect(@test.check_all_attributes).to eq(true)
        end

        it "should not run when one item exists" do
          @test[:creates] = [@unexist, @exist, @unexist]
          expect(@test.check_all_attributes).to eq(false)
        end

        it "should not run when all items exist" do
          @test[:creates] = [@exist] * 3
        end
      end
    end

    { :onlyif => { :pass => false, :fail => true  },
      :unless => { :pass => true,  :fail => false },
    }.each do |param, sense|
      describe ":#{param}" do
        before :each do
          @pass = make_absolute("/magic/pass")
          @fail = make_absolute("/magic/fail")

          @pass_status = stub('status', :exitstatus => sense[:pass] ? 0 : 1)
          @fail_status = stub('status', :exitstatus => sense[:fail] ? 0 : 1)

          @test.provider.stubs(:checkexe).returns(true)
          [true, false].each do |check|
            @test.provider.stubs(:run).with(@pass, check).
              returns(['test output', @pass_status])
            @test.provider.stubs(:run).with(@fail, check).
              returns(['test output', @fail_status])
          end
        end

        context "with a single item" do
          it "should run if the command exits non-zero" do
            @test[param] = @fail
            expect(@test.check_all_attributes).to eq(true)
          end

          it "should not run if the command exits zero" do
            @test[param] = @pass
            expect(@test.check_all_attributes).to eq(false)
          end
        end

        context "with an array with a single item" do
          it "should run if the command exits non-zero" do
            @test[param] = [@fail]
            expect(@test.check_all_attributes).to eq(true)
          end

          it "should not run if the command exits zero" do
            @test[param] = [@pass]
            expect(@test.check_all_attributes).to eq(false)
          end
        end

        context "with an array with multiple items" do
          it "should run if all the commands exits non-zero" do
            @test[param] = [@fail] * 3
            expect(@test.check_all_attributes).to eq(true)
          end

          it "should not run if one command exits zero" do
            @test[param] = [@pass, @fail, @pass]
            expect(@test.check_all_attributes).to eq(false)
          end

          it "should not run if all command exits zero" do
            @test[param] = [@pass] * 3
            expect(@test.check_all_attributes).to eq(false)
          end
        end

        it "should emit output to debug" do
          Puppet::Util::Log.level = :debug
          @test[param] = @fail
          expect(@test.check_all_attributes).to eq(true)
          expect(@logs.shift.message).to eq("test output")
        end
      end
    end
  end

  describe "#retrieve" do
    before :each do
      @exec_resource = Puppet::Type.type(:exec).new(:name => @bogus_cmd)
    end

    it "should return :notrun when check_all_attributes returns true" do
      @exec_resource.stubs(:check_all_attributes).returns true
      expect(@exec_resource.retrieve[:returns]).to eq(:notrun)
    end

    it "should return default exit code 0 when check_all_attributes returns false" do
      @exec_resource.stubs(:check_all_attributes).returns false
      expect(@exec_resource.retrieve[:returns]).to eq(['0'])
    end

    it "should return the specified exit code when check_all_attributes returns false" do
      @exec_resource.stubs(:check_all_attributes).returns false
      @exec_resource[:returns] = 42
      expect(@exec_resource.retrieve[:returns]).to eq(["42"])
    end
  end

  describe "#output" do
    before :each do
      @exec_resource = Puppet::Type.type(:exec).new(:name => @bogus_cmd)
    end

    it "should return the provider's run output" do
      provider = stub 'provider'
      status = stubs "process_status"
      status.stubs(:exitstatus).returns("0")
      provider.expects(:run).returns(["silly output", status])
      @exec_resource.stubs(:provider).returns(provider)

      @exec_resource.refresh
      expect(@exec_resource.output).to eq('silly output')
    end
  end

  describe "#refresh" do
    before :each do
      @exec_resource = Puppet::Type.type(:exec).new(:name => @bogus_cmd)
    end

    it "should call provider run with the refresh parameter if it is set" do
      myother_bogus_cmd = make_absolute('/myother/bogus/cmd')
      provider = stub 'provider'
      @exec_resource.stubs(:provider).returns(provider)
      @exec_resource.stubs(:[]).with(:refresh).returns(myother_bogus_cmd)
      provider.expects(:run).with(myother_bogus_cmd)

      @exec_resource.refresh
    end

    it "should call provider run with the specified command if the refresh parameter is not set" do
      provider = stub 'provider'
      status = stubs "process_status"
      status.stubs(:exitstatus).returns("0")
      provider.expects(:run).with(@bogus_cmd).returns(["silly output", status])
      @exec_resource.stubs(:provider).returns(provider)

      @exec_resource.refresh
    end

    it "should not run the provider if check_all_attributes is false" do
      @exec_resource.stubs(:check_all_attributes).returns false
      provider = stub 'provider'
      provider.expects(:run).never
      @exec_resource.stubs(:provider).returns(provider)

      @exec_resource.refresh
    end
  end

  describe "relative and absolute commands vs path" do
    let :type do Puppet::Type.type(:exec) end
    let :rel  do 'echo' end
    let :abs  do make_absolute('/bin/echo') end
    let :path do make_absolute('/bin') end

    it "should fail with relative command and no path" do
      expect { type.new(:command => rel) }.
        to raise_error Puppet::Error, /no path was specified/
    end

    it "should accept a relative command with a path" do
      expect(type.new(:command => rel, :path => path)).to be
    end

    it "should accept an absolute command with no path" do
      expect(type.new(:command => abs)).to be
    end

    it "should accept an absolute command with a path" do
      expect(type.new(:command => abs, :path => path)).to be
    end
  end
  describe "when providing a umask" do
    it "should fail if an invalid umask is used" do
      resource = Puppet::Type.type(:exec).new :command => @command
      expect { resource[:umask] = '0028'}.to raise_error(Puppet::ResourceError, /umask specification is invalid/)
      expect { resource[:umask] = '28' }.to raise_error(Puppet::ResourceError, /umask specification is invalid/)
    end
  end
end
