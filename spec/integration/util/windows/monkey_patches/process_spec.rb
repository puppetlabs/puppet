# frozen_string_literal: true

require 'spec_helper'

describe 'Process', if: Puppet::Util::Platform.windows? do
  describe '.create' do
    context 'with common flags' do
      it do
        Process.create(
          app_name: 'cmd.exe /c echo 123',
          creation_flags: 0x00000008,
          process_inherit: false,
          thread_inherit: false,
          cwd: 'C:\\'
        )
      end

      context 'when FFI call fails' do
        before do
          allow(Process).to receive(:CreateProcessW).and_return(false)
        end

        it 'raises SystemCallError' do
          expect do
            Process.create(
              app_name: 'cmd.exe /c echo 123',
              creation_flags: 0x00000008
            )
          end.to raise_error(SystemCallError)
        end
      end
    end

    context 'with logon' do
      context 'without password' do
        it 'raises error' do
          expect do
            Process.create(
              app_name: 'cmd.exe /c echo 123',
              creation_flags: 0x00000008,
              with_logon: 'test'
            )
          end.to raise_error(ArgumentError, 'password must be specified if with_logon is used')
        end
      end

      context 'with common flags' do
        before do
          allow(Process).to receive(:CreateProcessWithLogonW).and_return(true)
        end

        it do
          Process.create(
            app_name: 'cmd.exe /c echo 123',
            creation_flags: 0x00000008,
            process_inherit: false,
            thread_inherit: false,
            with_logon: 'test',
            password: 'password',
            cwd: 'C:\\'
          )
        end

        context 'when FFI call fails' do
          before do
            allow(Process).to receive(:CreateProcessWithLogonW).and_return(false)
          end

          it 'raises SystemCallError' do
            expect do
              Process.create(
                app_name: 'cmd.exe /c echo 123',
                creation_flags: 0x00000008,
                with_logon: 'test',
                password: 'password'
              )
            end.to raise_error(SystemCallError)
          end
        end
      end
    end

    describe 'validations' do
      context 'when args is not a hash' do
        it 'raises TypeError' do
          expect do
            Process.create('test')
          end.to raise_error(TypeError, 'hash keyword arguments expected')
        end
      end

      context 'when args key is invalid' do
        it 'raises ArgumentError' do
          expect do
            Process.create(invalid_key: 'test')
          end.to raise_error(ArgumentError, "invalid key 'invalid_key'")
        end
      end

      context 'when startup_info is invalid' do
        it 'raises ArgumentError' do
          expect do
            Process.create(startup_info: { invalid_key: 'test' })
          end.to raise_error(ArgumentError, "invalid startup_info key 'invalid_key'")
        end
      end

      context 'when app_name and command_line are missing' do
        it 'raises ArgumentError' do
          expect do
            Process.create(creation_flags: 0)
          end.to raise_error(ArgumentError, 'command_line or app_name must be specified')
        end
      end

      context 'when executable is not found' do
        it 'raises Errno::ENOENT' do
          expect do
            Process.create(app_name: 'non_existent')
          end.to raise_error(Errno::ENOENT)
        end
      end
    end

    context 'when environment is not specified' do
      it 'passes local environment' do
        stdout_read, stdout_write = IO.pipe
        ENV['TEST_ENV'] = 'B'

        Process.create(
          app_name: 'cmd.exe /c echo %TEST_ENV%',
          creation_flags: 0x00000008,
          startup_info: { stdout: stdout_write }
        )

        stdout_write.close
        expect(stdout_read.read.chomp).to eql('B')
      end
    end

    context 'when environment is specified' do
      it 'does not pass local environment' do
        stdout_read, stdout_write = IO.pipe
        ENV['TEST_ENV'] = 'B'

        Process.create(
          app_name: 'cmd.exe /c echo %TEST_ENV%',
          creation_flags: 0x00000008,
          environment: '',
          startup_info: { stdout: stdout_write }
        )

        stdout_write.close
        expect(stdout_read.read.chomp).to eql('%TEST_ENV%')
      end

      it 'supports :environment as a string' do
        stdout_read, stdout_write = IO.pipe

        Process.create(
          app_name: 'cmd.exe /c echo %A% %B%',
          creation_flags: 0x00000008,
          environment: 'A=C;B=D',
          startup_info: { stdout: stdout_write }
        )

        stdout_write.close
        expect(stdout_read.read.chomp).to eql('C D')
      end

      it 'supports :environment as a string' do
        stdout_read, stdout_write = IO.pipe

        Process.create(
          app_name: 'cmd.exe /c echo %A% %C%',
          creation_flags: 0x00000008,
          environment: ['A=B;X;', 'C=;D;Y'],
          startup_info: { stdout: stdout_write }
        )

        stdout_write.close
        expect(stdout_read.read.chomp).to eql('B;X; ;D;Y')
      end
    end
  end

  describe '.setpriority' do
    let(:priority) { Process::BELOW_NORMAL_PRIORITY_CLASS }

    context 'when success' do
      it 'returns 0' do
        expect(Process.setpriority(0, Process.pid, priority)).to eql(0)
      end

      it 'treats an int argument of zero as the current process' do
        expect(Process.setpriority(0, 0, priority)).to eql(0)
      end
    end

    context 'when invalid arguments are sent' do
      it 'raises TypeError' do
        expect {
          Process.setpriority('test', 0, priority)
        }.to raise_error(TypeError)
      end
    end

    context 'when process is not found' do
      before do
        allow(Process).to receive(:OpenProcess).and_return(0)
      end
      it 'raises SystemCallError' do
        expect {
          Process.setpriority(0, 0, priority)
        }.to raise_error(SystemCallError)
      end
    end

    context 'when priority is not set' do
      before do
        allow(Process).to receive(:SetPriorityClass).and_return(false)
      end

      it 'raises SystemCallError' do
        expect {
          Process.setpriority(0, 0, priority)
        }.to raise_error(SystemCallError)
      end
    end
  end
end
