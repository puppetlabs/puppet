require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/face'
require 'puppet/application/parser'

describe Puppet::Face[:parser, :current] do
  include PuppetSpec::Files

  let(:parser) { Puppet::Face[:parser, :current] }

  context "validate" do
    let(:validate_app) do
      Puppet::Application::Parser.new.tap do |app|
        allow(app).to receive(:action).and_return(parser.get_action(:validate))
      end
    end

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
          parse_errors = parser.validate()

          expect(parse_errors[manifest]).to be_a_kind_of(Puppet::ParseErrorWithIssue)
        end
      end

      it "validates the given file" do
        manifest = file_containing('site.pp', "{ invalid =>")
        parse_errors = parser.validate(manifest)

        expect(parse_errors[manifest]).to be_a_kind_of(Puppet::ParseErrorWithIssue)
      end

      it "validates static heredoc with specified syntax" do
        manifest = file_containing('site.pp', "@(EOT:pp)
          { invalid =>
          EOT
        ")
        parse_errors = parser.validate(manifest)

        expect(parse_errors[manifest]).to be_a_kind_of(Puppet::ParseErrorWithIssue)
      end

      it "does not validates dynamic heredoc with specified syntax" do
        manifest = file_containing('site.pp', "@(\"EOT\":pp)
        {invalid => ${1+1}
        EOT")
        parse_errors = parser.validate(manifest)

        expect(parse_errors).to be_empty
      end

      it "runs error free when there are no validation errors" do
        manifest = file_containing('site.pp', "notify { valid: }")
        parse_errors = parser.validate(manifest)

        expect(parse_errors).to be_empty
      end

      it "runs error free when there is a puppet function in manifest being validated" do
        manifest = file_containing('site.pp', "function valid() { 'valid' } notify{ valid(): }")
        parse_errors = parser.validate(manifest)

        expect(parse_errors).to be_empty
      end

      it "runs error free when there is a type alias in a manifest that requires type resolution" do
        manifest = file_containing('site.pp',
                                   "type A = String; type B = Array[A]; function valid(B $x) { $x } notify{ valid([valid]): }")
        parse_errors = parser.validate(manifest)

        expect(parse_errors).to be_empty
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
          parse_errors = parser.validate(manifest)

          expect(parse_errors[manifest]).to be_a_kind_of(Puppet::ParseErrorWithIssue)
        end
      end
    end

    context "when no files given and STDIN is not a tty" do
      it "validates the contents of STDIN" do
        from_a_piped_input_of("{ invalid =>")

        Puppet.override(:current_environment => Puppet::Node::Environment.create(:special, [])) do
          parse_errors = parser.validate()

          expect(parse_errors['STDIN']).to be_a_kind_of(Puppet::ParseErrorWithIssue)
        end
      end

      it "runs error free when contents of STDIN is valid" do
        from_a_piped_input_of("notify { valid: }")

        Puppet.override(:current_environment => Puppet::Node::Environment.create(:special, [])) do
          parse_errors = parser.validate()

          expect(parse_errors).to be_empty
        end
      end
    end

    context "when invoked with console output renderer" do
      before(:each) do
        validate_app.render_as = :console
      end

      it "logs errors using Puppet.log_exception" do
        manifest = file_containing('test.pp', "{ invalid =>")
        results = parser.validate(manifest)

        results.each do |_, error|
          expect(Puppet).to receive(:log_exception).with(error)
        end

        expect { validate_app.render(results, nil) }.to raise_error(SystemExit)
      end
    end

    context "when invoked with --render-as=json" do
      before(:each) do
        validate_app.render_as = :json
      end

      it "outputs errors in a JSON document to stdout" do
        manifest = file_containing('test.pp', "{ invalid =>")
        results = parser.validate(manifest)

        expected_json = /\A{.*#{Regexp.escape('"message":')}\s*#{Regexp.escape('"Syntax error at end of input"')}.*}\Z/m

        expect { validate_app.render(results, nil) }.to output(expected_json).to_stdout.and raise_error(SystemExit)
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
    allow(STDIN).to receive(:tty?).and_return(true)
  end

  def from_a_piped_input_of(contents)
    allow(STDIN).to receive(:tty?).and_return(false)
    allow(STDIN).to receive(:read).and_return(contents)
  end
end
