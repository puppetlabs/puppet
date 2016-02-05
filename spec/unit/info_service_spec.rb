require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/pops'
require 'puppet/info_service'
require 'puppet/pops/evaluator/literal_evaluator'

describe "Puppet::InfoService" do
  context 'classes_per_environment service' do
    include PuppetSpec::Files

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
      Puppet::Pops::Parser::EvaluatingParser.any_instance.expects(:parse_file).with("#{code_dir}/fum.pp").returns(result).once
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
              {:error=>"Syntax error at '+' at #{code_dir}/borked.pp:1:30",
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
