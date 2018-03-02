require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/face'

describe Puppet::Face[:epp, :current] do
  include PuppetSpec::Files

  let(:eppface) { Puppet::Face[:epp, :current] }

  context "validate" do
    context "from an interactive terminal" do
      before :each do
        from_an_interactive_terminal
      end

      it "validates the template referenced as an absolute file" do
        template_name = 'template1.epp'
        dir = dir_containing('templates', { template_name => "<%= |$a $b |%>" })
        template = File.join(dir, template_name)
        expect { eppface.validate(template) }.to raise_exception(Puppet::Error, /Errors while validating epp/)
      end

      it "runs error free when there are no validation errors from an absolute file" do
        template_name = 'template1.epp'
        dir = dir_containing('templates', { template_name => "just text" })
        template = File.join(dir, template_name)
        expect { eppface.validate(template) }.to_not raise_exception()
      end

      it "reports missing files" do
        expect do
          eppface.validate("missing.epp")
        end.to raise_error(Puppet::Error, /One or more file\(s\) specified did not exist.*missing\.epp/m)
      end

      context "in an environment with templates" do
        let(:dir) do
          dir_containing('environments', { 'production' => { 'modules' => {
            'm1' => { 'templates' => {
              'greetings.epp' => "<% |$subject = world| %>hello <%= $subject -%>",
              'broken.epp'    => "<% | $a $b | %> I am broken",
              'broken2.epp'   => "<% | $a $b | %> I am broken too"
            }},
            'm2' => { 'templates' => {
              'goodbye.epp'   => "<% | $subject = world |%>goodbye <%= $subject -%>",
              'broken3.epp'   => "<% | $a $b | %> I am broken too"
            }}
          }}})

        end

        around(:each) do |example|
          Puppet.settings.initialize_global_settings
          loader = Puppet::Environments::Directories.new(dir, [])
          Puppet.override(:environments => loader) do
            example.run
          end
        end

        it "parses supplied template files in different modules of a directory environment" do
          expect(eppface.validate('m1/greetings.epp')).to be_nil
          expect(eppface.validate('m2/goodbye.epp')).to be_nil
        end

        it "finds errors in supplied template file in the context of a directory environment" do
          expect { eppface.validate('m1/broken.epp') }.to raise_exception(Puppet::Error, /Errors while validating epp/)
          expect(@logs.join).to match(/Syntax error at 'b'/)
        end

        it "stops on first error by default" do
          expect { eppface.validate('m1/broken.epp', 'm1/broken2.epp') }.to raise_exception(Puppet::Error, /Errors while validating epp/)
          expect(@logs.join).to match(/Syntax error at 'b'.*broken\.epp/)
          expect(@logs.join).to_not match(/Syntax error at 'b'.*broken2\.epp/)
        end

        it "continues after error when --continue_on_error is given" do
          expect { eppface.validate('m1/broken.epp', 'm1/broken2.epp', :continue_on_error => true) }.to raise_exception(Puppet::Error, /Errors while validating epp/)
          expect(@logs.join).to match(/Syntax error at 'b'.*broken\.epp/)
          expect(@logs.join).to match(/Syntax error at 'b'.*broken2\.epp/)
        end

        it "validates all templates in the environment" do
          pending "NOT IMPLEMENTED YET"
          expect { eppface.validate(:continue_on_error => true) }.to raise_exception(Puppet::Error, /Errors while validating epp/)
          expect(@logs.join).to match(/Syntax error at 'b'.*broken\.epp/)
          expect(@logs.join).to match(/Syntax error at 'b'.*broken2\.epp/)
          expect(@logs.join).to match(/Syntax error at 'b'.*broken3\.epp/)
        end
      end
    end

    it "validates the contents of STDIN when no files given and STDIN is not a tty" do
      from_a_piped_input_of("<% | $a $oh_no | %> I am broken")
      expect { eppface.validate() }.to raise_exception(Puppet::Error, /Errors while validating epp/)
      expect(@logs.join).to match(/Syntax error at 'oh_no'/)
    end

    it "validates error free contents of STDIN when no files given and STDIN is not a tty" do
      from_a_piped_input_of("look, just text")
      expect(eppface.validate()).to be_nil
    end
  end


  context "dump" do
    it "prints the AST of a template given with the -e option" do
      expect(eppface.dump({ :e => 'hello world' })).to eq("(lambda (epp (block\n  (render-s 'hello world')\n)))\n")
    end

    it "prints the AST of a template given as an absolute file" do
      template_name = 'template1.epp'
      dir = dir_containing('templates', { template_name => "hello world" })
      template = File.join(dir, template_name)
      expect(eppface.dump(template)).to eq("(lambda (epp (block\n  (render-s 'hello world')\n)))\n")
    end

    it "adds a header between dumps by default" do
      template_name1 = 'template1.epp'
      template_name2 = 'template2.epp'
      dir = dir_containing('templates', { template_name1 => "hello world", template_name2 => "hello again"} )
      template1 = File.join(dir, template_name1)
      template2 = File.join(dir, template_name2)

      # Do not move the text block, the left margin and indentation matters
      expect(eppface.dump(template1, template2)).to eq( <<-"EOT" )
