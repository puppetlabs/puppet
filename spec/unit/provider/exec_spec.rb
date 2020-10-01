require 'spec_helper'
require 'puppet/provider/exec'
require 'puppet_spec/compiler'
require 'puppet_spec/files'

describe Puppet::Provider::Exec do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  describe "#extractexe" do
    it "should return the first element of an array" do
      expect(subject.extractexe(['one', 'two'])).to eq('one')
    end

    {
      # double-quoted commands
      %q{"/has whitespace"}            => "/has whitespace",
      %q{"/no/whitespace"}             => "/no/whitespace",
      # singe-quoted commands
      %q{'/has whitespace'}            => "/has whitespace",
      %q{'/no/whitespace'}             => "/no/whitespace",
      # combinations
      %q{"'/has whitespace'"}          => "'/has whitespace'",
      %q{'"/has whitespace"'}          => '"/has whitespace"',
      %q{"/has 'special' characters"}  => "/has 'special' characters",
      %q{'/has "special" characters'}  => '/has "special" characters',
      # whitespace split commands
      %q{/has whitespace}              => "/has",
      %q{/no/whitespace}               => "/no/whitespace",
    }.each do |base_command, exe|
      ['', ' and args', ' "and args"', " 'and args'"].each do |args|
        command = base_command + args
        it "should extract #{exe.inspect} from #{command.inspect}" do
          expect(subject.extractexe(command)).to eq(exe)
        end
      end
    end
  end

  context "when handling sensitive data" do
    before :each do
      Puppet[:log_level] = 'debug'
    end

    let(:supersecret) { 'supersecret' }
    let(:path) do
      if Puppet::Util::Platform.windows?
        # The `apply_compiled_manifest` helper doesn't add the `path` fact, so
        # we can't reference that in our manifest. Windows PATHs can contain
        # double quotes and trailing backslashes, which confuse HEREDOC
        # interpolation below. So sanitize it:
        ENV['PATH'].split(File::PATH_SEPARATOR)
                   .map { |dir| dir.gsub(/"/, '\"').gsub(/\\$/, '') }
                   .map { |dir| Pathname.new(dir).cleanpath.to_s }
                   .join(File::PATH_SEPARATOR)
      else
        ENV['PATH']
      end
    end

    def ruby_exit_0
      "ruby -e 'exit 0'"
    end

    def echo_from_ruby_exit_0(message)
      # Escape double quotes due to HEREDOC interpolation below
      "ruby -e 'puts \"#{message}\"; exit 0'".gsub(/"/, '\"')
    end

    def echo_from_ruby_exit_1(message)
      # Escape double quotes due to HEREDOC interpolation below
      "ruby -e 'puts \"#{message}\"; exit 1'".gsub(/"/, '\"')
    end

    context "when validating the command" do
      it "redacts the arguments if the command is relative" do
        expect {
          apply_compiled_manifest(<<-MANIFEST)
            exec { 'echo':
              command => Sensitive.new('echo #{supersecret}')
            }
          MANIFEST
        }.to raise_error do |err|
          expect(err).to be_a(Puppet::Error)
          expect(err.message).to match(/'echo' is not qualified and no path was specified. Please qualify the command or specify a path./)
          expect(err.message).to_not match(/#{supersecret}/)
        end
      end

      it "redacts the arguments if the command is a directory" do
        dir = tmpdir('exec')
        apply_compiled_manifest(<<-MANIFEST)
          exec { 'echo':
            command => Sensitive.new('#{dir} #{supersecret}'),
          }
        MANIFEST
        expect(@logs).to include(an_object_having_attributes(level: :err, message: /'#{dir}' is a directory, not a file/))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{supersecret}/))
      end

      it "redacts the arguments if the command isn't executable" do
        file = tmpfile('exec')
        Puppet::FileSystem.touch(file)
        Puppet::FileSystem.chmod(0644, file)

        apply_compiled_manifest(<<-MANIFEST)
          exec { 'echo':
            command => Sensitive.new('#{file} #{supersecret}'),
          }
        MANIFEST
        # Execute permission works differently on Windows, but execute will fail since the
        # file doesn't have a valid extension and isn't a valid executable. The raised error
        # will be Errno::EIO, which is not useful. The Windows execute code needs to raise
        # Puppet::Util::Windows::Error so the Win32 error message is preserved.
        pending("PUP-3561 Needs to raise a meaningful Puppet::Error") if Puppet::Util::Platform.windows?
        expect(@logs).to include(an_object_having_attributes(level: :err, message: /'#{file}' is not executable/))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{supersecret}/))
      end

      it "redacts the arguments if the relative command cannot be resolved using the path parameter" do
        file = File.basename(tmpfile('exec'))
        dir = tmpdir('exec')

        apply_compiled_manifest(<<-MANIFEST)
          exec { 'echo':
            command => Sensitive.new('#{file} #{supersecret}'),
            path    => "#{dir}",
          }
        MANIFEST
        expect(@logs).to include(an_object_having_attributes(level: :err, message: /Could not find command '#{file}'/))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{supersecret}/))
      end
    end

    it "redacts the command on success", unless: Puppet::Util::Platform.jruby? do
      command = echo_from_ruby_exit_0(supersecret)

      apply_compiled_manifest(<<-MANIFEST)
        exec { 'true':
          command => Sensitive.new("#{command}"),
          path    => "#{path}",
        }
      MANIFEST
      expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing '[redacted]'", source: /Exec\[true\]/))
      expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing: '[redacted]'", source: "Puppet"))
      expect(@logs).to include(an_object_having_attributes(level: :notice, message: "executed successfully"))
      expect(@logs).to_not include(an_object_having_attributes(message: /#{supersecret}/))
    end

    it "redacts the command on failure", unless: Puppet::Util::Platform.jruby? do
      command = echo_from_ruby_exit_1(supersecret)

      apply_compiled_manifest(<<-MANIFEST)
        exec { 'false':
          command => Sensitive.new("#{command}"),
          path    => "#{path}",
        }
      MANIFEST
      expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing '[redacted]'", source: /Exec\[false\]/))
      expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing: '[redacted]'", source: "Puppet"))
      expect(@logs).to include(an_object_having_attributes(level: :err, message: "[command redacted] returned 1 instead of one of [0]"))
      expect(@logs).to_not include(an_object_having_attributes(message: /#{supersecret}/))
    end

    context "when handling checks", unless: Puppet::Util::Platform.jruby? do
      let(:onlyifsecret) { "onlyifsecret" }
      let(:unlesssecret) { "unlesssecret" }

      it "redacts command and onlyif outputs" do
        onlyif = echo_from_ruby_exit_0(onlyifsecret)

        apply_compiled_manifest(<<-MANIFEST)
          exec { 'true':
            command => Sensitive.new("#{ruby_exit_0}"),
            onlyif  => Sensitive.new("#{onlyif}"),
            path    => "#{path}",
          }
        MANIFEST
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing check '[redacted]'"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing '[redacted]'", source: /Exec\[true\]/))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing: '[redacted]'", source: "Puppet"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "[output redacted]"))
        expect(@logs).to include(an_object_having_attributes(level: :notice, message: "executed successfully"))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{onlyifsecret}/))
      end

      it "redacts the command that would have been executed but didn't due to onlyif" do
        command = echo_from_ruby_exit_0(supersecret)
        onlyif = echo_from_ruby_exit_1(onlyifsecret)

        apply_compiled_manifest(<<-MANIFEST)
          exec { 'true':
            command => Sensitive.new("#{command}"),
            onlyif  => Sensitive.new("#{onlyif}"),
            path    => "#{path}",
          }
        MANIFEST
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing check '[redacted]'"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing: '[redacted]'", source: "Puppet"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "[output redacted]"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "'[command redacted]' won't be executed because of failed check 'onlyif'"))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{supersecret}/))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{onlyifsecret}/))
      end

      it "redacts command and unless outputs" do
        unlesscmd = echo_from_ruby_exit_1(unlesssecret)

        apply_compiled_manifest(<<-MANIFEST)
          exec { 'true':
            command => Sensitive.new("#{ruby_exit_0}"),
            unless  => Sensitive.new("#{unlesscmd}"),
            path    => "#{path}",
          }
        MANIFEST
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing check '[redacted]'"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing '[redacted]'", source: /Exec\[true\]/))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing: '[redacted]'", source: "Puppet"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "[output redacted]"))
        expect(@logs).to include(an_object_having_attributes(level: :notice, message: "executed successfully"))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{unlesssecret}/))
      end

      it "redacts the command that would have been executed but didn't due to unless" do
        command = echo_from_ruby_exit_0(supersecret)
        unlesscmd = echo_from_ruby_exit_0(unlesssecret)

        apply_compiled_manifest(<<-MANIFEST)
          exec { 'true':
            command => Sensitive.new("#{command}"),
            unless  => Sensitive.new("#{unlesscmd}"),
            path    => "#{path}",
          }
        MANIFEST
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing check '[redacted]'"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing: '[redacted]'", source: "Puppet"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "[output redacted]"))
        expect(@logs).to include(an_object_having_attributes(level: :debug, message: "'[command redacted]' won't be executed because of failed check 'unless'"))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{supersecret}/))
        expect(@logs).to_not include(an_object_having_attributes(message: /#{unlesssecret}/))
      end
    end
  end
end
