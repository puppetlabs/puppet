# encoding: UTF-8
shared_examples_for "things that declare options" do
  it "should support options without arguments" do
    thing = add_options_to { option "--bar" }
    thing.should be_option :bar
  end

  it "should support options with an empty block" do
    thing = add_options_to do
      option "--foo" do
        # this section deliberately left blank
      end
    end
    thing.should be
    thing.should be_option :foo
  end

  { "--foo=" => :foo }.each do |input, option|
    it "should accept #{name.inspect}" do
      thing = add_options_to { option input }
      thing.should be_option option
    end
  end

  it "should support option documentation" do
    text = "Sturm und Drang (German pronunciation: [ˈʃtʊʁm ʊnt ˈdʁaŋ]) …"

    thing = add_options_to do
      option "--foo" do
        desc text
      end
    end

    thing.get_option(:foo).desc.should == text
  end

  it "should list all the options" do
    thing = add_options_to do
      option "--foo"
      option "--bar"
    end
    thing.options.should =~ [:foo, :bar]
  end

  it "should detect conflicts in long options" do
    expect {
      add_options_to do
        option "--foo"
        option "--foo"
      end
    }.should raise_error ArgumentError, /Option foo conflicts with existing option foo/i
  end

  it "should detect conflicts in short options" do
    expect {
      add_options_to do
        option "-f"
        option "-f"
      end
    }.should raise_error ArgumentError, /Option f conflicts with existing option f/
  end

  ["-f", "--foo"].each do |option|
    ["", " FOO", "=FOO", " [FOO]", "=[FOO]"].each do |argument|
      input = option + argument
      it "should detect conflicts within a single option like #{input.inspect}" do
        expect {
          add_options_to do
            option input, input
          end
        }.should raise_error ArgumentError, /duplicates existing alias/
      end
    end
  end


  # Verify the range of interesting conflicts to check for ordering causing
  # the behaviour to change, or anything exciting like that.
  [ %w{--foo}, %w{-f}, %w{-f --foo}, %w{--baz -f},
    %w{-f --baz}, %w{-b --foo}, %w{--foo -b}
  ].each do |conflict|
    base = %w{--foo -f}
    it "should detect conflicts between #{base.inspect} and #{conflict.inspect}" do
      expect {
        add_options_to do
          option *base
          option *conflict
        end
      }.should raise_error ArgumentError, /conflicts with existing option/
    end
  end

  it "should fail if we are not consistent about taking an argument" do
    expect { add_options_to do option "--foo=bar", "--bar" end }.
      should raise_error ArgumentError, /inconsistent about taking an argument/
  end

  it "should not accept optional arguments" do
    expect do
      thing = add_options_to do option "--foo=[baz]", "--bar=[baz]" end
      [:foo, :bar].each do |name|
        thing.should be_option name
      end
    end.to raise_error(ArgumentError, /optional arguments are not supported/)
  end

  describe "#takes_argument?" do
    it "should detect an argument being absent" do
      thing = add_options_to do option "--foo" end
      thing.get_option(:foo).should_not be_takes_argument
    end
    ["=FOO", " FOO"].each do |input|
      it "should detect an argument given #{input.inspect}" do
        thing = add_options_to do option "--foo#{input}" end
        thing.get_option(:foo).should be_takes_argument
      end
    end
  end

  describe "#optional_argument?" do
    it "should be false if no argument is present" do
      option = add_options_to do option "--foo" end.get_option(:foo)
      option.should_not be_takes_argument
      option.should_not be_optional_argument
    end

    ["=FOO", " FOO"].each do |input|
      it "should be false if the argument is mandatory (like #{input.inspect})" do
        option = add_options_to do option "--foo#{input}" end.get_option(:foo)
      option.should be_takes_argument
      option.should_not be_optional_argument
      end
    end

    ["=[FOO]", " [FOO]"].each do |input|
      it "should fail if the argument is optional (like #{input.inspect})" do
        expect do
          option = add_options_to do option "--foo#{input}" end.get_option(:foo)
          option.should be_takes_argument
          option.should be_optional_argument
        end.to raise_error(ArgumentError, /optional arguments are not supported/)
      end
    end
  end
end
