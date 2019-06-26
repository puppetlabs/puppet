require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/modules'
require 'puppet/module/plan'

describe Puppet::Module::Plan do
  include PuppetSpec::Files

  let(:modpath) { tmpdir('plan_modpath') }
  let(:mymodpath) { File.join(modpath, 'mymod') }
  let(:othermodpath) { File.join(modpath, 'othermod') }
  let(:mymod) { Puppet::Module.new('mymod', mymodpath, nil) }
  let(:othermod) { Puppet::Module.new('othermod', othermodpath, nil) }
  let(:plans_path) { File.join(mymodpath, 'plans') }
  let(:other_plans_path) { File.join(othermodpath, 'plans') }
  let(:plans_glob) { File.join(mymodpath, 'plans', '*') }

  describe :naming do
    word = (Puppet::Module::Plan::RESERVED_WORDS - Puppet::Module::Plan::RESERVED_DATA_TYPES).sample
    datatype = (Puppet::Module::Plan::RESERVED_DATA_TYPES - Puppet::Module::Plan::RESERVED_WORDS).sample
    test_cases = { 'iLegal.pp'  => 'Plan names must start with a lowercase letter and be composed of only lowercase letters, numbers, and underscores',
                   'name.md'    => 'Plan name cannot have extension .md, must be .pp or .yaml',
                   "#{word}.pp"     => "Plan name cannot be a reserved word, but was '#{word}'",
                   "#{datatype}.pp" => "Plan name cannot be a Puppet data type, but was '#{datatype}'",
                   'test_1.pp'    => nil,
                   'test_2.yaml'  => nil }
    test_cases.each do |filename, error|
      it "constructs plans when needed with #{filename}" do
        name = File.basename(filename, '.*')
        if error
          expect { Puppet::Module::Plan.new(mymod, name, [File.join(plans_path, filename)]) }
            .to raise_error(Puppet::Module::Plan::InvalidName,
                            error)
        else
          expect { Puppet::Module::Plan.new(mymod, name, [filename]) }
            .not_to raise_error
        end
      end
    end
  end

  it "finds all plans in module" do
    og_files = %w{plan1.pp plan2.yaml not-a-plan.ok}.map { |bn| "#{plans_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(plans_glob).and_return(og_files)

    plans = Puppet::Module::Plan.plans_in_module(mymod)

    expect(plans.count).to eq(2)
  end

  it "selects .pp file before .yaml" do
    og_files = %w{plan1.pp plan1.yaml}.map { |bn| "#{plans_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(plans_glob).and_return(og_files)

    plans = Puppet::Module::Plan.plans_in_module(mymod)

    expect(plans.count).to eq(1)
    expect(plans.first.files.count).to eq(1)
    expect(plans.first.files.first['name']).to eq('plan1.pp')
  end

  it "gives the 'init' plan a name that is just the module's name" do
    expect(Puppet::Module::Plan.new(mymod, 'init', ["#{plans_path}/init.pp"]).name).to eq('mymod')
  end
end