--- #{template1}
(lambda (epp (block
  (render-s 'hello world')
)))
--- #{template2}
(lambda (epp (block
  (render-s 'hello again')
)))
      EOT
    end

    it "dumps non validated content when given --no-validate" do
      template_name = 'template1.epp'
      dir = dir_containing('templates', { template_name => "<% 1 2 3 %>" })
      template = File.join(dir, template_name)
      expect(eppface.dump(template, :validate => false)).to eq("(lambda (epp (block\n  1\n  2\n  3\n)))\n")
    end

    it "validated content when given --validate" do
      template_name = 'template1.epp'
      dir = dir_containing('templates', { template_name => "<% 1 2 3 %>" })
      template = File.join(dir, template_name)
      expect(eppface.dump(template, :validate => true)).to eq("")
      expect(@logs.join).to match(/This Literal Integer has no effect.*\(file: .*\/template1\.epp, line: 1, column: 4\)/)
    end

    it "validated content by default" do
      template_name = 'template1.epp'
      dir = dir_containing('templates', { template_name => "<% 1 2 3 %>" })
      template = File.join(dir, template_name)
      expect(eppface.dump(template)).to eq("")
      expect(@logs.join).to match(/This Literal Integer has no effect.*\(file: .*\/template1\.epp, line: 1, column: 4\)/)
    end

    it "informs the user of files that don't exist" do
      expected_message = /One or more file\(s\) specified did not exist:\n\s*does_not_exist_here\.epp/m
      expect { eppface.dump('does_not_exist_here.epp') }.to raise_exception(Puppet::Error, expected_message)
    end

    it "dumps the AST of STDIN when no files given and STDIN is not a tty" do
      from_a_piped_input_of("hello world")
      expect(eppface.dump()).to eq("(lambda (epp (block\n  (render-s 'hello world')\n)))\n")
    end

    it "logs an error if the input cannot be parsed even if validation is off" do
      from_a_piped_input_of("<% |$a  $b| %> oh no")
      expect(eppface.dump(:validate => false)).to eq("")
      expect(@logs[0].message).to match(/Syntax error at 'b'/)
      expect(@logs[0].level).to eq(:err)
    end

    context "using 'pn' format" do
      it "prints the AST of the given expression in PN format" do
        expect(eppface.dump({ :format => 'pn', :e => 'hello world' })).to eq(
          '(lambda {:body [(epp (render-s "hello world"))]})')
      end

      it "pretty prints the AST of the given expression in PN format when --pretty is given" do
        expect(eppface.dump({ :pretty => true, :format => 'pn', :e => 'hello world' })).to eq(<<-RESULT.unindent[0..-2])
        (lambda
          {
            :body [
              (epp
                (render-s
                  "hello world"))]})
        RESULT
      end
    end

    context "using 'json' format" do
      it "prints the AST of the given expression in JSON based on the PN format" do
        expect(eppface.dump({ :format => 'json', :e => 'hello world' })).to eq(
          '{"^":["lambda",{"#":["body",[{"^":["epp",{"^":["render-s","hello world"]}]}]]}]}')
      end

      it "pretty prints the AST of the given expression in JSON based on the PN format when --pretty is given" do
        expect(eppface.dump({ :pretty => true, :format => 'json', :e => 'hello world' })).to eq(<<-RESULT.unindent[0..-2])
        {
          "^": [
            "lambda",
            {
              "#": [
                "body",
                [
                  {
                    "^": [
                      "epp",
                      {
                        "^": [
                          "render-s",
                          "hello world"
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

  context "render" do
    it "renders input from stdin" do
      from_a_piped_input_of("hello world")
      expect(eppface.render()).to eq("hello world")
    end

    it "renders input from command line" do
      expect(eppface.render(:e => 'hello world')).to eq("hello world")
    end

    it "renders input from an absolute file" do
      template_name = 'template1.epp'
      dir = dir_containing('templates', { template_name => "absolute world" })
      template = File.join(dir, template_name)
      expect(eppface.render(template)).to eq("absolute world")
    end

    it "renders expressions" do
      expect(eppface.render(:e => '<% $x = "mr X"%>hello <%= $x %>')).to eq("hello mr X")
    end

    it "adds values given in a puppet hash given on command line with --values" do
      expect(eppface.render(:e => 'hello <%= $x %>', :values => '{x => "mr X"}')).to eq("hello mr X")
    end

    it "adds fully qualified values given in a puppet hash given on command line with --values" do
      expect(eppface.render(:e => 'hello <%= $mr::x %>', :values => '{mr::x => "mr X"}')).to eq("hello mr X")
    end

    it "adds fully qualified values with leading :: given in a puppet hash given on command line with --values" do
      expect(eppface.render(:e => 'hello <%= $::mr %>', :values => '{"::mr" => "mr X"}')).to eq("hello mr X")
    end

    it "adds values given in a puppet hash produced by a .pp file given with --values_file" do
      file_name = 'values.pp'
      dir = dir_containing('values', { file_name => '{x => "mr X"}' })
      values_file = File.join(dir, file_name)
      expect(eppface.render(:e => 'hello <%= $x %>', :values_file => values_file)).to eq("hello mr X")
    end

    it "adds values given in a yaml hash given with --values_file" do
      file_name = 'values.yaml'
      dir = dir_containing('values', { file_name => "---\n x: 'mr X'" })
      values_file = File.join(dir, file_name)
      expect(eppface.render(:e => 'hello <%= $x %>', :values_file => values_file)).to eq("hello mr X")
    end

    it "merges values from values file and command line with command line having higher precedence" do
      file_name = 'values.yaml'
      dir = dir_containing('values', { file_name => "---\n x: 'mr X'\n word: 'goodbye'" })
      values_file = File.join(dir, file_name)
      expect(eppface.render(:e => '<%= $word %> <%= $x %>',
        :values_file => values_file,
        :values => '{x => "mr Y"}')
        ).to eq("goodbye mr Y")
    end

    it "sets $facts" do
      expect(eppface.render({ :e => 'facts is hash: <%= $facts =~ Hash %>' })).to eql("facts is hash: true")
    end

    it "sets $trusted" do
      expect(eppface.render({ :e => 'trusted is hash: <%= $trusted =~ Hash %>' })).to eql("trusted is hash: true")
    end

    it 'initializes the 4x loader' do
      expect(eppface.render({ :e => <<-EPP.unindent })).to eql("\nString\n\nInteger\n\nBoolean\n")
        <% $data = [type('a',generalized), type(2,generalized), type(true,generalized)] -%>
        <% $data.each |$value| { %>
        <%= $value %>
        <% } -%>
      EPP
    end

    it "facts can be added to" do
      expect(eppface.render({
        :facts => {'the_crux' => 'biscuit'},
        :e     => '<%= $facts[the_crux] %>', 
      })).to eql("biscuit")
    end

    it "facts can be overridden" do
      expect(eppface.render({
        :facts => {'operatingsystem' => 'Merwin'},
        :e     => '<%= $facts[operatingsystem] %>', 
      })).to eql("Merwin")
    end

    context "in an environment with templates" do
      let(:dir) do
        dir_containing('environments', { 'production' => { 'modules' => {
          'm1' => { 'templates' => {
            'greetings.epp' => "<% |$subject = world| %>hello <%= $subject -%>",
            'factshash.epp' => "fact = <%= $facts[the_fact] -%>",
            'fact.epp'      => "fact = <%= $the_fact -%>",
          }},
          'm2' => { 'templates' => {
            'goodbye.epp'   => "<% | $subject = world |%>goodbye <%= $subject -%>",
          }}
        },
          'extra' => {
            'facts.yaml' => "---\n the_fact: 42"
          }
        }})

      end

      around(:each) do |example|
        Puppet.settings.initialize_global_settings
        loader = Puppet::Environments::Directories.new(dir, [])
        Puppet.override(:environments => loader) do
          example.run
        end
      end

      it "renders supplied template files in different modules of a directory environment" do
        expect(eppface.render('m1/greetings.epp')).to eq("hello world")
        expect(eppface.render('m2/goodbye.epp')).to eq("goodbye world")
      end

      it "makes facts available in $facts" do
        facts_file = File.join(dir, 'production', 'extra', 'facts.yaml')
        expect(eppface.render('m1/factshash.epp', :facts => facts_file)).to eq("fact = 42")
      end

      it "makes facts available individually" do
        facts_file = File.join(dir, 'production', 'extra', 'facts.yaml')
        expect(eppface.render('m1/fact.epp', :facts => facts_file)).to eq("fact = 42")
      end

      it "renders multiple files separated by headers by default" do
        # chomp the last newline, it is put there by heredoc
        expect(eppface.render('m1/greetings.epp', 'm2/goodbye.epp')).to eq(<<-EOT.chomp)
--- m1/greetings.epp
hello world
--- m2/goodbye.epp
goodbye world
        EOT
      end

      it "outputs multiple files verbatim when --no-headers is given" do
        expect(eppface.render('m1/greetings.epp', 'm2/goodbye.epp', :header => false)).to eq("hello worldgoodbye world")
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
