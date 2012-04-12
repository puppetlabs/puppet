#!/usr/bin/env rspec
require 'spec_helper'

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
      tokens.size.should == 1
      tokens[0].size.should == 3
      tokens[0][0].should == "set"
      tokens[0][1].should == "/context/Jar/Jar"
      tokens[0][2].should == "Binks"
    end

    it "should break apart a multiple line into six tokens" do
      tokens = @provider.parse_commands("set /Jar/Jar Binks\nrm anakin")
      tokens.size.should == 2
      tokens[0].size.should == 3
      tokens[1].size.should == 2
      tokens[0][0].should == "set"
      tokens[0][1].should == "/Jar/Jar"
      tokens[0][2].should == "Binks"
      tokens[1][0].should == "rm"
      tokens[1][1].should == "anakin"
    end

    it "should strip whitespace and ignore blank lines" do
      tokens = @provider.parse_commands("  set /Jar/Jar Binks \t\n  \n\n  rm anakin ")
      tokens.size.should == 2
      tokens[0].size.should == 3
      tokens[1].size.should == 2
      tokens[0][0].should == "set"
      tokens[0][1].should == "/Jar/Jar"
      tokens[0][2].should == "Binks"
      tokens[1][0].should == "rm"
      tokens[1][1].should == "anakin"
    end

    it "should handle arrays" do
      @resource[:context] = "/foo/"
      commands = ["set /Jar/Jar Binks", "rm anakin"]
      tokens = @provider.parse_commands(commands)
      tokens.size.should == 2
      tokens[0].size.should == 3
      tokens[1].size.should == 2
      tokens[0][0].should == "set"
      tokens[0][1].should == "/Jar/Jar"
      tokens[0][2].should == "Binks"
      tokens[1][0].should == "rm"
      tokens[1][1].should == "/foo/anakin"
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
      tokens.size.should == 1
      tokens[0].size.should == 3
      tokens[0][0].should == "set"
      tokens[0][1].should == "/foo/JarJar"
      tokens[0][2].should == "Binks is my copilot"
    end

    it "should accept spaces in the value and double ticks" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands('set /JarJar "Binks is my copilot"')
      tokens.size.should == 1
      tokens[0].size.should == 3
      tokens[0][0].should == "set"
      tokens[0][1].should == '/JarJar'
      tokens[0][2].should == 'Binks is my copilot'
    end

    it "should accept mixed ticks" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands('set JarJar "Some \'Test\'"')
      tokens.size.should == 1
      tokens[0].size.should == 3
      tokens[0][0].should == "set"
      tokens[0][1].should == '/foo/JarJar'
      tokens[0][2].should == "Some \'Test\'"
    end

    it "should handle predicates with literals" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("rm */*[module='pam_console.so']")
      tokens.should == [["rm", "/foo/*/*[module='pam_console.so']"]]
    end

    it "should handle whitespace in predicates" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("ins 42 before /files/etc/hosts/*/ipaddr[ . = '127.0.0.1' ]")
      tokens.should == [["ins", "42", "before","/files/etc/hosts/*/ipaddr[ . = '127.0.0.1' ]"]]
    end

    it "should handle multiple predicates" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("clear pam.d/*/*[module = 'system-auth'][type = 'account']")
      tokens.should == [["clear", "/foo/pam.d/*/*[module = 'system-auth'][type = 'account']"]]
    end

    it "should handle nested predicates" do
      @resource[:context] = "/foo/"
      args = ["clear", "/foo/pam.d/*/*[module[ ../type = 'type] = 'system-auth'][type[last()] = 'account']"]
      tokens = @provider.parse_commands(args.join(" "))
      tokens.should == [ args ]
    end

    it "should handle escaped doublequotes in doublequoted string" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("set /foo \"''\\\"''\"")
      tokens.should == [[ "set", "/foo", "''\\\"''" ]]
    end

    it "should allow escaped spaces and brackets in paths" do
      @resource[:context] = "/foo/"
      args = [ "set", "/white\\ space/\\[section", "value" ]
      tokens = @provider.parse_commands(args.join(" \t "))
      tokens.should == [ args ]
    end

    it "should allow single quoted escaped spaces in paths" do
      @resource[:context] = "/foo/"
      args = [ "set", "'/white\\ space/key'", "value" ]
      tokens = @provider.parse_commands(args.join(" \t "))
      tokens.should == [[ "set", "/white\\ space/key", "value" ]]
    end

    it "should allow double quoted escaped spaces in paths" do
      @resource[:context] = "/foo/"
      args = [ "set", '"/white\\ space/key"', "value" ]
      tokens = @provider.parse_commands(args.join(" \t "))
      tokens.should == [[ "set", "/white\\ space/key", "value" ]]
    end

    it "should remove trailing slashes" do
      @resource[:context] = "/foo/"
      tokens = @provider.parse_commands("set foo/ bar")
      tokens.should == [[ "set", "/foo/foo", "bar" ]]
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
      @provider.process_get(command).should == true
    end

    it "should return true for a != match" do
      command = ["get", "fake value", "!=", "value"]
      @provider.process_get(command).should == false
    end

    it "should return true for a =~ match" do
      command = ["get", "fake value", "=~", "val*"]
      @provider.process_get(command).should == true
    end

    it "should return false for a == nonmatch" do
      command = ["get", "fake value", "=~", "num*"]
      @provider.process_get(command).should == false
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
      @provider.process_match(command).should == true
    end

    it "should return false for a size non match" do
      command = ["match", "fake value", "size < 3"]
      @provider.process_match(command).should == false
    end

    it "should return true for includes match" do
      command = ["match", "fake value", "include values"]
      @provider.process_match(command).should == true
    end

    it "should return false for includes non match" do
      command = ["match", "fake value", "include JarJar"]
      @provider.process_match(command).should == false
    end

    it "should return true for includes match" do
      command = ["match", "fake value", "not_include JarJar"]
      @provider.process_match(command).should == true
    end

    it "should return false for includes non match" do
      command = ["match", "fake value", "not_include values"]
      @provider.process_match(command).should == false
    end

    it "should return true for an array match" do
      command = ["match", "fake value", "== ['set', 'of', 'values']"]
      @provider.process_match(command).should == true
    end

    it "should return false for an array non match" do
      command = ["match", "fake value", "== ['this', 'should', 'not', 'match']"]
      @provider.process_match(command).should == false
    end

    it "should return false for an array match with noteq" do
      command = ["match", "fake value", "!= ['set', 'of', 'values']"]
      @provider.process_match(command).should == false
    end

    it "should return true for an array non match with noteq" do
      command = ["match", "fake value", "!= ['this', 'should', 'not', 'match']"]
      @provider.process_match(command).should == true
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
      @provider.need_to_run?.should == true
    end

    it "should return true when a get filter matches" do
      @resource[:onlyif] = "get path == value"
      @augeas.stubs("get").returns("value")
      @provider.need_to_run?.should == true
    end

    it "should return false when a get filter does not match" do
      @resource[:onlyif] = "get path == another value"
      @augeas.stubs("get").returns("value")
      @provider.need_to_run?.should == false
    end

    it "should return true when a match filter matches" do
      @resource[:onlyif] = "match path size == 3"
      @augeas.stubs("match").returns(["set", "of", "values"])
      @provider.need_to_run?.should == true
    end

    it "should return false when a match filter does not match" do
      @resource[:onlyif] = "match path size == 2"
      @augeas.stubs("match").returns(["set", "of", "values"])
      @provider.need_to_run?.should == false
    end

    # Now setting force to true
    it "setting force should not change the above logic" do
      @resource[:force] = true
      @resource[:onlyif] = "match path size == 2"
      @augeas.stubs("match").returns(["set", "of", "values"])
      @provider.need_to_run?.should == false
    end

    #Ticket 5211 testing
    it "should return true when a size != the provided value" do
      @resource[:onlyif] = "match path size != 17"
      @augeas.stubs("match").returns(["set", "of", "values"])
      @provider.need_to_run?.should == true
    end

    #Ticket 5211 testing
    it "should return false when a size doeas equal the provided value" do
      @resource[:onlyif] = "match path size != 3"
      @augeas.stubs("match").returns(["set", "of", "values"])
      @provider.need_to_run?.should == false
    end

    # Ticket 2728 (diff files)
    describe "and Puppet[:show_diff] is set" do
      before(:each) do
        Puppet[:show_diff] = true

        @resource[:root] = ""
        @provider.stubs(:get_augeas_version).returns("0.10.0")
        @augeas.stubs(:set).returns(true)
        @augeas.stubs(:save).returns(true)
      end

      it "should call diff when a file is shown to have been changed" do
        file = "/etc/hosts"
        File.stubs(:delete)

        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file}/foo bar"]

        @augeas.stubs(:match).with("/augeas/events/saved").returns(["/augeas/events/saved"])
        @augeas.stubs(:get).with("/augeas/events/saved").returns("/files#{file}")
        @augeas.expects(:set).with("/augeas/save", "newfile")
        @augeas.expects(:close).never()

        @provider.expects("diff").with("#{file}", "#{file}.augnew").returns("")
        @provider.should be_need_to_run
      end

      it "should call diff for each file thats changed" do
        file1 = "/etc/hosts"
        file2 = "/etc/resolv.conf"
        File.stubs(:delete)

        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file1}/foo bar", "set #{file2}/baz biz"]

        @augeas.stubs(:match).with("/augeas/events/saved").returns(["/augeas/events/saved[1]", "/augeas/events/saved[2]"])
        @augeas.stubs(:get).with("/augeas/events/saved[1]").returns("/files#{file1}")
        @augeas.stubs(:get).with("/augeas/events/saved[2]").returns("/files#{file2}")
        @augeas.expects(:set).with("/augeas/save", "newfile")
        @augeas.expects(:close).never()

        @provider.expects(:diff).with("#{file1}", "#{file1}.augnew").returns("")
        @provider.expects(:diff).with("#{file2}", "#{file2}.augnew").returns("")
        @provider.should be_need_to_run
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
          @augeas.expects(:close).never()

          @provider.expects(:diff).with("#{root}#{file}", "#{root}#{file}.augnew").returns("")
          @provider.should be_need_to_run
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
        @provider.should_not be_need_to_run
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
        @provider.should be_need_to_run
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
        @provider.should be_need_to_run
      end

      it "should fail with an error if saving fails" do
        file = "/etc/hosts"

        @resource[:context] = "/files"
        @resource[:changes] = ["set #{file}/foo bar"]

        @augeas.stubs(:save).returns(false)
        @augeas.stubs(:match).with("/augeas/events/saved").returns([])
        @augeas.expects(:close)

        @provider.expects(:diff).never()
        lambda { @provider.need_to_run? }.should raise_error
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
      @provider.execute_changes.should == :executed
    end

    it "should handle rm commands" do
      @resource[:changes] = "rm /Jar/Jar"
      @augeas.expects(:rm).with("/Jar/Jar")
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle remove commands" do
      @resource[:changes] = "remove /Jar/Jar"
      @augeas.expects(:rm).with("/Jar/Jar")
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle clear commands" do
      @resource[:changes] = "clear Jar/Jar"
      @resource[:context] = "/foo/"
      @augeas.expects(:clear).with("/foo/Jar/Jar").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle ins commands with before" do
      @resource[:changes] = "ins Binks before Jar/Jar"
      @resource[:context] = "/foo"
      @augeas.expects(:insert).with("/foo/Jar/Jar", "Binks", true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle ins commands with after" do
      @resource[:changes] = "ins Binks after /Jar/Jar"
      @resource[:context] = "/foo"
      @augeas.expects(:insert).with("/Jar/Jar", "Binks", false)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle ins with no context" do
      @resource[:changes] = "ins Binks after /Jar/Jar"
      @augeas.expects(:insert).with("/Jar/Jar", "Binks", false)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle multiple commands" do
      @resource[:changes] = ["ins Binks after /Jar/Jar", "clear Jar/Jar"]
      @resource[:context] = "/foo/"
      @augeas.expects(:insert).with("/Jar/Jar", "Binks", false)
      @augeas.expects(:clear).with("/foo/Jar/Jar").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle defvar commands" do
      @resource[:changes] = "defvar myjar Jar/Jar"
      @resource[:context] = "/foo/"
      @augeas.expects(:defvar).with("myjar", "/foo/Jar/Jar").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should pass through augeas variables without context" do
      @resource[:changes] = ["defvar myjar Jar/Jar","set $myjar/Binks 1"]
      @resource[:context] = "/foo/"
      @augeas.expects(:defvar).with("myjar", "/foo/Jar/Jar").returns(true)
      # this is the important bit, shouldn't be /foo/$myjar/Binks
      @augeas.expects(:set).with("$myjar/Binks", "1").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle defnode commands" do
      @resource[:changes] = "defnode newjar Jar/Jar[last()+1] Binks"
      @resource[:context] = "/foo/"
      @augeas.expects(:defnode).with("newjar", "/foo/Jar/Jar[last()+1]", "Binks").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle mv commands" do
      @resource[:changes] = "mv Jar/Jar Binks"
      @resource[:context] = "/foo/"
      @augeas.expects(:mv).with("/foo/Jar/Jar", "/foo/Binks").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end

    it "should handle setm commands" do
      @resource[:changes] = ["set test[1]/Jar/Jar Foo","set test[2]/Jar/Jar Bar","setm test Jar/Jar Binks"]
      @resource[:context] = "/foo/"
      @augeas.expects(:set).with("/foo/test[1]/Jar/Jar", "Foo").returns(true)
      @augeas.expects(:set).with("/foo/test[2]/Jar/Jar", "Bar").returns(true)
      @augeas.expects(:setm).with("/foo/test", "Jar/Jar", "Binks").returns(true)
      @augeas.expects(:save).returns(true)
      @augeas.expects(:close)
      @provider.execute_changes.should == :executed
    end
  end

  describe "when making changes", :if => Puppet.features.augeas? do
    include PuppetSpec::Files

    it "should not clobber the file if it's a symlink" do
      Puppet::Util::Storage.stubs(:store)

      link = tmpfile('link')
      target = tmpfile('target')
      FileUtils.touch(target)
      FileUtils.symlink(target, link)

      resource = Puppet::Type.type(:augeas).new(
        :name => 'test',
        :incl => link,
        :lens => 'Sshd.lns',
        :changes => "set PermitRootLogin no"
      )

      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource resource

      catalog.apply

      File.ftype(link).should == 'link'
      File.readlink(link).should == target
      File.read(target).should =~ /PermitRootLogin no/
    end
  end
end
