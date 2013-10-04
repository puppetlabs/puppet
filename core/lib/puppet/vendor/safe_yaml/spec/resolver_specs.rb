module ResolverSpecs
  def self.included(base)
    base.module_eval do
      let(:resolver) { nil }
      let(:result) { @result }

      def parse(yaml)
        tree = YAML.parse(yaml.unindent)
        @result = resolver.resolve_node(tree)
      end

      # Isn't this how I should've been doing it all along?
      def parse_and_test(yaml)
        parse(yaml)
        @result.should == YAML.unsafe_load(yaml)
      end

      context "by default" do
        it "translates maps to hashes" do
          parse <<-YAML
            potayto: potahto
            tomayto: tomahto
          YAML

          result.should == {
            "potayto" => "potahto",
            "tomayto" => "tomahto"
          }
        end

        it "translates sequences to arrays" do
          parse <<-YAML
            - foo
            - bar
            - baz
          YAML

          result.should == ["foo", "bar", "baz"]
        end

        it "translates most values to strings" do
          parse "string: value"
          result.should == { "string" => "value" }
        end

        it "does not deserialize symbols" do
          parse ":symbol: value"
          result.should == { ":symbol" => "value" }
        end

        it "translates valid integral numbers to integers" do
          parse "integer: 1"
          result.should == { "integer" => 1 }
        end

        it "translates valid decimal numbers to floats" do
          parse "float: 3.14"
          result.should == { "float" => 3.14 }
        end

        it "translates valid dates" do
          parse "date: 2013-01-24"
          result.should == { "date" => Date.parse("2013-01-24") }
        end

        it "translates valid true/false values to booleans" do
          parse <<-YAML
            - yes
            - true
            - no
            - false
          YAML

          result.should == [true, true, false, false]
        end

        it "translates valid nulls to nil" do
          parse <<-YAML
            - 
            - ~
            - null
          YAML

          result.should == [nil] * 3
        end

        it "matches the behavior of the underlying YAML engine w/ respect to capitalization of boolean values" do
          parse_and_test <<-YAML
            - true
            - True
            - TRUE
            - tRue
            - TRue
            - False
            - FALSE
            - fAlse
            - FALse
          YAML

          # using Syck: [true, true, true, "tRue", "TRue", false, false, "fAlse", "FALse"]
          # using Psych: all booleans
        end

        it "matches the behavior of the underlying YAML engine w/ respect to capitalization of nil values" do
          parse_and_test <<-YAML
            - Null
            - NULL
            - nUll
            - NUll
          YAML

          # using Syck: [nil, nil, "nUll", "NUll"]
          # using Psych: all nils
        end

        it "translates quoted empty strings to strings (not nil)" do
          parse "foo: ''"
          result.should == { "foo" => "" }
        end

        it "correctly reverse-translates strings encoded via #to_yaml" do
          parse "5.10".to_yaml
          result.should == "5.10"
        end

        it "does not specially parse any double-quoted strings" do
          parse <<-YAML
            - "1"
            - "3.14"
            - "true"
            - "false"
            - "2013-02-03"
            - "2013-02-03 16:27:00 -0600"
          YAML

          result.should == ["1", "3.14", "true", "false", "2013-02-03", "2013-02-03 16:27:00 -0600"]
        end

        it "does not specially parse any single-quoted strings" do
          parse <<-YAML
            - '1'
            - '3.14'
            - 'true'
            - 'false'
            - '2013-02-03'
            - '2013-02-03 16:27:00 -0600'
          YAML

          result.should == ["1", "3.14", "true", "false", "2013-02-03", "2013-02-03 16:27:00 -0600"]
        end

        it "deals just fine with nested maps" do
          parse <<-YAML
            foo:
              bar:
                marco: polo
          YAML

          result.should == { "foo" => { "bar" => { "marco" => "polo" } } }
        end

        it "deals just fine with nested sequences" do
          parse <<-YAML
            - foo
            -
              - bar1
              - bar2
              -
                - baz1
                - baz2
          YAML

          result.should == ["foo", ["bar1", "bar2", ["baz1", "baz2"]]]
        end

        it "applies the same transformations to keys as to values" do
          parse <<-YAML
            foo: string
            :bar: symbol
            1: integer
            3.14: float
            2013-01-24: date
          YAML

          result.should == {
            "foo"  => "string",
            ":bar" => "symbol",
            1      => "integer",
            3.14   => "float",
            Date.parse("2013-01-24") => "date",
          }
        end

        it "applies the same transformations to elements in sequences as to all values" do
          parse <<-YAML
            - foo
            - :bar
            - 1
            - 3.14
            - 2013-01-24
          YAML

          result.should == ["foo", ":bar", 1, 3.14, Date.parse("2013-01-24")]
        end
      end

      context "for Ruby version #{RUBY_VERSION}" do
        it "translates valid time values" do
          parse "time: 2013-01-29 05:58:00 -0800"
          result.should == { "time" => Time.utc(2013, 1, 29, 13, 58, 0) }
        end

        it "applies the same transformation to elements in sequences" do
          parse "- 2013-01-29 05:58:00 -0800"
          result.should == [Time.utc(2013, 1, 29, 13, 58, 0)]
        end

        it "applies the same transformation to keys" do
          parse "2013-01-29 05:58:00 -0800: time"
          result.should == { Time.utc(2013, 1, 29, 13, 58, 0) => "time" }
        end
      end

      context "with symbol deserialization enabled" do
        before :each do
          SafeYAML::OPTIONS[:deserialize_symbols] = true
        end

        after :each do
          SafeYAML.restore_defaults!
        end

        it "translates values starting with ':' to symbols" do
          parse "symbol: :value"
          result.should == { "symbol" => :value }
        end

        it "applies the same transformation to keys" do
          parse ":bar: symbol"
          result.should == { :bar  => "symbol" }
        end

        it "applies the same transformation to elements in sequences" do
          parse "- :bar"
          result.should == [:bar]
        end
      end
    end
  end
end
