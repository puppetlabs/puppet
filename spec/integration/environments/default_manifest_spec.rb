require 'spec_helper'

module EnvironmentsDefaultManifestsSpec
describe "default manifests" do

  context "puppet with default_manifest settings" do
    let(:confdir) { Puppet[:confdir] }
    let(:environmentpath) { File.expand_path("envdir", confdir) }

    context "relative default" do
      let(:testingdir) { File.join(environmentpath, "testing") }

      before(:each) do
        FileUtils.mkdir_p(testingdir)
      end

      it "reads manifest from ./manifest of a basic directory environment" do
        manifestsdir = File.join(testingdir, "manifests")
        FileUtils.mkdir_p(manifestsdir)

        File.open(File.join(manifestsdir, "site.pp"), "w") do |f|
          f.puts("notify { 'ManifestFromRelativeDefault': }")
        end

        File.open(File.join(confdir, "puppet.conf"), "w") do |f|
          f.puts("environmentpath=#{environmentpath}")
        end

        expect(a_catalog_compiled_for_environment('testing')).to(
          include_resource('Notify[ManifestFromRelativeDefault]')
        )
      end
    end

    context "set absolute" do
      let(:testingdir) { File.join(environmentpath, "testing") }

      before(:each) do
        FileUtils.mkdir_p(testingdir)
      end

      it "reads manifest from an absolute default_manifest" do
        manifestsdir = File.expand_path("manifests", confdir)
        FileUtils.mkdir_p(manifestsdir)

        File.open(File.join(confdir, "puppet.conf"), "w") do |f|
          f.puts(<<-EOF)
  environmentpath=#{environmentpath}
  default_manifest=#{manifestsdir}
          EOF
        end

        File.open(File.join(manifestsdir, "site.pp"), "w") do |f|
          f.puts("notify { 'ManifestFromAbsoluteDefaultManifest': }")
        end

        expect(a_catalog_compiled_for_environment('testing')).to(
          include_resource('Notify[ManifestFromAbsoluteDefaultManifest]')
        )
      end

      it "reads manifest from directory environment manifest when environment.conf manifest set" do
        default_manifestsdir = File.expand_path("manifests", confdir)
        File.open(File.join(confdir, "puppet.conf"), "w") do |f|
          f.puts(<<-EOF)
  environmentpath=#{environmentpath}
  default_manifest=#{default_manifestsdir}
          EOF
        end

        manifestsdir = File.join(testingdir, "special_manifests")
        FileUtils.mkdir_p(manifestsdir)

        File.open(File.join(manifestsdir, "site.pp"), "w") do |f|
          f.puts("notify { 'ManifestFromEnvironmentConfManifest': }")
        end

        File.open(File.join(testingdir, "environment.conf"), "w") do |f|
          f.puts("manifest=./special_manifests")
        end

        expect(a_catalog_compiled_for_environment('testing')).to(
          include_resource('Notify[ManifestFromEnvironmentConfManifest]')
        )
        expect(Puppet[:default_manifest]).to eq(default_manifestsdir)
      end

      it "ignores manifests in the local ./manifests if default_manifest specifies another directory" do
        default_manifestsdir = File.expand_path("manifests", confdir)
        FileUtils.mkdir_p(default_manifestsdir)

        File.open(File.join(confdir, "puppet.conf"), "w") do |f|
          f.puts(<<-EOF)
  environmentpath=#{environmentpath}
  default_manifest=#{default_manifestsdir}
          EOF
        end

        File.open(File.join(default_manifestsdir, "site.pp"), "w") do |f|
          f.puts("notify { 'ManifestFromAbsoluteDefaultManifest': }")
        end

        implicit_manifestsdir = File.join(testingdir, "manifests")
        FileUtils.mkdir_p(implicit_manifestsdir)

        File.open(File.join(implicit_manifestsdir, "site.pp"), "w") do |f|
          f.puts("notify { 'ManifestFromImplicitRelativeEnvironmentManifestDirectory': }")
        end

        expect(a_catalog_compiled_for_environment('testing')).to(
          include_resource('Notify[ManifestFromAbsoluteDefaultManifest]')
        )
      end

    end

    context "with disable_per_environment_manifest true" do
      let(:manifestsdir) { File.expand_path("manifests", confdir) }
      let(:testingdir) { File.join(environmentpath, "testing") }

      before(:each) do
        FileUtils.mkdir_p(testingdir)
      end

      before(:each) do
        FileUtils.mkdir_p(manifestsdir)

        File.open(File.join(confdir, "puppet.conf"), "w") do |f|
          f.puts(<<-EOF)
  environmentpath=#{environmentpath}
  default_manifest=#{manifestsdir}
  disable_per_environment_manifest=true
          EOF
        end

        File.open(File.join(manifestsdir, "site.pp"), "w") do |f|
          f.puts("notify { 'ManifestFromAbsoluteDefaultManifest': }")
        end
      end

      it "reads manifest from the default manifest setting" do
        expect(a_catalog_compiled_for_environment('testing')).to(
          include_resource('Notify[ManifestFromAbsoluteDefaultManifest]')
        )
      end

      it "refuses to compile if environment.conf specifies a different manifest" do
        File.open(File.join(testingdir, "environment.conf"), "w") do |f|
          f.puts("manifest=./special_manifests")
        end

        expect { a_catalog_compiled_for_environment('testing') }.to(
          raise_error(Puppet::Error, /disable_per_environment_manifest.*environment.conf.*manifest.*conflict/)
        )
      end

      it "reads manifest from default_manifest setting when environment.conf has manifest set if setting equals default_manifest setting" do
        File.open(File.join(testingdir, "environment.conf"), "w") do |f|
          f.puts("manifest=#{manifestsdir}")
        end

        expect(a_catalog_compiled_for_environment('testing')).to(
          include_resource('Notify[ManifestFromAbsoluteDefaultManifest]')
        )
      end

      it "logs errors if environment.conf specifies a different manifest" do
        File.open(File.join(testingdir, "environment.conf"), "w") do |f|
          f.puts("manifest=./special_manifests")
        end

        Puppet.initialize_settings
        expect(Puppet[:environmentpath]).to eq(environmentpath)
        environment = Puppet.lookup(:environments).get('testing')
        expect(environment.manifest).to eq(manifestsdir)
        expect(@logs.first.to_s).to match(%r{disable_per_environment_manifest.*is true, but.*environment.*at #{testingdir}.*has.*environment.conf.*manifest.*#{testingdir}/special_manifests})
      end

      it "raises an error if default_manifest is not absolute" do
        File.open(File.join(confdir, "puppet.conf"), "w") do |f|
          f.puts(<<-EOF)
  environmentpath=#{environmentpath}
  default_manifest=./relative
  disable_per_environment_manifest=true
          EOF
        end

        expect { Puppet.initialize_settings }.to raise_error(Puppet::Settings::ValidationError, /default_manifest.*must be.*absolute.*when.*disable_per_environment_manifest.*true/)
      end
    end
  end

  RSpec::Matchers.define :include_resource do |expected|
    match do |actual|
      actual.resources.map(&:ref).include?(expected)
    end

    def failure_message
      "expected #{@actual.resources.map(&:ref)} to include #{expected}"
    end

    def failure_message_when_negated
      "expected #{@actual.resources.map(&:ref)} not to include #{expected}"
    end
  end

  def a_catalog_compiled_for_environment(envname)
    Puppet.initialize_settings
    expect(Puppet[:environmentpath]).to eq(environmentpath)
    node = Puppet::Node.new('testnode', :environment => 'testing')
    expect(node.environment).to eq(Puppet.lookup(:environments).get('testing'))
    Puppet::Parser::Compiler.compile(node)
  end
end
end
