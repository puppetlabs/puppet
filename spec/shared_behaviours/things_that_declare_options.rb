# encoding: UTF-8
shared_examples_for "things that declare options" do
  it "should support options without arguments" do
    thing = add_options_to { option "--bar" }
    expect(thing).to be_option :bar
  end

  it "should support options with an empty block" do
    thing = add_options_to do
      option "--foo" do
        # this section deliberately left blank
      end
    end
    expect(thing).to be
    expect(thing).to be_option :foo
  end

  { "--foo=" => :foo }.each do |input, option|
    it "should accept #{name.inspect}" do
      thing = add_options_to { option input }
      expect(thing).to be_option option
    end
  end

  it "should support option documentation" do
    text = "Sturm und Drang (German pronunciation: [ˈʃtʊʁm ʊnt ˈdʁaŋ]) …"

    thing = add_options_to do
      option "--foo" do
        description text
        summary text
      end
    end

    expect(thing.get_option(:foo).description).to eq(text)
  end

  it "should list all the options" do
    thing = add_options_to do
      option "--foo"
      option "--bar", '-b'
      option "-q", "--quux"
      option "-f"
      option "--baz"
    end
    expect(thing.options).to eq([:foo, :bar, :quux, :f, :baz])
  end

  it "should detect conflicts in long options" do
    expect {
      add_options_to do
        option "--foo"
        option "--foo"
      end
    }.to raise_error ArgumentError, /Option foo conflicts with existing option foo/i
  end

  it "should detect conflicts in short options" do
    expect {
      add_options_to do
        option "-f"
        option "-f"
      end
    }.to raise_error ArgumentError, /Option f conflicts with existing option f/
  end

  ["-f", "--foo"].each do |option|
    ["", " FOO", "=FOO", " [FOO]", "=[FOO]"].each do |argument|
      input = option + argument
      it "should detect conflicts within a single option like #{input.inspect}" do
        expect {
          add_options_to do
            option input, input
          end
        }.to raise_error ArgumentError, /duplicates existing alias/
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
      }.to raise_error ArgumentError, /conflicts with existing option/
    end
  end

  it "should fail if we are not consistent about taking an argument" do
    expect { add_options_to do option "--foo=bar", "--bar" end }.
      to raise_error ArgumentError, /inconsistent about taking an argument/
  end

  it "should not accept optional arguments" do
    expect do
      thing = add_options_to do option "--foo=[baz]", "--bar=[baz]" end
      [:foo, :bar].each do |name|
        expect(thing).to be_option name
      end
    end.to raise_error(ArgumentError, /optional arguments are not supported/)
  end

  describe "#takes_argument?" do
    it "should detect an argument being absent" do
      thing = add_options_to do option "--foo" end
      expect(thing.get_option(:foo)).not_to be_takes_argument
    end
    ["=FOO", " FOO"].each do |input|
      it "should detect an argument given #{input.inspect}" do
        thing = add_options_to do option "--foo#{input}" end
        expect(thing.get_option(:foo)).to be_takes_argument
      end
    end
  end

  describe "#optional_argument?" do
    it "should be false if no argument is present" do
      option = add_options_to do option "--foo" end.get_option(:foo)
      expect(option).not_to be_takes_argument
      expect(option).not_to be_optional_argument
    end

    ["=FOO", " FOO"].each do |input|
      it "should be false if the argument is mandatory (like #{input.inspect})" do
        option = add_options_to do option "--foo#{input}" end.get_option(:foo)
      expect(option).to be_takes_argument
      expect(option).not_to be_optional_argument
      end
    end

    ["=[FOO]", " [FOO]"].each do |input|
      it "should fail if the argument is optional (like #{input.inspect})" do
        expect do
          option = add_options_to do option "--foo#{input}" end.get_option(:foo)
          expect(option).to be_takes_argument
          expect(option).to be_optional_argument
        end.to raise_error(ArgumentError, /optional arguments are not supported/)
      end
    end
  end

  describe "#default_to" do
    it "should not have a default value by default" do
      option = add_options_to do option "--foo" end.get_option(:foo)
      expect(option).not_to be_has_default
    end

    it "should accept a block for the default value" do
      option = add_options_to do
        option "--foo" do
          default_to do
            12
          end
        end
      end.get_option(:foo)

      expect(option).to be_has_default
    end

    it "should invoke the block when asked for the default value" do
      invoked = false
      option = add_options_to do
        option "--foo" do
          default_to do
            invoked = true
          end
        end
      end.get_option(:foo)

      expect(option).to be_has_default
      expect(option.default).to be_truthy
      expect(invoked).to be_truthy
    end

    it "should return the value of the block when asked for the default" do
      option = add_options_to do
        option "--foo" do
          default_to do
            12
          end
        end
      end.get_option(:foo)

      expect(option).to be_has_default
      expect(option.default).to eq(12)
    end

    it "should invoke the block every time the default is requested" do
      option = add_options_to do
        option "--foo" do
          default_to do
            {}
          end
        end
      end.get_option(:foo)

      first  = option.default.object_id
      second = option.default.object_id
      third  = option.default.object_id

      expect(first).not_to eq(second)
      expect(first).not_to eq(third)
      expect(second).not_to eq(third)
    end

    it "should fail if the option has a default and is required" do
      expect {
        add_options_to do
          option "--foo" do
            required
            default_to do 12 end
          end
        end
      }.to raise_error ArgumentError, /can't be optional and have a default value/

      expect {
        add_options_to do
          option "--foo" do
            default_to do 12 end
            required
          end
        end
      }.to raise_error ArgumentError, /can't be optional and have a default value/
    end

    it "should fail if default_to has no block" do
      expect { add_options_to do option "--foo" do default_to end end }.
        to raise_error ArgumentError, /default_to requires a block/
    end

    it "should fail if default_to is invoked twice" do
      expect {
        add_options_to do
          option "--foo" do
            default_to do 12 end
            default_to do "fun" end
          end
        end
      }.to raise_error ArgumentError, /already has a default value/
    end

    [ "one", "one, two", "one, *two" ].each do |input|
      it "should fail if the block has the wrong arity (#{input})" do
        expect {
          add_options_to do
            option "--foo" do
              eval "default_to do |#{input}| 12 end"
            end
          end
        }.to raise_error ArgumentError, /should not take any arguments/
      end
    end
  end
end
