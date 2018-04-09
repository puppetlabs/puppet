#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/package'

provider_class = Puppet::Type.type(:augeas).provider(:augeas)

describe provider_class do
  before(:each) do
    @resource = Puppet::Type.type(:augeas).new(
      :name     => "test",
      :root     => my_fixture_dir,
      :provider => :augeas
    )
    @provider = provider_class.new(@resource)
  end

  after(:each) do
    @provider.close_augeas
  end

  describe "command parsing" do
    it "should break apart a single line into three tokens and clean up the context" do
      @resource[:context] = "/context"
      tokens = @provider.parse_commands("set Jar/Jar Binks")
      expect(tokens.size).to eq(1)
      expect(tokens[0].size).to eq(3)
      expect(tokens[0][0]).to eq("set")
      expect(tokens[0][1]).to eq("/context/Jar/Jar")
      expect(tokens[0][2]).to eq("Binks")
    end

    it "should break apart a multiple line into six tokens" do
      tokens = @provider.parse_commands("set /Jar/Jar Binks\nrm anakin")
      expect(tokens.size).to eq(2)
      expect(tokens[0].size).to eq(3)
      expect(tokens[1].size).to eq(2)
      expect(tokens[0][0]).to eq("set")
      expect(tokens[0][1]).to eq("/Jar/Jar")
      expect(tokens[0][2]).to eq("Binks")
      expect(tokens[1][0]).to eq("rm")
      expect(tokens[1][1]).to eq("anakin")
    end

    it "should strip whitespace and ignore blank lines" do
      tokens = @provider.parse_commands("  set /Jar/Jar Binks \t\n  \n\n  rm anakin ")
      expect(tokens.size).to eq(2)
      expect(tokens[0].size).to eq(3)
      expect(tokens[1].size).to eq(2)
      expect(tokens[0][0]).to eq("set")
      expect(tokens[0][1]).to eq("/Jar/Jar")
      expect(tokens[0][2]).to eq("Binks")
      expect(tokens[1][0]).to eq("rm")
      expect(tokens[1][1]).to eq("anakin")
    end

    it "should handle arrays" do
      @resource[:context] = "/foo/"
      commands = ["set /Jar/Jar Binks", "rm anakin"]
      tokens = @provider.parse_commands(commands)
      expect(tokens.size).to eq(2)
      expect(tokens[0].size).to eq(3)
      expect(tokens[1].size).to eq(2)
      expect(tokens[0][0]).to eq("set")
      expect(tokens[0][1]).to eq("/Jar/Jar")
      expect(tokens[0][2]).to eq("Binks")
      expect(tokens[1][0]).to eq("rm")
      expect(tokens[1][1]).to eq("/foo/anakin")
    end

    # This is not supported in the new parsing class
    #it "should concat the last values" do
    #    provider = provider_class.new
    #    tokens = provider.parse_commands("set /Jar/Jar Binks is my copilot")
    #    tokens.size.should == 1
    #    tokens[0].size.should == 3
    #    tokens[0][0].should == "set"
    #    tokens[0][1].should == "/Jar/Jar"
    #    tokens[0][2].should == "Binks is my copilot"
    #end

    it "should accept spaces in the value and single ticks" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("set JarJar 'Binks is my copilot'")
      expect(tokens.size).to eq(1)
      expect(tokens[0].size).to eq(3)
      expect(tokens[0][0]).to eq("set")
      expect(tokens[0][1]).to eq("/foo/JarJar")
      expect(tokens[0][2]).to eq("Binks is my copilot")
    end

    it "should accept spaces in the value and double ticks" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands('set /JarJar "Binks is my copilot"')
      expect(tokens.size).to eq(1)
      expect(tokens[0].size).to eq(3)
      expect(tokens[0][0]).to eq("set")
      expect(tokens[0][1]).to eq('/JarJar')
      expect(tokens[0][2]).to eq('Binks is my copilot')
    end

    it "should accept mixed ticks" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands('set JarJar "Some \'Test\'"')
      expect(tokens.size).to eq(1)
      expect(tokens[0].size).to eq(3)
      expect(tokens[0][0]).to eq("set")
      expect(tokens[0][1]).to eq('/foo/JarJar')
      expect(tokens[0][2]).to eq("Some \'Test\'")
    end

    it "should handle predicates with literals" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("rm */*[module='pam_console.so']")
      expect(tokens).to eq([["rm", "/foo/*/*[module='pam_console.so']"]])
    end

    it "should handle whitespace in predicates" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("ins 42 before /files/etc/hosts/*/ipaddr[ . = '127.0.0.1' ]")
      expect(tokens).to eq([["ins", "42", "before","/files/etc/hosts/*/ipaddr[ . = '127.0.0.1' ]"]])
    end

    it "should handle multiple predicates" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("clear pam.d/*/*[module = 'system-auth'][type = 'account']")
      expect(tokens).to eq([["clear", "/foo/pam.d/*/*[module = 'system-auth'][type = 'account']"]])
    end

    it "should handle nested predicates" do
      @resource[:context] = "/foo/"
      args = ["clear", "/foo/pam.d/*/*[module[ ../type = 'type] = 'system-auth'][type[last()] = 'account']"]
      tokens = @provider.parse_commands(args.join(" "))
      expect(tokens).to eq([ args ])
    end

    it "should handle escaped doublequotes in doublequoted string" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("set /foo \"''\\\"''\"")
      expect(tokens).to eq([[ "set", "/foo", "''\"''" ]])
    end

    it "should preserve escaped single quotes in double quoted strings" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("set /foo \"\\'\"")
      expect(tokens).to eq([[ "set", "/foo", "\\'" ]])
    end

    it "should allow escaped spaces and brackets in paths" do
      @resource[:context] = "/foo/"
      args = [ "set", "/white\\ space/\\[section", "value" ]
      tokens = @provider.parse_commands(args.join(" \t "))
      expect(tokens).to eq([ args ])
    end

    it "should allow single quoted escaped spaces in paths" do
      @resource[:context] = "/foo/"
      args = [ "set", "'/white\\ space/key'", "value" ]
      tokens = @provider.parse_commands(args.join(" \t "))
      expect(tokens).to eq([[ "set", "/white\\ space/key", "value" ]])
    end

    it "should allow double quoted escaped spaces in paths" do
      @resource[:context] = "/foo/"
      args = [ "set", '"/white\\ space/key"', "value" ]
      tokens = @provider.parse_commands(args.join(" \t "))
      expect(tokens).to eq([[ "set", "/white\\ space/key", "value" ]])
    end

    it "should remove trailing slashes" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("set foo/ bar")
      expect(tokens).to eq([[ "set", "/foo/foo", "bar" ]])
    end
  end

  describe "get filters" do
    before do
      augeas = stub("augeas", :get => "value")
      augeas.stubs("close")
      @provider.aug = augeas
    end

    it "should return false for a = nonmatch" do
      command = ["get", "fake value", "==", "value"]
      expect(@provider.process_get(command)).to eq(true)
    end

    it "should return true for a != match" do
      command = ["get", "fake value", "!=", "value"]
      expect(@provider.process_get(command)).to eq(false)
    end

    it "should return true for a =~ match" do
      command = ["get", "fake value", "=~", "val*"]
      expect(@provider.process_get(command)).to eq(true)
    end

    it "should return false for a == nonmatch" do
      command = ["get", "fake value", "=~", "num*"]
      expect(@provider.process_get(command)).to eq(false)
    end
  end

  describe "values filters" do
    before do
      augeas = stub("augeas", :match => ["set", "of", "values"])
      augeas.stubs(:get).returns('set').then.returns('of').then.returns('values')
      augeas.stubs("close")
      @provider = provider_class.new(@resource)
      @provider.aug = augeas
    end

    it "should return true for includes match" do
      command = ["values", "fake value", "include values"]
      expect(@provider.process_values(command)).to eq(true)
    end

    it "should return false for includes non match" do
      command = ["values", "fake value", "include JarJar"]
      expect(@provider.process_values(command)).to eq(false)
    end

    it "should return true for includes match" do
      command = ["values", "fake value", "not_include JarJar"]
      expect(@provider.process_values(command)).to eq(true)
    end

    it "should return false for includes non match" do
      command = ["values", "fake value", "not_include values"]
      expect(@provider.process_values(command)).to eq(false)
    end

    it "should return true for an array match" do
      command = ["values", "fake value", "== ['set', 'of', 'values']"]
      expect(@provider.process_values(command)).to eq(true)
    end

    it "should return false for an array non match" do
      command = ["values", "fake value", "== ['this', 'should', 'not', 'match']"]
      expect(@provider.process_values(command)).to eq(false)
    end

    it "should return false for an array match with noteq" do
      command = ["values", "fake value", "!= ['set', 'of', 'values']"]
      expect(@provider.process_values(command)).to eq(false)
    end

    it "should return true for an array non match with noteq" do
      command = ["values", "fake value", "!= ['this', 'should', 'not', 'match']"]
      expect(@provider.process_values(command)).to eq(true)
    end
  end

  describe "match filters" do
    before do
      augeas = stub("augeas", :match => ["set", "of", "values"])
      augeas.stubs("close")
      @provider = provider_class.new(@resource)
      @provider.aug = augeas
    end

    it "should return true for size match" do
      command = ["match", "fake value", "size == 3"]
      expect(@provider.process_match(command)).to eq(true)
    end

    it "should return false for a size non match" do
      command = ["match", "fake value", "size < 3"]
      expect(@provider.process_match(command)).to eq(false)
    end

    it "should return true for includes match" do
      command = ["match", "fake value", "include values"]
      expect(@provider.process_match(command)).to eq(true)
    end

    it "should return false for includes non match" do
      command = ["match", "fake value", "include JarJar"]
      expect(@provider.process_match(command)).to eq(false)
    end

    it "should return true for includes match" do
      command = ["match", "fake value", "not_include JarJar"]
      expect(@provider.process_match(command)).to eq(true)
    end

    it "should return false for includes non match" do
      command = ["match", "fake value", "not_include values"]
      expect(@provider.process_match(command)).to eq(false)
    end

    it "should return true for an array match" do
      command = ["match", "fake value", "== ['set', 'of', 'values']"]
      expect(@provider.process_match(command)).to eq(true)
    end

    it "should return false for an array non match" do
      command = ["match", "fake value", "== ['this', 'should', 'not', 'match']"]
      expect(@provider.process_match(command)).to eq(false)
    end

    it "should return false for an array match with noteq" do
      command = ["match", "fake value", "!= ['set', 'of', 'values']"]
      expect(@provider.process_match(command)).to eq(false)
    end

    it "should return true for an array non match with noteq" do
      command = ["match", "fake value", "!= ['this', 'should', 'not', 'match']"]
      expect(@provider.process_match(command)).to eq(true)
    end
  end

  describe "need to run" do
    before(:each) do
      @augeas = stub("augeas")
      @augeas.stubs("close")
      @provider.aug = @augeas

      # These tests pretend to be an earlier version so the provider doesn't
      # attempt to make the change in the need_to_run? method
      @provider.stubs(:get_augeas_version).returns("0.3.5")
    end

    it "should handle no filters" do
      @augeas.stubs("match").returns(["set", "of", "values"])
      expect(@provider.need_to_run?).to eq(true)
    end

    it "should return true when a get filter matches" do
      @resource[:onlyif] = "get path == value"
      @augeas.stubs("get").returns("value")
      expect(@provider.need_to_run?).to eq(true)
    end

    describe "performing numeric comparisons (#22617)" do
      it "should return true when a get string compare is true" do
        @resource[:onlyif] = "get bpath > a"
        @augeas.stubs("get").returns("b")
        expect(@provider.need_to_run?).to eq(true)
      end

      it "should return false when a get string compare is false" do
        @resource[:onlyif] = "get a19path > a2"
        @augeas.stubs("get").returns("a19")
        expect(@provider.need_to_run?).to eq(false)
      end

      it "should return true when a get int gt compare is true" do
        @resource[:onlyif] = "get path19 > 2"
        @augeas.stubs("get").returns("19")
        expect(@provider.need_to_run?).to eq(true)
      end

      it "should return true when a get int ge compare is true" do
        @resource[:onlyif] = "get path19 >= 2"
        @augeas.stubs("get").returns("19")
        expect(@provider.need_to_run?).to eq(true)
      end

      it "should return true when a get int lt compare is true" do
        @resource[:onlyif] = "get path2 < 19"
        @augeas.stubs("get").returns("2")
        expect(@provider.need_to_run?).to eq(true)
      end

      it "should return false when a get int le compare is false" do
        @resource[:onlyif] = "get path39 <= 4"
        @augeas.stubs("get").returns("39")
        expect(@provider.need_to_run?).to eq(false)
      end
    end
    describe "performing is_numeric checks (#22617)" do
      it "should return false for nil" do
        expect(@provider.is_numeric?(nil)).to eq(false)
      end
      it "should return true for Integers" do
        expect(@provider.is_numeric?(9)).to eq(true)
      end
      it "should return true for numbers in Strings" do
        expect(@provider.is_numeric?('9')).to eq(true)
      end
      it "should return false for non-number Strings" do
        expect(@provider.is_numeric?('x9')).to eq(false)
      end
      it "should return false for other types" do
        expect(@provider.is_numeric?([true])).to eq(false)
      end
    end

    it "should return false when a get filter does not match" do
      @resource[:onlyif] = "get path == another value"
      @augeas.stubs("get").returns("value")
      expect(@provider.need_to_run?).to eq(false)
    end

    it "should return true when a match filter matches" do
      @resource[:onlyif] = "match path size == 3"
      @augeas.stubs("match").returns(["set", "of", "values"])
      expect(@provider.need_to_run?).to eq(true)
    end

    it "should return false when a match filter does not match" do
      @resource[:onlyif] = "match path size == 2"
      @augeas.stubs("match").returns(["set", "of", "values"])
      expect(@provider.need_to_run?).to eq(false)
    end

    # Now setting force to true
    it "setting force should not change the above logic" do
      @resource[:force] = true
      @resource[:onlyif] = "match path size == 2"
      @augeas.stubs("match").returns(["set", "of", "values"])
      expect(@provider.need_to_run?).to eq(false)
    end

    #Ticket 5211 testing
    it "should return true when a size != the provided value" do
      @resource[:onlyif] = "match path size != 17"
      @augeas.stubs("match").returns(["set", "of", "values"])
      expect(@provider.need_to_run?).to eq(true)
    end

    #Ticket 5211 testing
    it "should return false when a size does equal the provided value" do
      @resource[:onlyif] = "match path size != 3"
      @augeas.stubs("match").returns(["set", "of", "values"])
      expect(@provider.need_to_run?).to eq(false)
    end

    [true, false].product([true, false]) do |cfg, param|
      describe "and Puppet[:show_diff] is #{cfg} and show_diff => #{param}" do
        let(:file) { "/some/random/file" }

        before(:each) do
          Puppet[:show_diff] = cfg
          @resource[:show_diff] = param

          @resource[:root] = ""
          @resource[:context] = "/files"
          @resource[:changes] = ["set #{file}/foo bar"]

          File.stubs(:delete)
          @provider.stubs(:get_augeas_version).returns("0.10.0")
          @provider.stubs("diff").with("#{file}", "#{file}.augnew").returns("diff")

          @augeas.stubs(:set).returns(true)
          @augeas.stubs(:save).returns(true)
          @augeas.stubs(:match).with("/augeas/events/saved").returns(["/augeas/events/saved"])
          @augeas.stubs(:get).with("/augeas/events/saved").returns("/files#{file}")
          @augeas.stubs(:set).with("/augeas/save", "newfile")
        end

        if cfg && param
          it "should display a diff" do
            expect(@provider).to be_need_to_run

            expect(@logs[0].message).to eq("\ndiff")
          end
        else
          it "should not display a diff" do
            expect(@provider).to be_need_to_run

            expect(@logs).to be_empty
          end
        end
      end
    end

    # Ticket 2728 (diff files)
    describe "and configured to show diffs" do
      before(:each) do
        Puppet[:show_diff] = true
        @resource[:show_diff] = true

        @resource[:root] = ""
        @provider.stubs(:get_augeas_version).returns("0.10.0")
        @augeas.stubs(:set).returns(true)
        @augeas.stubs(:save).returns(true)
      end

      it "should display a diff when a single file is shown to have been changed" do
        file = "/etc/hosts"
        File.stubs(:delete)

        @resource[:loglevel] = "crit"
        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file}/foo bar"]

        @augeas.stubs(:match).with("/augeas/events/saved").returns(["/augeas/events/saved"])
        @augeas.stubs(:get).with("/augeas/events/saved").returns("/files#{file}")
        @augeas.expects(:set).with("/augeas/save", "newfile")
        @provider.expects("diff").with("#{file}", "#{file}.augnew").returns("diff")

        expect(@provider).to be_need_to_run

        expect(@logs[0].message).to eq("\ndiff")
        expect(@logs[0].level).to eq(:crit)
      end

      it "should display a diff for each file that is changed when changing many files" do
        file1 = "/etc/hosts"
        file2 = "/etc/resolv.conf"
        File.stubs(:delete)

        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file1}/foo bar", "set #{file2}/baz biz"]

        @augeas.stubs(:match).with("/augeas/events/saved").returns(["/augeas/events/saved[1]", "/augeas/events/saved[2]"])
        @augeas.stubs(:get).with("/augeas/events/saved[1]").returns("/files#{file1}")
        @augeas.stubs(:get).with("/augeas/events/saved[2]").returns("/files#{file2}")
        @augeas.expects(:set).with("/augeas/save", "newfile")
        @provider.expects(:diff).with("#{file1}", "#{file1}.augnew").returns("diff #{file1}")
        @provider.expects(:diff).with("#{file2}", "#{file2}.augnew").returns("diff #{file2}")

        expect(@provider).to be_need_to_run

        expect(@logs.collect(&:message)).to include("\ndiff #{file1}", "\ndiff #{file2}")
        expect(@logs.collect(&:level)).to eq([:notice, :notice])
      end

      describe "and resource[:root] is set" do
        it "should call diff when a file is shown to have been changed" do
          root = "/tmp/foo"
          file = "/etc/hosts"
          File.stubs(:delete)

          @resource[:context] = "/files"
          @resource[:changes] = ["set #{file}/foo bar"]
          @resource[:root] = root

          @augeas.stubs(:match).with("/augeas/events/saved").returns(["/augeas/events/saved"])
          @augeas.stubs(:get).with("/augeas/events/saved").returns("/files#{file}")
          @augeas.expects(:set).with("/augeas/save", "newfile")
          @provider.expects(:diff).with("#{root}#{file}", "#{root}#{file}.augnew").returns("diff")

          expect(@provider).to be_need_to_run

          expect(@logs[0].message).to eq("\ndiff")
          expect(@logs[0].level).to eq(:notice)
        end
      end

      it "should not call diff if no files change" do
        file = "/etc/hosts"

        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file}/foo bar"]

        @augeas.stubs(:match).with("/augeas/events/saved").returns([])
        @augeas.expects(:set).with("/augeas/save", "newfile")
        @augeas.expects(:get).with("/augeas/events/saved").never()
        @augeas.expects(:close)

        @provider.expects(:diff).never()
        expect(@provider).not_to be_need_to_run
      end

      it "should cleanup the .augnew file" do
        file = "/etc/hosts"

        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file}/foo bar"]

        @augeas.stubs(:match).with("/augeas/events/saved").returns(["/augeas/events/saved"])
        @augeas.stubs(:get).with("/augeas/events/saved").returns("/files#{file}")
        @augeas.expects(:set).with("/augeas/save", "newfile")
        @augeas.expects(:close)

        File.expects(:delete).with(file + ".augnew")

        @provider.expects(:diff).with("#{file}", "#{file}.augnew").returns("")
        expect(@provider).to be_need_to_run
      end

      # Workaround for Augeas bug #264 which reports filenames twice
      it "should handle duplicate /augeas/events/saved filenames" do
        file = "/etc/hosts"

        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file}/foo bar"]

        @augeas.stubs(:match).with("/augeas/events/saved").returns(["/augeas/events/saved[1]", "/augeas/events/saved[2]"])
        @augeas.stubs(:get).with("/augeas/events/saved[1]").returns("/files#{file}")
        @augeas.stubs(:get).with("/augeas/events/saved[2]").returns("/files#{file}")
        @augeas.expects(:set).with("/augeas/save", "newfile")
        @augeas.expects(:close)

        File.expects(:delete).with(file + ".augnew").once()

        @provider.expects(:diff).with("#{file}", "#{file}.augnew").returns("").once()
        expect(@provider).to be_need_to_run
      end

      it "should fail with an error if saving fails" do
        file = "/etc/hosts"

        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file}/foo bar"]

        @augeas.stubs(:save).returns(false)
        @augeas.stubs(:match).with("/augeas/events/saved").returns([])
        @augeas.expects(:close)

        @provider.expects(:diff).never()
        @provider.expects(:print_put_errors)
        expect { @provider.need_to_run? }.to raise_error(Puppet::Error)
      end
    end
  end

  describe "augeas execution integration" do
    before do
      @augeas = stub("augeas", :load)
      @augeas.stubs("close")
      @augeas.stubs(:match).with("/augeas/events/saved").returns([])

      @provider.aug = @augeas
      @provider.stubs(:get_augeas_version).returns("0.3.5")
    end

    it "should handle set commands" do
      @resource[:changes] = "set JarJar Binks"
      @resource[:context] = "/some/path/"
      @augeas.expects(:set).with("/some/path/JarJar", "Binks").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle rm commands" do
      @resource[:changes] = "rm /Jar/Jar"
      @augeas.expects(:rm).with("/Jar/Jar")
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle remove commands" do
      @resource[:changes] = "remove /Jar/Jar"
      @augeas.expects(:rm).with("/Jar/Jar")
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle clear commands" do
      @resource[:changes] = "clear Jar/Jar"
      @resource[:context] = "/foo/"
      @augeas.expects(:clear).with("/foo/Jar/Jar").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    describe "touch command" do
      it "should clear missing path" do
        @resource[:changes] = "touch Jar/Jar"
        @resource[:context] = "/foo/"
        @augeas.expects(:match).with("/foo/Jar/Jar").returns([])
        @augeas.expects(:clear).with("/foo/Jar/Jar").returns(true)
        @augeas.expects(:save).returns(true)
        @augeas.expects(:close)
        expect(@provider.execute_changes).to eq(:executed)
      end

      it "should not change on existing path" do
        @resource[:changes] = "touch Jar/Jar"
        @resource[:context] = "/foo/"
        @augeas.expects(:match).with("/foo/Jar/Jar").returns(["/foo/Jar/Jar"])
        @augeas.expects(:clear).never
        @augeas.expects(:save).returns(true)
        @augeas.expects(:close)
        expect(@provider.execute_changes).to eq(:executed)
      end
    end

    it "should handle ins commands with before" do
      @resource[:changes] = "ins Binks before Jar/Jar"
      @resource[:context] = "/foo"
      @augeas.expects(:insert).with("/foo/Jar/Jar", "Binks", true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle ins commands with after" do
      @resource[:changes] = "ins Binks after /Jar/Jar"
      @resource[:context] = "/foo"
      @augeas.expects(:insert).with("/Jar/Jar", "Binks", false)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle ins with no context" do
      @resource[:changes] = "ins Binks after /Jar/Jar"
      @augeas.expects(:insert).with("/Jar/Jar", "Binks", false)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle multiple commands" do
      @resource[:changes] = ["ins Binks after /Jar/Jar", "clear Jar/Jar"]
      @resource[:context] = "/foo/"
      @augeas.expects(:insert).with("/Jar/Jar", "Binks", false)
      @augeas.expects(:clear).with("/foo/Jar/Jar").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle defvar commands" do
      @resource[:changes] = "defvar myjar Jar/Jar"
      @resource[:context] = "/foo/"
      @augeas.expects(:defvar).with("myjar", "/foo/Jar/Jar").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should pass through augeas variables without context" do
      @resource[:changes] = ["defvar myjar Jar/Jar","set $myjar/Binks 1"]
      @resource[:context] = "/foo/"
      @augeas.expects(:defvar).with("myjar", "/foo/Jar/Jar").returns(true)
      # this is the important bit, shouldn't be /foo/$myjar/Binks
      @augeas.expects(:set).with("$myjar/Binks", "1").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle defnode commands" do
      @resource[:changes] = "defnode newjar Jar/Jar[last()+1] Binks"
      @resource[:context] = "/foo/"
      @augeas.expects(:defnode).with("newjar", "/foo/Jar/Jar[last()+1]", "Binks").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle mv commands" do
      @resource[:changes] = "mv Jar/Jar Binks"
      @resource[:context] = "/foo/"
      @augeas.expects(:mv).with("/foo/Jar/Jar", "/foo/Binks").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle rename commands" do
      @resource[:changes] = "rename Jar/Jar Binks"
      @resource[:context] = "/foo/"
      @augeas.expects(:rename).with("/foo/Jar/Jar", "Binks").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should handle setm commands" do
      @resource[:changes] = ["set test[1]/Jar/Jar Foo","set test[2]/Jar/Jar Bar","setm test Jar/Jar Binks"]
      @resource[:context] = "/foo/"
      @augeas.expects(:respond_to?).with("setm").returns(true)
      @augeas.expects(:set).with("/foo/test[1]/Jar/Jar", "Foo").returns(true)
      @augeas.expects(:set).with("/foo/test[2]/Jar/Jar", "Bar").returns(true)
      @augeas.expects(:setm).with("/foo/test", "Jar/Jar", "Binks").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should throw error if setm command not supported" do
      @resource[:changes] = ["set test[1]/Jar/Jar Foo","set test[2]/Jar/Jar Bar","setm test Jar/Jar Binks"]
      @resource[:context] = "/foo/"
      @augeas.expects(:respond_to?).with("setm").returns(false)
      @augeas.expects(:set).with("/foo/test[1]/Jar/Jar", "Foo").returns(true)
      @augeas.expects(:set).with("/foo/test[2]/Jar/Jar", "Bar").returns(true)
      expect { @provider.execute_changes }.to raise_error RuntimeError, /command 'setm' not supported/
    end

    it "should handle clearm commands" do
      @resource[:changes] = ["set test[1]/Jar/Jar Foo","set test[2]/Jar/Jar Bar","clearm test Jar/Jar"]
      @resource[:context] = "/foo/"
      @augeas.expects(:respond_to?).with("clearm").returns(true)
      @augeas.expects(:set).with("/foo/test[1]/Jar/Jar", "Foo").returns(true)
      @augeas.expects(:set).with("/foo/test[2]/Jar/Jar", "Bar").returns(true)
      @augeas.expects(:clearm).with("/foo/test", "Jar/Jar").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      expect(@provider.execute_changes).to eq(:executed)
    end

    it "should throw error if clearm command not supported" do
      @resource[:changes] = ["set test[1]/Jar/Jar Foo","set test[2]/Jar/Jar Bar","clearm test Jar/Jar"]
      @resource[:context] = "/foo/"
      @augeas.expects(:respond_to?).with("clearm").returns(false)
      @augeas.expects(:set).with("/foo/test[1]/Jar/Jar", "Foo").returns(true)
      @augeas.expects(:set).with("/foo/test[2]/Jar/Jar", "Bar").returns(true)
      expect { @provider.execute_changes }.to raise_error(RuntimeError, /command 'clearm' not supported/)
    end

    it "should throw error if saving failed" do
      @resource[:changes] = ["set test[1]/Jar/Jar Foo","set test[2]/Jar/Jar Bar","clearm test Jar/Jar"]
      @resource[:context] = "/foo/"
      @augeas.expects(:respond_to?).with("clearm").returns(true)
      @augeas.expects(:set).with("/foo/test[1]/Jar/Jar", "Foo").returns(true)
      @augeas.expects(:set).with("/foo/test[2]/Jar/Jar", "Bar").returns(true)
      @augeas.expects(:clearm).with("/foo/test", "Jar/Jar").returns(true)
      @augeas.expects(:save).returns(false)
      @provider.expects(:print_put_errors)
      @augeas.expects(:match).returns([])
      expect { @provider.execute_changes }.to raise_error(Puppet::Error)
    end
  end

  describe "when making changes", :if => Puppet.features.augeas? do
    include PuppetSpec::Files

    it "should not clobber the file if it's a symlink" do
      Puppet::Util::Storage.stubs(:store)

      link = tmpfile('link')
      target = tmpfile('target')
      FileUtils.touch(target)
      Puppet::FileSystem.symlink(target, link)

      resource = Puppet::Type.type(:augeas).new(
        :name => 'test',
        :incl => link,
        :lens => 'Sshd.lns',
        :changes => "set PermitRootLogin no"
      )

      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource resource

      catalog.apply

      expect(File.ftype(link)).to eq('link')
      expect(Puppet::FileSystem.readlink(link)).to eq(target)
      expect(File.read(target)).to match(/PermitRootLogin no/)
    end
  end

  describe "load/save failure reporting" do
    before do
      @augeas = stub("augeas")
      @augeas.stubs("close")
      @provider.aug = @augeas
    end

    describe "should find load errors" do
      before do
        @augeas.expects(:match).with("/augeas//error").returns(["/augeas/files/foo/error"])
        @augeas.expects(:match).with("/augeas/files/foo/error/*").returns(["/augeas/files/foo/error/path", "/augeas/files/foo/error/message"])
        @augeas.expects(:get).with("/augeas/files/foo/error").returns("some_failure")
        @augeas.expects(:get).with("/augeas/files/foo/error/path").returns("/foo")
        @augeas.expects(:get).with("/augeas/files/foo/error/message").returns("Failed to...")
      end

      it "and output only to debug when no path supplied" do
        @provider.expects(:debug).times(5)
        @provider.expects(:warning).never()
        @provider.print_load_errors(nil)
      end

      it "and output a warning and to debug when path supplied" do
        @augeas.expects(:match).with("/augeas/files/foo//error").returns(["/augeas/files/foo/error"])
        @provider.expects(:warning).once()
        @provider.expects(:debug).times(4)
        @provider.print_load_errors('/augeas/files/foo//error')
      end

      it "and output only to debug when path doesn't match" do
        @augeas.expects(:match).with("/augeas/files/foo//error").returns([])
        @provider.expects(:warning).never()
        @provider.expects(:debug).times(5)
        @provider.print_load_errors('/augeas/files/foo//error')
      end
    end

    it "should find load errors from lenses" do
      @augeas.expects(:match).with("/augeas//error").twice.returns(["/augeas/load/Xfm/error"])
      @augeas.expects(:match).with("/augeas/load/Xfm/error/*").returns([])
      @augeas.expects(:get).with("/augeas/load/Xfm/error").returns(["Could not find lens php.aug"])
      @provider.expects(:warning).once()
      @provider.expects(:debug).twice()
      @provider.print_load_errors('/augeas//error')
    end

    it "should find save errors and output to debug" do
      @augeas.expects(:match).with("/augeas//error[. = 'put_failed']").returns(["/augeas/files/foo/error"])
      @augeas.expects(:match).with("/augeas/files/foo/error/*").returns(["/augeas/files/foo/error/path", "/augeas/files/foo/error/message"])
      @augeas.expects(:get).with("/augeas/files/foo/error").returns("some_failure")
      @augeas.expects(:get).with("/augeas/files/foo/error/path").returns("/foo")
      @augeas.expects(:get).with("/augeas/files/foo/error/message").returns("Failed to...")
      @provider.expects(:debug).times(5)
      @provider.print_put_errors
    end
  end

  # Run initialisation tests of the real Augeas library to test our open_augeas
  # method.  This relies on Augeas and ruby-augeas on the host to be
  # functioning.
  describe "augeas lib initialisation", :if => Puppet.features.augeas? do
    # Expect lenses for fstab and hosts
    it "should have loaded standard files by default" do
      aug = @provider.open_augeas
      expect(aug).not_to eq(nil)
      expect(aug.match("/files/etc/fstab")).to eq(["/files/etc/fstab"])
      expect(aug.match("/files/etc/hosts")).to eq(["/files/etc/hosts"])
      expect(aug.match("/files/etc/test")).to eq([])
    end

    it "should report load errors to debug only" do
      @provider.expects(:print_load_errors).with(nil)
      aug = @provider.open_augeas
      expect(aug).not_to eq(nil)
    end

    # Only the file specified should be loaded
    it "should load one file if incl/lens used" do
      @resource[:incl] = "/etc/hosts"
      @resource[:lens] = "Hosts.lns"

      @provider.expects(:print_load_errors).with('/augeas//error')
      aug = @provider.open_augeas
      expect(aug).not_to eq(nil)
      expect(aug.match("/files/etc/fstab")).to eq([])
      expect(aug.match("/files/etc/hosts")).to eq(["/files/etc/hosts"])
      expect(aug.match("/files/etc/test")).to eq([])
    end

    it "should also load lenses from load_path" do
      @resource[:load_path] = my_fixture_dir

      aug = @provider.open_augeas
      expect(aug).not_to eq(nil)
      expect(aug.match("/files/etc/fstab")).to eq(["/files/etc/fstab"])
      expect(aug.match("/files/etc/hosts")).to eq(["/files/etc/hosts"])
      expect(aug.match("/files/etc/test")).to eq(["/files/etc/test"])
    end

    it "should also load lenses from pluginsync'd path" do
      Puppet[:libdir] = my_fixture_dir

      aug = @provider.open_augeas
      expect(aug).not_to eq(nil)
      expect(aug.match("/files/etc/fstab")).to eq(["/files/etc/fstab"])
      expect(aug.match("/files/etc/hosts")).to eq(["/files/etc/hosts"])
      expect(aug.match("/files/etc/test")).to eq(["/files/etc/test"])
    end

    # Optimisations added for Augeas 0.8.2 or higher is available, see #7285
    describe ">= 0.8.2 optimisations", :if => Puppet.features.augeas? && Facter.value(:augeasversion) && Puppet::Util::Package.versioncmp(Facter.value(:augeasversion), "0.8.2") >= 0 do
      it "should only load one file if relevant context given" do
        @resource[:context] = "/files/etc/fstab"

        @provider.expects(:print_load_errors).with('/augeas/files/etc/fstab//error')
        aug = @provider.open_augeas
        expect(aug).not_to eq(nil)
        expect(aug.match("/files/etc/fstab")).to eq(["/files/etc/fstab"])
        expect(aug.match("/files/etc/hosts")).to eq([])
      end

      it "should only load one lens from load_path if context given" do
        @resource[:context] = "/files/etc/test"
        @resource[:load_path] = my_fixture_dir

        @provider.expects(:print_load_errors).with('/augeas/files/etc/test//error')
        aug = @provider.open_augeas
        expect(aug).not_to eq(nil)
        expect(aug.match("/files/etc/fstab")).to eq([])
        expect(aug.match("/files/etc/hosts")).to eq([])
        expect(aug.match("/files/etc/test")).to eq(["/files/etc/test"])
      end

      it "should load standard files if context isn't specific" do
        @resource[:context] = "/files/etc"

        @provider.expects(:print_load_errors).with(nil)
        aug = @provider.open_augeas
        expect(aug).not_to eq(nil)
        expect(aug.match("/files/etc/fstab")).to eq(["/files/etc/fstab"])
        expect(aug.match("/files/etc/hosts")).to eq(["/files/etc/hosts"])
      end

      it "should not optimise if the context is a complex path" do
        @resource[:context] = "/files/*[label()='etc']"

        @provider.expects(:print_load_errors).with(nil)
        aug = @provider.open_augeas
        expect(aug).not_to eq(nil)
        expect(aug.match("/files/etc/fstab")).to eq(["/files/etc/fstab"])
        expect(aug.match("/files/etc/hosts")).to eq(["/files/etc/hosts"])
      end
    end
  end

  describe "get_load_path" do
    it "should offer no load_path by default" do
      expect(@provider.get_load_path(@resource)).to eq("")
    end

    it "should offer one path from load_path" do
      @resource[:load_path] = "/foo"
      expect(@provider.get_load_path(@resource)).to eq("/foo")
    end

    it "should offer multiple colon-separated paths from load_path" do
      @resource[:load_path] = "/foo:/bar:/baz"
      expect(@provider.get_load_path(@resource)).to eq("/foo:/bar:/baz")
    end

    it "should offer multiple paths in array from load_path" do
      @resource[:load_path] = ["/foo", "/bar", "/baz"]
      expect(@provider.get_load_path(@resource)).to eq("/foo:/bar:/baz")
    end

    it "should offer pluginsync augeas/lenses subdir" do
      Puppet[:libdir] = my_fixture_dir
      expect(@provider.get_load_path(@resource)).to eq("#{my_fixture_dir}/augeas/lenses")
    end

    it "should offer both pluginsync and load_path paths" do
      Puppet[:libdir] = my_fixture_dir
      @resource[:load_path] = ["/foo", "/bar", "/baz"]
      expect(@provider.get_load_path(@resource)).to eq("/foo:/bar:/baz:#{my_fixture_dir}/augeas/lenses")
    end
  end
end
