#!/usr/bin/env ruby
require 'spec_helper'
require 'fileutils'
require 'puppet/type'

describe Puppet::Type.type(:k5login), :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  context "the type class" do
    subject { described_class }
    it { is_expected.to be_validattr :ensure }
    it { is_expected.to be_validattr :path }
    it { is_expected.to be_validattr :principals }
    it { is_expected.to be_validattr :mode }
    it { is_expected.to be_validattr :selrange }
    it { is_expected.to be_validattr :selrole }
    it { is_expected.to be_validattr :seltype }
    it { is_expected.to be_validattr :seluser }
    # We have one, inline provider implemented.
    it { is_expected.to be_validattr :provider }
  end

  let(:path) { tmpfile('k5login') }

  def resource(attrs = {})
    attrs = {
      :ensure     => 'present',
      :path       => path,
      :principals => 'fred@EXAMPLE.COM',
      :seluser    => 'user_u',
      :selrole    => 'role_r',
      :seltype    => 'type_t',
      :selrange   => 's0',
    }.merge(attrs)

    if content = attrs.delete(:content)
      File.open(path, 'w') { |f| f.print(content) }
    end

    resource = described_class.new(attrs)
    resource
  end

  before :each do
    FileUtils.touch(path)
  end

  context "the provider" do
    context "when the file is missing" do
      it "should initially be absent" do
        File.delete(path)
        expect(resource.retrieve[:ensure]).to eq(:absent)
      end

      it "should create the file when synced" do
        resource(:ensure => 'present').parameter(:ensure).sync
        expect(Puppet::FileSystem.exist?(path)).to be_truthy
      end
    end

    context "when the file is present" do
      context "retrieved initial state" do
        subject { resource.retrieve }

        it "should retrieve its properties correctly with zero principals" do
          expect(subject[:ensure]).to eq(:present)
          expect(subject[:principals]).to eq([])
          # We don't really care what the mode is, just that it got it
          expect(subject[:mode]).not_to be_nil
        end

        context "with one principal" do
          subject { resource(:content => "daniel@EXAMPLE.COM\n").retrieve }

          it "should retrieve its principals correctly" do
            expect(subject[:principals]).to eq(["daniel@EXAMPLE.COM"])
          end
        end

        [:seluser, :selrole, :seltype, :selrange].each do |param|
          property = described_class.attrclass(param)
          context param.to_s do
            let(:sel_param) { property.new :resource => resource }

            context "with selinux" do
              it "should return correct values based on SELinux state" do
                sel_param.stubs(:debug)
                expectedresult = case param
                  when :seluser; "user_u"
                  when :selrole; "object_r"
                  when :seltype; "krb5_home_t"
                  when :selrange; "s0"
                end
                expect(sel_param.default).to eq(expectedresult)
              end
            end

            context 'without selinux' do
              it 'should not try to determine the initial state' do
                Puppet::Type::K5login::ProviderK5login.any_instance.stubs(:selinux_support?).returns false

                expect(subject[:selrole]).to be_nil
              end

              it "should do nothing for safe_insync? if no SELinux support" do
                sel_param.should = 'newcontext'
                sel_param.expects(:selinux_support?).returns false
                expect(sel_param.safe_insync?('oldcontext')).to eq(true)
              end
            end
          end
        end

        context "with two principals" do
          subject do
            content = ["daniel@EXAMPLE.COM", "george@EXAMPLE.COM"].join("\n")
            resource(:content => content).retrieve
          end

          it "should retrieve its principals correctly" do
            expect(subject[:principals]).to eq(["daniel@EXAMPLE.COM", "george@EXAMPLE.COM"])
          end
        end
      end

      it "should remove the file ensure is absent" do
        resource(:ensure => 'absent').property(:ensure).sync
        expect(Puppet::FileSystem.exist?(path)).to be_falsey
      end

      it "should write one principal to the file" do
        expect(File.read(path)).to eq("")
        resource(:principals => ["daniel@EXAMPLE.COM"]).property(:principals).sync
        expect(File.read(path)).to eq("daniel@EXAMPLE.COM\n")
      end

      it "should write multiple principals to the file" do
        content = ["daniel@EXAMPLE.COM", "george@EXAMPLE.COM"]

        expect(File.read(path)).to eq("")
        resource(:principals => content).property(:principals).sync
        expect(File.read(path)).to eq(content.join("\n") + "\n")
      end

      describe "when setting the mode" do
        # The defined input type is "mode, as an octal string"
        ["400", "600", "700", "644", "664"].each do |mode|
          it "should update the mode to #{mode}" do
            resource(:mode => mode).property(:mode).sync

            expect((Puppet::FileSystem.stat(path).mode & 07777).to_s(8)).to eq(mode)
          end
        end
      end

      context "#stat" do
        let(:file) { described_class.new(:path => path) }

        it "should return nil if the file does not exist" do
          file[:path] = make_absolute('/foo/bar/baz/non-existent')

          expect(file.stat).to be_nil
        end

        it "should return nil if the file cannot be stat'ed" do
          dir = tmpfile('link_test_dir')
          child = File.join(dir, 'some_file')

          # Note: we aren't creating the file for this test. If the user is
          # running these tests as root, they will be able to access the
          # directory. In that case, this test will still succeed, not because
          # we cannot stat the file, but because the file does not exist.
          Dir.mkdir(dir)
          begin
            File.chmod(0, dir)

            file[:path] = child

            expect(file.stat).to be_nil
          ensure
            # chmod it back so we can clean it up
            File.chmod(0777, dir)
          end
        end

        it "should return nil if parts of path are not directories" do
          regular_file = tmpfile('ENOTDIR_test')
          FileUtils.touch(regular_file)
          impossible_child = File.join(regular_file, 'some_file')

          file[:path] = impossible_child
          expect(file.stat).to be_nil
        end

        it "should return the stat instance" do
          expect(file.stat).to be_a(File::Stat)
        end

        it "should cache the stat instance" do
          expect(file.stat.object_id).to eql(file.stat.object_id)
        end
      end
    end
  end
end
