require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/modules'

require 'puppet/pops'
require 'puppet/info_service'
require 'puppet/pops/evaluator/literal_evaluator'

describe "Puppet::InfoService" do
  include PuppetSpec::Files

  context 'task information service' do
    let(:mod_name) { 'test1' }
    let(:metadata) {
      { "private" => true,
        "description" => "a task that does a thing" } }
    let(:task_name) { "#{mod_name}::thingtask" }
    let(:modpath) { tmpdir('modpath') }
    let(:env_name) { 'testing' }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [modpath]) }
    let(:env_loader) { Puppet::Environments::Static.new(env) }

    context 'tasks_per_environment method' do
      it "returns task data for the tasks in an environment" do
        Puppet.override(:environments => env_loader) do
          PuppetSpec::Modules.create(mod_name, modpath, {:environment => env,
                                                         :tasks => [['thingtask',
                                                                     {:name => 'thingtask.json',
                                                                      :content => metadata.to_json}]]})
          expect(Puppet::InfoService.tasks_per_environment(env_name)).to eq([{:name => task_name,
                                                                              :module => {:name => mod_name},
                                                                              :metadata => metadata}  ])
        end
      end

      it "returns task data for valid tasks in an environment even if invalid tasks exist" do
        Puppet.override(:environments => env_loader) do
          @mod = PuppetSpec::Modules.create(mod_name, modpath, {:environment => env,
                                                                :tasks => [['atask',
                                                                            {:name => 'atask.json',
                                                                             :content => metadata.to_json}],
                                                                           ['btask',
                                                                            {:name => 'btask.json',
                                                                             :content => metadata.to_json}],
                                                                           ['ctask',
                                                                            {:name => 'ctask.json',
                                                                             :content => metadata.to_json}]]})
          File.write("#{modpath}/#{mod_name}/tasks/atask.json", "NOT JSON")

          expect(Puppet).to receive(:send_log).with(:err, /unexpected token at 'NOT JSON'/)

          @tasks = Puppet::InfoService.tasks_per_environment(env_name)
          expect(@tasks.map{|t| t[:name]}).to contain_exactly('test1::btask', 'test1::ctask')
        end
      end

      it "should throw EnvironmentNotFound if given a nonexistent environment" do
        expect{ Puppet::InfoService.tasks_per_environment('utopia') }.to raise_error(Puppet::Environments::EnvironmentNotFound)
      end
    end

    context 'task_data method' do
      context 'For a valid simple module' do
        before do
          Puppet.override(:environments => env_loader) do
            @mod = PuppetSpec::Modules.create(mod_name, modpath,
                                              {:environment => env,
                                               :tasks => [['thingtask',
                                                           {:name => 'thingtask.json',
                                                            :content => '{}'}]]})
            @result = Puppet::InfoService.task_data(env_name, mod_name, task_name)
          end
        end

        it 'returns the right set of keys' do
          expect(@result.keys.sort).to eq([:files, :metadata])
        end

        it 'specifies the metadata_file correctly' do
          expect(@result[:metadata]).to eq({})
        end

        it 'specifies the other files correctly' do
          task = @mod.tasks[0]
          expect(@result[:files]).to eq(task.files)
        end
      end

      context 'For a module with multiple implemenations and files' do
        let(:other_mod_name) { "shell_helpers" }
        let(:metadata) {
          { "implementations" => [
            {"name" => "thingtask.rb", "requirements" => ["puppet_agent"],
             "files" => ["#{mod_name}/lib/puppet/providers/"]},
            {"name" => "thingtask.sh", "requirements" => ["shell"] } ],
            "files" => [
             "#{mod_name}/files/my_data.json",
             "#{other_mod_name}/files/scripts/helper.sh",
             "#{mod_name}/files/data/files/data.rb"] } }
        let(:expected_files) { [ {'name' => 'thingtask.rb',
                                  'path' => "#{modpath}/#{mod_name}/tasks/thingtask.rb"},
        { 'name' => 'thingtask.sh',
          'path' => "#{modpath}/#{mod_name}/tasks/thingtask.sh"},
        { 'name' => "#{mod_name}/lib/puppet/providers/prov.rb",
          'path' => "#{modpath}/#{mod_name}/lib/puppet/providers/prov.rb"},
        { 'name' => "#{mod_name}/files/data/files/data.rb",
          'path' => "#{modpath}/#{mod_name}/files/data/files/data.rb"},
        { 'name' => "#{mod_name}/files/my_data.json",
          'path' => "#{modpath}/#{mod_name}/files/my_data.json"},
        { 'name' => "#{other_mod_name}/files/scripts/helper.sh",
          'path' => "#{modpath}/#{other_mod_name}/files/scripts/helper.sh" }
        ].sort_by {|f| f['name']} }

        before do
          Puppet.override(:environments => env_loader) do
            @mod = PuppetSpec::Modules.create(mod_name, modpath,
                                              {:environment => env,
                                               :tasks => [['thingtask.rb',
                                                           'thingtask.sh',
                                                           {:name => 'thingtask.json',
                                                            :content => metadata.to_json}]],
                                               :files => {
                                                 "files/data/files/data.rb" => "a file of data",
                                                 "files/my_data.json" => "{}",
                                                 "lib/puppet/providers/prov.rb" => "provider_content"} })
            @other_mod = PuppetSpec::Modules.create(other_mod_name, modpath, { :environment => env,
                                                                               :files =>{
              "files/scripts/helper.sh" => "helper content" } } )
            @result = Puppet::InfoService.task_data(env_name, mod_name, task_name)
          end
        end

        it 'returns the right set of keys' do
          expect(@result.keys.sort).to eq([:files, :metadata])
        end

        it 'specifies the metadata_file correctly' do
          expect(@result[:metadata]).to eq(metadata)
        end

        it 'specifies the other file names correctly' do
          expect(@result[:files].sort_by{|f| f['name']}).to eq(expected_files)
        end
      end

      context 'For a task with files that do not exist' do
        let(:metadata) {
          { "files" => [
            "#{mod_name}/files/random_data",
            "shell_helpers/files/scripts/helper.sh"] } }

        before do
          Puppet.override(:environments => env_loader) do
            @mod = PuppetSpec::Modules.create(mod_name, modpath,
                                              {:environment => env,
                                               :tasks => [['thingtask.rb',
                                                           {:name => 'thingtask.json',
                                                            :content => metadata.to_json}]]})
            @result = Puppet::InfoService.task_data(env_name, mod_name, task_name)
          end
        end

        it 'errors when the file is not found' do
          expect(@result[:error][:kind]).to eq('puppet.tasks/invalid-file')
        end
      end

      context 'For a task with bad metadata' do
        let(:metadata) {
          { "implementations" => [
            {"name" => "thingtask.rb", "requirements" => ["puppet_agent"] },
            {"name" => "thingtask.sh", "requirements" => ["shell"] } ] } }

        before do
          Puppet.override(:environments => env_loader) do
            @mod = PuppetSpec::Modules.create(mod_name, modpath,
                                              {:environment => env,
                                               :tasks => [['thingtask.sh',
                                                           {:name => 'thingtask.json',
                                                            :content => metadata.to_json}]]})
            @result = Puppet::InfoService.task_data(env_name, mod_name, task_name)
          end
        end

        it 'returns the right set of keys' do
          expect(@result.keys.sort).to eq([:error, :files, :metadata])
        end

        it 'returns the expected error' do
          expect(@result[:error][:kind]).to eq('puppet.tasks/missing-implementation')
        end
      end

      context 'For a task with required directories with no trailing slash' do
        let(:metadata) { { "files" => [ "#{mod_name}/files" ] } }

        before do
          Puppet.override(:environments => env_loader) do
            @mod = PuppetSpec::Modules.create(mod_name, modpath,
                                              {:environment => env,
                                               :tasks => [['thingtask.sh',
                                                           {:name => 'thingtask.json',
                                                            :content => metadata.to_json}]],
                                               :files => {
                                                 "files/helper.rb" => "help"}})
            @result = Puppet::InfoService.task_data(env_name, mod_name, task_name)
          end
        end

        it 'returns the right set of keys' do
          expect(@result.keys.sort).to eq([:error, :files, :metadata])
        end

        it 'returns the expected error' do
          expect(@result[:error][:kind]).to eq('puppet.tasks/invalid-metadata')
        end
      end

      it "should raise EnvironmentNotFound if given a nonexistent environment" do
        expect{ Puppet::InfoService.task_data('utopia', mod_name, task_name) }.to raise_error(Puppet::Environments::EnvironmentNotFound)
      end

      it "should raise MissingModule if the module does not exist" do
        Puppet.override(:environments => env_loader) do
          expect { Puppet::InfoService.task_data(env_name, 'notamodule', 'notamodule::thingtask') }
            .to raise_error(Puppet::Module::MissingModule)
        end
      end

      it "should raise TaskNotFound if the task does not exist" do
        Puppet.override(:environments => env_loader) do
          PuppetSpec::Modules.create(mod_name, modpath)
          expect { Puppet::InfoService.task_data(env_name, mod_name, 'testing1::notatask') }
            .to raise_error(Puppet::Module::Task::TaskNotFound)
        end
      end
    end
  end

  context 'plan information service' do
    let(:mod_name) { 'test1' }
    let(:plan_name) { "#{mod_name}::thingplan" }
    let(:modpath) { tmpdir('modpath') }
    let(:env_name) { 'testing' }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [modpath]) }
    let(:env_loader) { Puppet::Environments::Static.new(env) }

    context 'plans_per_environment method' do
      it "returns plan data for the plans in an environment" do
        Puppet.override(:environments => env_loader) do
          PuppetSpec::Modules.create(mod_name, modpath, {:environment => env, :plans => ['thingplan.pp']})
          expect(Puppet::InfoService.plans_per_environment(env_name)).to eq([{:name => plan_name, :module => {:name => mod_name}}])
        end
      end

      it "should throw EnvironmentNotFound if given a nonexistent environment" do
        expect{ Puppet::InfoService.plans_per_environment('utopia') }.to raise_error(Puppet::Environments::EnvironmentNotFound)
      end
    end

    context 'plan_data method' do
      context 'For a valid simple module' do
        before do
          Puppet.override(:environments => env_loader) do
            @mod = PuppetSpec::Modules.create(mod_name, modpath,
                                              {:environment => env,
                                               :plans => ['thingplan.pp']})
            @result = Puppet::InfoService.plan_data(env_name, mod_name, plan_name)
          end
        end

        it 'returns the right set of keys' do
          expect(@result.keys.sort).to eq([:files, :metadata])
        end

        it 'specifies the metadata_file correctly' do
          expect(@result[:metadata]).to eq({})
        end

        it 'specifies the other files correctly' do
          plan = @mod.plans[0]
          expect(@result[:files]).to eq(plan.files)
        end
      end
    end
  end

  context 'classes_per_environment service' do
    let(:code_dir) do
      dir_containing('manifests', {
        'foo.pp' => <<-CODE,
           class foo($foo_a, Integer $foo_b, String $foo_c = 'c default value') { }
           class foo2($foo2_a, Integer $foo2_b, String $foo2_c = 'c default value') { }
        CODE
        'bar.pp' => <<-CODE,
           class bar($bar_a, Integer $bar_b, String $bar_c = 'c default value') { }
           class bar2($bar2_a, Integer $bar2_b, String $bar2_c = 'c default value') { }
        CODE
        'intp.pp' => <<-CODE,
           class intp(String $intp_a = "default with interpolated $::os_family") { }
        CODE
        'fee.pp' => <<-CODE,
           class fee(Integer $fee_a = 1+1) { }
        CODE
        'fum.pp' => <<-CODE,
           class fum($fum_a) { }
        CODE
        'nothing.pp' => <<-CODE,
           # not much to see here, move along
        CODE
        'borked.pp' => <<-CODE,
           class Borked($Herp+$Derp) {}
        CODE
        'json_unsafe.pp' => <<-CODE,
             class json_unsafe($arg1 = /.*/, $arg2 = default, $arg3 = {1 => 1}) {}
        CODE
        'non_literal.pp' => <<-CODE,
            class oops(Integer[1-3] $bad_int) { }
        CODE
        'non_literal_2.pp' => <<-CODE,
           class oops_2(Optional[[String]] $double_brackets) { }
          CODE
       })
    end

    it "errors if not given a hash" do
      expect{ Puppet::InfoService.classes_per_environment("you wassup?")}.to raise_error(ArgumentError, 'Given argument must be a Hash')
    end

    it "returns empty hash if given nothing" do
      expect(Puppet::InfoService.classes_per_environment({})).to eq({})
    end

    it "produces classes and parameters from a given file" do
      files = ['foo.pp'].map {|f| File.join(code_dir, f) }
      result = Puppet::InfoService.classes_per_environment({'production' => files })
      expect(result).to eq({
        "production"=>{
           "#{code_dir}/foo.pp"=> {:classes => [
             {:name=>"foo",
               :params=>[
                 {:name=>"foo_a"},
                 {:name=>"foo_b", :type=>"Integer"},
                 {:name=>"foo_c", :type=>"String", :default_literal=>"c default value",
                   :default_source=>"'c default value'"}
               ]},
             {:name=>"foo2",
               :params=>[
                 {:name=>"foo2_a"},
                 {:name=>"foo2_b", :type=>"Integer"},
                 {:name=>"foo2_c", :type=>"String", :default_literal=>"c default value",
                   :default_source=>"'c default value'"}
               ]
             }
           ]}} # end production env
        })
    end

    it "produces classes and parameters from multiple files in same environment" do
      files = ['foo.pp', 'bar.pp'].map {|f| File.join(code_dir, f) }
      result = Puppet::InfoService.classes_per_environment({'production' => files })
      expect(result).to eq({
        "production"=>{
           "#{code_dir}/foo.pp"=>{:classes => [
             {:name=>"foo",
               :params=>[
                 {:name=>"foo_a"},
                 {:name=>"foo_b", :type=>"Integer"},
                 {:name=>"foo_c", :type=>"String", :default_literal=>"c default value",
                   :default_source=>"'c default value'"}
               ]},
             {:name=>"foo2",
               :params=>[
                 {:name=>"foo2_a"},
                 {:name=>"foo2_b", :type=>"Integer"},
                 {:name=>"foo2_c", :type=>"String", :default_literal=>"c default value",
                   :default_source=>"'c default value'"}
               ]
             }
           ]},
          "#{code_dir}/bar.pp"=> {:classes =>[
            {:name=>"bar",
              :params=>[
                {:name=>"bar_a"},
                {:name=>"bar_b", :type=>"Integer"},
                {:name=>"bar_c", :type=>"String", :default_literal=>"c default value",
                  :default_source=>"'c default value'"}
              ]},
            {:name=>"bar2",
              :params=>[
                {:name=>"bar2_a"},
                {:name=>"bar2_b", :type=>"Integer"},
                {:name=>"bar2_c", :type=>"String", :default_literal=>"c default value",
                :default_source=>"'c default value'"}
              ]
            }
          ]},

          } # end production env
        }
      )
    end

    it "produces classes and parameters from multiple files in multiple environments" do
      files_production = ['foo.pp', 'bar.pp'].map {|f| File.join(code_dir, f) }
      files_test = ['fee.pp', 'fum.pp'].map {|f| File.join(code_dir, f) }
      result = Puppet::InfoService.classes_per_environment({
        'production' => files_production,
        'test'       => files_test
      })

      expect(result).to eq({
        "production"=>{
           "#{code_dir}/foo.pp"=>{:classes => [
             {:name=>"foo",
               :params=>[
                 {:name=>"foo_a"},
                 {:name=>"foo_b", :type=>"Integer"},
                 {:name=>"foo_c", :type=>"String", :default_literal=>"c default value",
                   :default_source=>"'c default value'"}
               ]},
             {:name=>"foo2",
               :params=>[
                 {:name=>"foo2_a"},
                 {:name=>"foo2_b", :type=>"Integer"},
                 {:name=>"foo2_c", :type=>"String", :default_literal=>"c default value",
                   :default_source=>"'c default value'"}
               ]
             }
           ]},
          "#{code_dir}/bar.pp"=>{:classes => [
            {:name=>"bar",
              :params=>[
                {:name=>"bar_a"},
                {:name=>"bar_b", :type=>"Integer"},
                {:name=>"bar_c", :type=>"String", :default_literal=>"c default value",
                  :default_source=>"'c default value'"}
              ]},
            {:name=>"bar2",
              :params=>[
                {:name=>"bar2_a"},
                {:name=>"bar2_b", :type=>"Integer"},
                {:name=>"bar2_c", :type=>"String", :default_literal=>"c default value",
                  :default_source=>"'c default value'"}
                ]
              }
          ]},
          }, # end production env
        "test"=>{
           "#{code_dir}/fee.pp"=>{:classes => [
             {:name=>"fee",
               :params=>[
                 {:name=>"fee_a", :type=>"Integer", :default_source=>"1+1"}
               ]},
           ]},
          "#{code_dir}/fum.pp"=>{:classes => [
            {:name=>"fum",
              :params=>[
                {:name=>"fum_a"}
              ]},
          ]},
         } # end test env
        }
      )
    end

    it "avoids parsing file more than once when environments have same feature flag set" do
      # in this version of puppet, all environments are equal in this respect
      result = Puppet::Pops::Parser::EvaluatingParser.new.parse_file("#{code_dir}/fum.pp")
      expect_any_instance_of(Puppet::Pops::Parser::EvaluatingParser).to receive(:parse_file).with("#{code_dir}/fum.pp").once.and_return(result)
      files_production = ['fum.pp'].map {|f| File.join(code_dir, f) }
      files_test       = files_production

      result = Puppet::InfoService.classes_per_environment({
        'production' => files_production,
        'test'       => files_test
        })
       expect(result).to eq({
         "production"=>{ "#{code_dir}/fum.pp"=>{:classes => [ {:name=>"fum", :params=>[ {:name=>"fum_a"}]}]}},
         "test"      =>{ "#{code_dir}/fum.pp"=>{:classes => [ {:name=>"fum", :params=>[ {:name=>"fum_a"}]}]}}
       }
      )
    end

    it "produces expression string if a default value is not literal" do
      files = ['fee.pp'].map {|f| File.join(code_dir, f) }
      result = Puppet::InfoService.classes_per_environment({'production' => files })
      expect(result).to eq({
        "production"=>{
           "#{code_dir}/fee.pp"=>{:classes => [
             {:name=>"fee",
               :params=>[
                 {:name=>"fee_a", :type=>"Integer", :default_source=>"1+1"}
               ]},
           ]}} # end production env
        })
     end

     it "produces source string for literals that are not pure json" do
       files = ['json_unsafe.pp'].map {|f| File.join(code_dir, f) }
       result = Puppet::InfoService.classes_per_environment({'production' => files })
       expect(result).to eq({
         "production"=>{
            "#{code_dir}/json_unsafe.pp" => {:classes => [
              {:name=>"json_unsafe",
                :params => [
                  {:name => "arg1",
                    :default_source => "/.*/" },
                  {:name => "arg2",
                    :default_source => "default" },
                  {:name => "arg3",
                    :default_source => "{1 => 1}" }
                ]}
            ]}} # end production env
         })
     end

     it "errors with a descriptive message if non-literal class parameter is given" do
       files = ['non_literal.pp', 'non_literal_2.pp'].map {|f| File.join(code_dir, f) }
       result = Puppet::InfoService.classes_per_environment({'production' => files })
       expect(result).to eq({
        "production"=>{
           "#{code_dir}/non_literal.pp" =>
           {:error=> "The parameter '$bad_int' must be a literal type, not a Puppet::Pops::Model::AccessExpression (file: #{code_dir}/non_literal.pp, line: 1, column: 37)"},
           "#{code_dir}/non_literal_2.pp" =>
           {:error=> "The parameter '$double_brackets' must be a literal type, not a Puppet::Pops::Model::AccessExpression (file: #{code_dir}/non_literal_2.pp, line: 1, column: 44)"}
          } # end production env
        })
     end

    it "produces no type entry if type is not given" do
      files = ['fum.pp'].map {|f| File.join(code_dir, f) }
      result = Puppet::InfoService.classes_per_environment({'production' => files })
      expect(result).to eq({
        "production"=>{
           "#{code_dir}/fum.pp"=>{:classes => [
             {:name=>"fum",
               :params=>[
                 {:name=>"fum_a" }
               ]},
           ]}} # end production env
        })
    end

    it 'does not evaluate default expressions' do
      files = ['intp.pp'].map {|f| File.join(code_dir, f) }
      result = Puppet::InfoService.classes_per_environment({'production' => files })
      expect(result).to eq({
        'production' =>{
          "#{code_dir}/intp.pp"=>{:classes => [
            {:name=> 'intp',
              :params=>[
                {:name=> 'intp_a',
                  :type=> 'String',
                  :default_source=>'"default with interpolated $::os_family"'}
              ]},
          ]}} # end production env
      })
    end

    it "produces error entry if file is broken" do
      files = ['borked.pp'].map {|f| File.join(code_dir, f) }
       result = Puppet::InfoService.classes_per_environment({'production' => files })
       expect(result).to eq({
         "production"=>{
            "#{code_dir}/borked.pp"=>
              {:error=>"Syntax error at '+' (file: #{code_dir}/borked.pp, line: 1, column: 30)",
              },
            } # end production env
         })
    end

    it "produces empty {} if parsed result has no classes" do
      files = ['nothing.pp'].map {|f| File.join(code_dir, f) }
       result = Puppet::InfoService.classes_per_environment({'production' => files })
       expect(result).to eq({
         "production"=>{
           "#{code_dir}/nothing.pp"=> {:classes => [] }
           },
         })
    end

    it "produces error when given a file that does not exist" do
      files = ['the_tooth_fairy_does_not_exist.pp'].map {|f| File.join(code_dir, f) }
      result = Puppet::InfoService.classes_per_environment({'production' => files })
      expect(result).to eq({
        "production"=>{
          "#{code_dir}/the_tooth_fairy_does_not_exist.pp" => {:error  => "The file #{code_dir}/the_tooth_fairy_does_not_exist.pp does not exist"}
             },
        })
    end

  end
end
