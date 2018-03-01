require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/face'

describe Puppet::Face[:parser, :current] do
  include PuppetSpec::Files

  let(:parser) { Puppet::Face[:parser, :current] }

  context "validate" do
    context "from an interactive terminal" do
      before :each do
        from_an_interactive_terminal
      end

      after(:each) do
        # Reset cache of loaders (many examples run in the *root* environment
        # which exists in "eternity")
        Puppet.lookup(:current_environment).loaders = nil
      end

      it "validates the configured site manifest when no files are given" do
        manifest = file_containing('site.pp', "{ invalid =>")

        configured_environment = Puppet::Node::Environment.create(:default, [], manifest)
        Puppet.override(:current_environment => configured_environment) do
          expect { parser.validate() }.to exit_with(1)
        end
      end

      it "validates the given file" do
        manifest = file_containing('site.pp', "{ invalid =>")

        expect { parser.validate(manifest) }.to exit_with(1)
      end

      it "runs error free when there are no validation errors" do
        expect {
            manifest = file_containing('site.pp', "notify { valid: }")
            parser.validate(manifest)
        }.to_not raise_error
      end

      it "runs error free when there is a puppet function in manifest being validated" do
        expect {
          manifest = file_containing('site.pp', "function valid() { 'valid' } notify{ valid(): }")
          parser.validate(manifest)
        }.to_not raise_error
      end

      it "runs error free when there is a type alias in a manifest that requires type resolution" do
        expect {
          manifest = file_containing('site.pp',
            "type A = String; type B = Array[A]; function valid(B $x) { $x } notify{ valid([valid]): }")
          parser.validate(manifest)
        }.to_not raise_error
      end

      it "reports missing files" do
        expect do
          parser.validate("missing.pp")
        end.to raise_error(Puppet::Error, /One or more file\(s\) specified did not exist.*missing\.pp/m)
      end

      it "parses supplied manifest files in the context of a directory environment" do
        manifest = file_containing('test.pp', "{ invalid =>")

        env = Puppet::Node::Environment.create(:special, [])
        env_loader = Puppet::Environments::Static.new(env)
        Puppet.override({:environments => env_loader, :current_environment => env}) do
          expect { parser.validate(manifest) }.to exit_with(1)
        end

        expect(@logs.join).to match(/environment special.*Syntax error at end of input/)
      end

    end

    it "validates the contents of STDIN when no files given and STDIN is not a tty" do
      from_a_piped_input_of("{ invalid =>")

      Puppet.override(:current_environment => Puppet::Node::Environment.create(:special, [])) do
        expect { parser.validate() }.to exit_with(1)
      end
    end
  end

  context "dump" do
    it "prints the AST of the passed expression" do
      expect(parser.dump({ :e => 'notice hi' })).to eq("(invoke notice hi)\n")
    end

    it "prints the AST of the code read from the passed files" do
      first_manifest = file_containing('site.pp', "notice hi")
      second_manifest = file_containing('site2.pp', "notice bye")

      output = parser.dump(first_manifest, second_manifest)

      expect(output).to match(/site\.pp.*\(invoke notice hi\)/)
      expect(output).to match(/site2\.pp.*\(invoke notice bye\)/)
    end

    it "informs the user of files that don't exist" do
      expect(parser.dump('does_not_exist_here.pp')).to match(/did not exist:\s*does_not_exist_here\.pp/m)
    end

    it "prints the AST of STDIN when no files given and STDIN is not a tty" do
      from_a_piped_input_of("notice hi")

      Puppet.override(:current_environment => Puppet::Node::Environment.create(:special, [])) do
        expect(parser.dump()).to eq("(invoke notice hi)\n")
      end
    end

    it "logs an error if the input cannot be parsed" do
      output = parser.dump({ :e => '{ invalid =>' })

      expect(output).to eq("")
      expect(@logs[0].message).to eq("Syntax error at end of input")
      expect(@logs[0].level).to eq(:err)
    end

    it "logs an error if the input begins with a UTF-8 BOM (Byte Order Mark)" do
      utf8_bom_manifest = file_containing('utf8_bom.pp', "\uFEFFnotice hi")

      output = parser.dump(utf8_bom_manifest)

      expect(output).to eq("")
      expect(@logs[1].message).to eq("Illegal UTF-8 Byte Order mark at beginning of input: [EF BB BF] - remove these from the puppet source")
      expect(@logs[1].level).to eq(:err)
    end

    it "runs error free when there is a puppet function in manifest being dumped" do
      expect {
        manifest = file_containing('site.pp', "function valid() { 'valid' } notify{ valid(): }")
        parser.dump(manifest)
      }.to_not raise_error
    end

    it "runs error free when there is a type alias in a manifest that requires type resolution" do
      expect {
        manifest = file_containing('site.pp',
          "type A = String; type B = Array[A]; function valid(B $x) { $x } notify{ valid([valid]): }")
        parser.dump(manifest)
      }.to_not raise_error
    end

    context "using 'pn' format" do
      it "prints the AST of the given expression in PN format" do
        expect(parser.dump({ :format => 'pn', :e => 'if $x { "hi ${x[2]}" }' })).to eq(
          '(if {:test (var "x") :then [(concat "hi " (str (access (var "x") 2)))]})')
      end

      it "pretty prints the AST of the given expression in PN format when --pretty is given" do
        expect(parser.dump({ :pretty => true, :format => 'pn', :e => 'if $x { "hi ${x[2]}" }' })).to eq(<<-RESULT.unindent[0..-2])
        (if
          {
            :test (var
              "x")
            :then [
              (concat
                "hi "
                (str
                  (access
                    (var
                      "x")
                    2)))]})
        RESULT
      end
    end

    context "using 'json' format" do
      it "prints the AST of the given expression in JSON based on the PN format" do
        expect(parser.dump({ :format => 'json', :e => 'if $x { "hi ${x[2]}" }' })).to eq(
          '{"^":["if",{"#":["test",{"^":["var","x"]},"then",[{"^":["concat","hi ",{"^":["str",{"^":["access",{"^":["var","x"]},2]}]}]}]]}]}')
      end

      it "pretty prints the AST of the given expression in JSON based on the PN format when --pretty is given" do
        expect(parser.dump({ :pretty => true, :format => 'json', :e => 'if $x { "hi ${x[2]}" }' })).to eq(<<-RESULT.unindent[0..-2])
        {
          "^": [
            "if",
            {
              "#": [
                "test",
                {
                  "^": [
                    "var",
                    "x"
                  ]
                },
                "then",
                [
                  {
                    "^": [
                      "concat",
                      "hi ",
                      {
                        "^": [
                          "str",
                          {
                            "^": [
                              "access",
                              {
                                "^": [
                                  "var",
                                  "x"
                                ]
                              },
                              2
                            ]
                          }
                        ]
                      }
                    ]
                  }
                ]
              ]
            }
          ]
        }
        RESULT
      end
    end
  end

  def from_an_interactive_terminal
    STDIN.stubs(:tty?).returns(true)
  end

  def from_a_piped_input_of(contents)
    STDIN.stubs(:tty?).returns(false)
    STDIN.stubs(:read).returns(contents)
  end
end
