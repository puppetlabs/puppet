#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:exec) do
  def exec_tester(command, exitstatus = 0, rest = {})
    @user_name  = 'some_user_name'
    @group_name = 'some_group_name'
    Puppet.features.stubs(:root?).returns(true)

    output = rest.delete(:output) || ''
    tries  = rest[:tries] || 1

    args = {
      :name      => command,
      :path      => @example_path,
      :user      => @user_name,
      :group     => @group_name,
      :logoutput => false,
      :loglevel  => :err,
      :returns   => 0
    }.merge(rest)

    exec = Puppet::Type.type(:exec).new(args)

    status = stub "process", :exitstatus => exitstatus
    Puppet::Util::SUIDManager.expects(:run_and_capture).times(tries).
      with([command], @user_name, @group_name).returns([output, status])

    return exec
  end

  before do
    @command = Puppet.features.posix? ? '/bin/true whatever' : '"C:/Program Files/something.exe" whatever'
  end

  describe "when not stubbing the provider" do
    before do
      @executable = Puppet.features.posix? ? '/bin/true' : 'C:/Program Files/something.exe'
      File.stubs(:exists?).returns false
      File.stubs(:exists?).with(@executable).returns true
      File.stubs(:exists?).with('/bin/false').returns true
      @example_path = Puppet.features.posix? ? %w{/usr/bin /bin} : [ "C:/Program Files/something/bin", "C:/Ruby/bin" ]
      File.stubs(:exists?).with(File.join(@example_path[0],"true")).returns true
      File.stubs(:exists?).with(File.join(@example_path[0],"false")).returns true
    end

    it "should return :executed_command as its event" do
      resource = Puppet::Type.type(:exec).new :command => @command
      resource.parameter(:returns).event.name.should == :executed_command
    end

    describe "when execing" do
      it "should use the 'run_and_capture' method to exec" do
        exec_tester("true").refresh.should == :executed_command
      end

      it "should report a failure" do
        proc { exec_tester('false', 1).refresh }.
          should raise_error(Puppet::Error, /^false returned 1 instead of/)
      end

      it "should not report a failure if the exit status is specified in a returns array" do
        proc { exec_tester("false", 1, :returns => [0, 1]).refresh }.should_not raise_error
      end

      it "should report a failure if the exit status is not specified in a returns array" do
        proc { exec_tester('false', 1, :returns => [0, 100]).refresh }.
          should raise_error(Puppet::Error, /^false returned 1 instead of/)
      end

      it "should log the output on success" do
        output = "output1\noutput2\n"
        exec_tester('false', 0, :output => output, :logoutput => true).refresh
        output.split("\n").each do |line|
          log = @logs.shift
          log.level.should == :err
          log.message.should == line
        end
      end

      it "should log the output on failure" do
        output = "output1\noutput2\n"
        proc { exec_tester('false', 1, :output => output, :logoutput => true).refresh }.
          should raise_error(Puppet::Error)

        output.split("\n").each do |line|
          log = @logs.shift
          log.level.should == :err
          log.message.should == line
        end
      end
    end

    describe "when logoutput=>on_failure is set" do
      it "should log the output on failure" do
        output = "output1\noutput2\n"
        proc { exec_tester('false', 1, :output => output, :logoutput => :on_failure).refresh }.
          should raise_error(Puppet::Error, /^false returned 1 instead of/)

        output.split("\n").each do |line|
          log = @logs.shift
          log.level.should == :err
          log.message.should == line
        end
      end

      it "should log the output on failure when returns is specified as an array" do
        output = "output1\noutput2\n"

        proc {
          exec_tester('false', 1, :output => output, :returns => [0, 100],
               :logoutput => :on_failure).refresh
        }.should raise_error(Puppet::Error, /^false returned 1 instead of/)

        output.split("\n").each do |line|
          log = @logs.shift
          log.level.should == :err
          log.message.should == line
        end
      end

      it "shouldn't log the output on success" do
        exec_tester('true', 0, :output => "a\nb\nc\n", :logoutput => :on_failure).refresh
        @logs.should == []
      end
    end

    it "shouldn't log the output on success when non-zero exit status is in a returns array" do
      exec_tester("true", 100, :output => "a\n", :logoutput => :on_failure, :returns => [1, 100]).refresh
      @logs.should == []
    end

    describe " when multiple tries are set," do
      it "should repeat the command attempt 'tries' times on failure and produce an error" do
        tries = 5
        resource = exec_tester("false", 1, :tries => tries, :try_sleep => 0)
        proc { resource.refresh }.should raise_error(Puppet::Error)
      end
    end
  end

  it "should be able to autorequire files mentioned in the command" do
    catalog = Puppet::Resource::Catalog.new
    tmp = Puppet::Type.type(:file).new(:name => "/bin/foo")
    catalog.add_resource tmp
    execer = Puppet::Type.type(:exec).new(:name => "/bin/foo")
    catalog.add_resource execer

    catalog.relationship_graph.dependencies(execer).should == [tmp]
  end

  describe "when handling the path parameter" do
    expect = %w{one two three four}
    { "an array"                        => expect,
      "a colon separated list"          => "one:two:three:four",
      "a semi-colon separated list"     => "one;two;three;four",
      "both array and colon lists"      => ["one", "two:three", "four"],
      "both array and semi-colon lists" => ["one", "two;three", "four"],
      "colon and semi-colon lists"      => ["one:two", "three;four"]
    }.each do |test, input|
      it "should accept #{test}" do
        type = Puppet::Type.type(:exec).new(:name => @command, :path => input)
        type[:path].should == expect
      end
    end
  end

  describe "when setting user" do
    it "should fail if we are not root" do
      Puppet.features.stubs(:root?).returns(false)
      expect { Puppet::Type.type(:exec).new(:name => @command, :user => 'input') }.
        should raise_error Puppet::Error, /Parameter user failed/
    end

    ['one', 2, 'root', 4294967295, 4294967296].each do |value|
      it "should accept '#{value}' as user if we are root" do
        Puppet.features.stubs(:root?).returns(true)
        type = Puppet::Type.type(:exec).new(:name => @command, :user => value)
        type[:user].should == value
      end
    end
  end

  describe "when setting group" do
    shared_examples_for "exec[:group]" do
      ['one', 2, 'wheel', 4294967295, 4294967296].each do |value|
        it "should accept '#{value}' without error or judgement" do
          type = Puppet::Type.type(:exec).new(:name => @command, :group => value)
          type[:group].should == value
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
        Puppet::Type.type(:exec).new(:name => '/bin/true', :cwd => path)
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
            instance = Puppet::Type.type(:exec).new(:name => "/bin/true")
          end
          if valid then
            instance.provider.expects(:validatecmd).returns(true)
          else
            instance.provider.expects(:validatecmd).raises(Puppet::Error, "from a stub")
          end
          instance[@param] = command
        end

        it "should work if the provider calls the command valid" do
          expect { test(command, true) }.should_not raise_error
        end

        it "should fail if the provider calls the command invalid" do
          expect { test(command, false) }.
            should raise_error Puppet::Error, /Parameter #{@param} failed: from a stub/
        end
      end
    end
  end

  shared_examples_for "all exec command parameters that take arrays" do |param|
    describe "when given an array of inputs" do
      before :each do
        @test = Puppet::Type.type(:exec).new(:name => "/bin/true")
      end

      it "should accept the array when all commands return valid" do
        input = %w{one two three}
        @test.provider.expects(:validatecmd).times(input.length).returns(true)
        @test[param] = input
        @test[param].should == input
      end

      it "should reject the array when any commands return invalid" do
        input = %w{one two three}
        @test.provider.expects(:validatecmd).with(input.first).returns(false)
        input[1..-1].each do |cmd|
          @test.provider.expects(:validatecmd).with(cmd).returns(true)
        end
        @test[param] = input
        @test[param].should == input
      end

      it "should reject the array when all commands return invalid" do
        input = %w{one two three}
        @test.provider.expects(:validatecmd).times(input.length).returns(false)
        @test[param] = input
        @test[param].should == input
      end
    end
  end

  describe "when setting refresh" do
    it_should_behave_like "all exec command parameters", :refresh
  end

  describe "for simple parameters" do
    before :each do
      @exec = Puppet::Type.type(:exec).new(:name => '/bin/true')
    end

    describe "when setting environment" do
      { "single values"   => "foo=bar",
        "multiple values" => ["foo=bar", "baz=quux"],
      }.each do |name, data|
        it "should accept #{name}" do
          @exec[:environment] = data
          @exec[:environment].should == data
        end
      end

      { "single values" => "foo",
        "only values"   => ["foo", "bar"],
        "any values"    => ["foo=bar", "baz"]
      }.each do |name, data|
        it "should reject #{name} without assignment" do
          expect { @exec[:environment] = data }.
            should raise_error Puppet::Error, /Invalid environment setting/
        end
      end
    end

    describe "when setting timeout" do
      [0, 0.1, 1, 10, 4294967295].each do |valid|
        it "should accept '#{valid}' as valid" do
          @exec[:timeout] = valid
          @exec[:timeout].should == valid
        end

        it "should accept '#{valid}' in an array as valid" do
          @exec[:timeout] = [valid]
          @exec[:timeout].should == valid
        end
      end

      ['1/2', '', 'foo', '5foo'].each do |invalid|
        it "should reject '#{invalid}' as invalid" do
          expect { @exec[:timeout] = invalid }.
            should raise_error Puppet::Error, /The timeout must be a number/
        end

        it "should reject '#{invalid}' in an array as invalid" do
          expect { @exec[:timeout] = [invalid] }.
            should raise_error Puppet::Error, /The timeout must be a number/
        end
      end

      it "should fail if timeout is exceeded" do
        File.stubs(:exists?).with('/bin/sleep').returns(true)
        File.stubs(:exists?).with('sleep').returns(false)
        sleep_exec = Puppet::Type.type(:exec).new(:name => 'sleep 1', :path => ['/bin'], :timeout => '0.2')
        lambda { sleep_exec.refresh }.should raise_error Puppet::Error, "Command exceeded timeout"
      end

      it "should convert timeout to a float" do
        resource = Puppet::Type.type(:exec).new :command => "/bin/false", :timeout => "12"
        resource[:timeout].should be_a(Float)
        resource[:timeout].should == 12.0
      end

      it "should munge negative timeouts to 0.0" do
        resource = Puppet::Type.type(:exec).new :command => "/bin/false", :timeout => "-12.0"
        resource.parameter(:timeout).value.should be_a(Float)
        resource.parameter(:timeout).value.should == 0.0
      end
    end

    describe "when setting tries" do
      [1, 10, 4294967295].each do |valid|
        it "should accept '#{valid}' as valid" do
          @exec[:tries] = valid
          @exec[:tries].should == valid
        end

        if "REVISIT: too much test log spam" == "a good thing" then
          it "should accept '#{valid}' in an array as valid" do
            pending "inconsistent, but this is not supporting arrays, unlike timeout"
            @exec[:tries] = [valid]
            @exec[:tries].should == valid
          end
        end
      end

      [-3.5, -1, 0, 0.2, '1/2', '1_000_000', '+12', '', 'foo'].each do |invalid|
        it "should reject '#{invalid}' as invalid" do
          expect { @exec[:tries] = invalid }.
            should raise_error Puppet::Error, /Tries must be an integer/
        end

        if "REVISIT: too much test log spam" == "a good thing" then
          it "should reject '#{invalid}' in an array as invalid" do
            pending "inconsistent, but this is not supporting arrays, unlike timeout"
            expect { @exec[:tries] = [invalid] }.
              should raise_error Puppet::Error, /Tries must be an integer/
          end
        end
      end
    end

    describe "when setting try_sleep" do
      [0, 0.2, 1, 10, 4294967295].each do |valid|
        it "should accept '#{valid}' as valid" do
          @exec[:try_sleep] = valid
          @exec[:try_sleep].should == valid
        end

        if "REVISIT: too much test log spam" == "a good thing" then
          it "should accept '#{valid}' in an array as valid" do
            pending "inconsistent, but this is not supporting arrays, unlike timeout"
            @exec[:try_sleep] = [valid]
            @exec[:try_sleep].should == valid
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
            should raise_error Puppet::Error, /try_sleep #{error}/
        end

        if "REVISIT: too much test log spam" == "a good thing" then
          it "should reject '#{invalid}' in an array as invalid" do
            pending "inconsistent, but this is not supporting arrays, unlike timeout"
            expect { @exec[:try_sleep] = [invalid] }.
              should raise_error Puppet::Error, /try_sleep #{error}/
          end
        end
      end
    end

    describe "when setting refreshonly" do
      [:true, :false].each do |value|
        it "should accept '#{value}'" do
          @exec[:refreshonly] = value
          @exec[:refreshonly].should == value
        end
      end

      [1, 0, "1", "0", "yes", "y", "no", "n"].each do |value|
        it "should reject '#{value}'" do
          expect { @exec[:refreshonly] = value }.
            should raise_error(Puppet::Error,
              /Invalid value #{value.inspect}\. Valid values are true, false/
            )
        end
      end
    end

    describe "when setting creates" do
      it_should_behave_like "all path parameters", :creates, :array => true do
        def instance(path)
          Puppet::Type.type(:exec).new(:name => '/bin/true', :creates => path)
        end
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
      @test = Puppet::Type.type(:exec).new(:name => "/bin/true")
    end

    describe ":refreshonly" do
      { :true => false, :false => true }.each do |input, result|
        it "should return '#{result}' when given '#{input}'" do
          @test[:refreshonly] = input
          @test.check_all_attributes.should == result
        end
      end
    end

    describe ":creates" do
      before :all do
        @exist   = "/"
        @unexist = "/this/path/should/never/exist"
        while FileTest.exist?(@unexist) do @unexist += "/foo" end
      end

      context "with a single item" do
        it "should run when the item does not exist" do
          @test[:creates] = @unexist
          @test.check_all_attributes.should == true
        end

        it "should not run when the item exists" do
          @test[:creates] = @exist
          @test.check_all_attributes.should == false
        end
      end

      context "with an array with one item" do
        it "should run when the item does not exist" do
          @test[:creates] = [@unexist]
          @test.check_all_attributes.should == true
        end

        it "should not run when the item exists" do
          @test[:creates] = [@exist]
          @test.check_all_attributes.should == false
        end
      end

      context "with an array with multiple items" do
        it "should run when all items do not exist" do
          @test[:creates] = [@unexist] * 3
          @test.check_all_attributes.should == true
        end

        it "should not run when one item exists" do
          @test[:creates] = [@unexist, @exist, @unexist]
          @test.check_all_attributes.should == false
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
          @pass = "/magic/pass"
          @fail = "/magic/fail"

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
            @test.check_all_attributes.should == true
          end

          it "should not run if the command exits zero" do
            @test[param] = @pass
            @test.check_all_attributes.should == false
          end
        end

        context "with an array with a single item" do
          it "should run if the command exits non-zero" do
            @test[param] = [@fail]
            @test.check_all_attributes.should == true
          end

          it "should not run if the command exits zero" do
            @test[param] = [@pass]
            @test.check_all_attributes.should == false
          end
        end

        context "with an array with multiple items" do
          it "should run if all the commands exits non-zero" do
            @test[param] = [@fail] * 3
            @test.check_all_attributes.should == true
          end

          it "should not run if one command exits zero" do
            @test[param] = [@pass, @fail, @pass]
            @test.check_all_attributes.should == false
          end

          it "should not run if all command exits zero" do
            @test[param] = [@pass] * 3
            @test.check_all_attributes.should == false
          end
        end
      end
    end
  end

  describe "#retrieve" do
    before :each do
      @exec_resource = Puppet::Type.type(:exec).new(:name => "/bogus/cmd")
    end

    it "should return :notrun when check_all_attributes returns true" do
      @exec_resource.stubs(:check_all_attributes).returns true
      @exec_resource.retrieve[:returns].should == :notrun
    end

    it "should return default exit code 0 when check_all_attributes returns false" do
      @exec_resource.stubs(:check_all_attributes).returns false
      @exec_resource.retrieve[:returns].should == ['0']
    end

    it "should return the specified exit code when check_all_attributes returns false" do
      @exec_resource.stubs(:check_all_attributes).returns false
      @exec_resource[:returns] = 42
      @exec_resource.retrieve[:returns].should == ["42"]
    end
  end

  describe "#output" do
    before :each do
      @exec_resource = Puppet::Type.type(:exec).new(:name => "/bogus/cmd")
    end

    it "should return the provider's run output" do
      provider = stub 'provider'
      status = stubs "process_status"
      status.stubs(:exitstatus).returns("0")
      provider.expects(:run).returns(["silly output", status])
      @exec_resource.stubs(:provider).returns(provider)

      @exec_resource.refresh
      @exec_resource.output.should == 'silly output'
    end
  end

  describe "#refresh" do
    before :each do
      @exec_resource = Puppet::Type.type(:exec).new(:name => "/bogus/cmd")
    end

    it "should call provider run with the refresh parameter if it is set" do
      provider = stub 'provider'
      @exec_resource.stubs(:provider).returns(provider)
      @exec_resource.stubs(:[]).with(:refresh).returns('/myother/bogus/cmd')
      provider.expects(:run).with('/myother/bogus/cmd')

      @exec_resource.refresh
    end

    it "should call provider run with the specified command if the refresh parameter is not set" do
      provider = stub 'provider'
      status = stubs "process_status"
      status.stubs(:exitstatus).returns("0")
      provider.expects(:run).with('/bogus/cmd').returns(["silly output", status])
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
end
