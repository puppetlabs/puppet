# encoding: UTF-8
shared_examples_for "documentation on faces" do
  defined?(Attrs) or
    Attrs = [:summary, :description, :examples, :short_description, :notes, :author]

  defined?(SingleLineAttrs) or
    SingleLineAttrs = [:summary, :author]

  # Simple, procedural tests that apply to a bunch of methods.
  Attrs.each do |attr|
    it "should accept a #{attr}" do
      expect { subject.send("#{attr}=", "hello") }.not_to raise_error
      expect(subject.send(attr)).to eq("hello")
    end

    it "should accept a long (single line) value for #{attr}" do
      text = "I never know when to stop with the word banana" + ("na" * 1000)
      expect { subject.send("#{attr}=", text) }.to_not raise_error
      expect(subject.send(attr)).to eq(text)
    end
  end

  Attrs.each do |getter|
    setter = "#{getter}=".to_sym
    context "#{getter}" do
      it "should strip leading whitespace on a single line" do
        subject.send(setter, "  death to whitespace")
        expect(subject.send(getter)).to eq("death to whitespace")
      end

      it "should strip trailing whitespace on a single line" do
        subject.send(setter, "death to whitespace  ")
        expect(subject.send(getter)).to eq("death to whitespace")
      end

      it "should strip whitespace at both ends at once" do
        subject.send(setter, "  death to whitespace  ")
        expect(subject.send(getter)).to eq("death to whitespace")
      end

      multiline_text = "with\nnewlines"
      if SingleLineAttrs.include? getter then
        it "should not accept multiline values" do
          expect { subject.send(setter, multiline_text) }.
            to raise_error ArgumentError, /#{getter} should be a single line/
          expect(subject.send(getter)).to be_nil
        end
      else
        it "should accept multiline values" do
          expect { subject.send(setter, multiline_text) }.not_to raise_error
          expect(subject.send(getter)).to eq(multiline_text)
        end

        [1, 2, 4, 7, 25].each do |length|
          context "#{length} chars indent" do
            indent = ' ' * length

            it "should strip leading whitespace on multiple lines" do
              text = "this\nis\the\final\outcome"
              subject.send(setter, text.gsub(/^/, indent))
              expect(subject.send(getter)).to eq(text)
            end

            it "should not remove formatting whitespace, only global indent" do
              text = "this\n  is\n    the\n  ultimate\ntest"
              subject.send(setter, text.gsub(/^/, indent))
              expect(subject.send(getter)).to eq(text)
            end
          end
        end

        it "should strip whitespace with a blank line" do
          subject.send(setter, "  this\n\n  should outdent")
          expect(subject.send(getter)).to eq("this\n\nshould outdent")
        end
      end
    end
  end

  describe "#short_description" do
    it "should return the set value if set after description" do
      subject.description = "hello\ngoodbye"
      subject.short_description = "whatever"
      expect(subject.short_description).to eq("whatever")
    end

    it "should return the set value if set before description" do
      subject.short_description = "whatever"
      subject.description = "hello\ngoodbye"
      expect(subject.short_description).to eq("whatever")
    end

    it "should return nothing if not set and no description" do
      expect(subject.short_description).to be_nil
    end

    it "should return the first paragraph of description if not set (where it is one line long)" do
      subject.description = "hello"
      expect(subject.short_description).to eq(subject.description)
    end

    it "should return the first paragraph of description if not set (where there is no paragraph break)" do
      subject.description = "hello\ngoodbye"
      expect(subject.short_description).to eq(subject.description)
    end

    it "should return the first paragraph of description if not set (where there is a paragraph break)" do
      subject.description = "hello\ngoodbye\n\nmore\ntext\nhere\n\nfinal\nparagraph"
      expect(subject.short_description).to eq("hello\ngoodbye")
    end

    it "should trim a very, very long first paragraph and add ellipsis" do
      line = "this is a very, very, very long long line full of text\n"
      subject.description = line * 20 + "\n\nwhatever, dude."

      expect(subject.short_description).to eq((line * 5).chomp + ' [...]')
    end

    it "should trim a very very long only paragraph even if it is followed by a new paragraph" do
      line = "this is a very, very, very long long line full of text\n"
      subject.description = line * 20

      expect(subject.short_description).to eq((line * 5).chomp + ' [...]')
    end
  end

  describe "multiple authors" do
    authors = %w{John Paul George Ringo}

    context "in the DSL" do
      it "should support multiple authors" do

        authors.each {|name| subject.author name }
        expect(subject.authors).to match_array(authors)

        expect(subject.author).to eq(authors.join("\n"))
      end

      it "should reject author as an array" do
        expect { subject.author ["Foo", "Bar"] }.
          to raise_error ArgumentError, /author must be a string/
      end
    end

    context "#author=" do
      it "should accept a single name" do
        subject.author = "Fred"
        expect(subject.author).to eq("Fred")
      end

      it "should accept an array of names" do
        subject.author = authors
        expect(subject.authors).to match_array(authors)
        expect(subject.author).to eq(authors.join("\n"))
      end

      it "should not append when set multiple times" do
        subject.author = "Fred"
        subject.author = "John"
        expect(subject.author).to eq("John")
      end

      it "should reject arrays with embedded newlines" do
        expect { subject.author = ["Fred\nJohn"] }.
          to raise_error ArgumentError, /author should be a single line/
      end
    end
  end

  describe "#license" do
    it "should default to reserving rights" do
      expect(subject.license).to match(/All Rights Reserved/)
    end

    it "should accept an arbitrary license string on the object" do
      subject.license = "foo"
      expect(subject.license).to eq("foo")
    end

    it "should accept symbols to specify existing licenses..."
  end

  describe "#copyright" do
    it "should fail with just a name" do
      expect { subject.copyright("invalid") }.
        to raise_error ArgumentError, /copyright takes the owners names, then the years covered/
    end

    [1997, "1997"].each do |year|
      it "should accept an entity name and a #{year.class.name} year" do
        subject.copyright("me", year)
        expect(subject.copyright).to match(/\bme\b/)
        expect(subject.copyright).to match(/#{year}/)
      end

      it "should accept multiple entity names and a #{year.class.name} year" do
        subject.copyright ["me", "you"], year
        expect(subject.copyright).to match(/\bme\b/)
        expect(subject.copyright).to match(/\byou\b/)
        expect(subject.copyright).to match(/#{year}/)
      end
    end

    ["1997-2003", "1997 - 2003", 1997..2003].each do |range|
      it "should accept a #{range.class.name} range of years" do
        subject.copyright("me", range)
        expect(subject.copyright).to match(/\bme\b/)
        expect(subject.copyright).to match(/1997-2003/)
      end

      it "should accept a #{range.class.name} range of years" do
        subject.copyright ["me", "you"], range
        expect(subject.copyright).to match(/\bme\b/)
        expect(subject.copyright).to match(/\byou\b/)
        expect(subject.copyright).to match(/1997-2003/)
      end
    end

    [[1997, 2003], ["1997", 2003], ["1997", "2003"]].each do |input|
      it "should accept the set of years #{input.inspect} in an array" do
        subject.copyright "me", input
        expect(subject.copyright).to match(/\bme\b/)
        expect(subject.copyright).to match(/1997, 2003/)
      end

      it "should accept the set of years #{input.inspect} in an array" do
        subject.copyright ["me", "you"], input
        expect(subject.copyright).to match(/\bme\b/)
        expect(subject.copyright).to match(/\byou\b/)
        expect(subject.copyright).to match(/1997, 2003/)
      end
    end

    it "should warn if someone does math accidentally on the range of years" do
      expect { subject.copyright "me", 1997-2003 }.
        to raise_error ArgumentError, /copyright with a year before 1970 is very strange; did you accidentally add or subtract two years\?/
    end

    it "should accept complex copyright years" do
      years = [1997, 1999, 2000..2002, 2005].reverse
      subject.copyright "me", years
      expect(subject.copyright).to match(/\bme\b/)
      expect(subject.copyright).to match(/1997, 1999, 2000-2002, 2005/)
    end
  end

  # Things that are automatically generated.
  [:name, :options, :synopsis].each do |attr|
    describe "##{attr}" do
      it "should not allow you to set #{attr}" do
        expect(subject).not_to respond_to :"#{attr}="
      end

      it "should have a #{attr}" do
        expect(subject.send(attr)).not_to be_nil
      end

      it "'s #{attr} should not be empty..." do
        expect(subject.send(attr)).not_to eq('')
      end
    end
  end
end
