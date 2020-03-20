require 'spec_helper'
require 'tmpdir'
require 'puppet/node/bolt_project'
require 'puppet/util/execution'
require 'puppet_spec/modules'
require 'puppet/parser/parser_factory'

describe Puppet::Node::BoltProject do
  let(:proj) { Puppet::Node::BoltProject.create("testing", Dir.pwd, []) }

  include PuppetSpec::Files

  context 'the bolt project' do
    describe "when modeling a specific project" do
      let(:first_modulepath) { tmpdir('firstmodules') }
      let(:second_modulepath) { tmpdir('secondmodules') }
      let(:proj) { Puppet::Node::BoltProject.create(:modules_test, Dir.pwd, [first_modulepath, second_modulepath]) }
      let(:pup_module) { Puppet::Module.new('puppet', Dir.pwd, proj) }

      describe "module data" do
        describe ".module" do
          it "returns the cwd module if requested" do
            expect(proj.module('puppet')).to eq(pup_module)
          end
        end

        describe "#modules_by_path" do
          it "does not include cwd" do
            expect(proj.modules_by_path).to eq({
              first_modulepath => [],
              second_modulepath => []
            })
          end
        end

        describe ".modules" do
          it "returns just the cwd if there are no modules" do
            expect(proj.modules).to eq([pup_module])
          end

          it "returns a module named for every directory in each module path, including the cwd" do
            %w{foo bar}.each do |mod_name|
              PuppetSpec::Modules.generate_files(mod_name, first_modulepath)
            end
            %w{bee baz}.each do |mod_name|
              PuppetSpec::Modules.generate_files(mod_name, second_modulepath)
            end
            expect(proj.modules.collect{|mod| mod.name}.sort).to eq(%w{foo bar bee baz puppet}.sort)
          end
        end
      end
    end
  end
end
