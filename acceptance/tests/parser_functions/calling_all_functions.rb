test_name 'Calling all functions.. test in progress!'

tag 'audit:medium',
    'audit:acceptance'

# create single manifest calling all functions
step 'Apply manifest containing all function calls'
def manifest_call_each_function_from_array(functions)
  manifest = ''
  # use index to work around puppet's immutable variables
  # use variables so we can concatenate strings
  functions.each_with_index do |function,index|
    if function[:rvalue]
      manifest << "$pre#{index} = \"sayeth #{function[:name].capitalize}: Scope(Class[main]): \" "
      manifest << "$output#{index} = #{function[:name]}(#{function[:args]}) "
      manifest << "#{function[:lambda]} notice \"${pre#{index}}${output#{index}}\"\n"
    else
      manifest << "$pre#{index} = \"sayeth #{function[:name].capitalize}: \" "
      manifest << "notice \"${pre#{index}}\"\n"
      manifest << "#{function[:name]}(#{function[:args]}) "
      manifest << "#{function[:lambda]}\n"
    end
  end
  manifest
end


generator = ''
agents.each do |agent|
  testdir = agent.tmpdir('calling_all_functions')
  if agent["platform"] =~ /win/
    generator = {:args => '"c:/windows/system32/tasklist.exe"', :expected => /\nImage Name/}
  else
    generator = {:args => '"/bin/date"',                        :expected => /\w\w\w.*?\d\d:\d\d\:\d\d/}
  end

  # create list of 3x functions and args
  # notes: hiera functions are well tested elsewhere, included for completeness
  #   special cases: contain (call this from call_em_all)
  #   do fail last because it errors out

  functions_3x = [
    {:name => :alert,            :args => '"consider yourself on alert"',      :lambda => nil, :expected => 'consider yourself on alert', :rvalue => false},
    {:name => :binary_file,      :args => '"call_em_all/rickon.txt"',          :lambda => nil, :expected => '', :rvalue => true},
    #{:name => :break,            :args => '',                                  :lambda => nil, :expected => '', :rvalue => false},
    # this is explicitly called from call_em_all module which is included below
    #{:name => :contain,          :args => 'call_em_all',                       :lambda => nil, :expected => '', :rvalue => true},
    # below doens't instance the resource. no output
    {:name => :create_resources, :args => 'notify, {"w"=>{message=>"winter is coming"}}',      :lambda => nil, :expected => '', :rvalue => false},
    {:name => :crit,             :args => '"consider yourself critical"',      :lambda => nil, :expected => 'consider yourself critical', :rvalue => false},
    {:name => :debug,            :args => '"consider yourself bugged"',        :lambda => nil, :expected => '', :rvalue => false}, # no output expected unless run with debug
    {:name => :defined,          :args => 'File["/tmp"]',                      :lambda => nil, :expected => 'false', :rvalue => true},
    {:name => :dig,              :args => '[100]',                             :lambda => nil, :expected => '[100]', :rvalue => true},
    # Expect sha256 hash value for the digest when running on fips enabled system
    {:name => :digest,           :args => '"Sansa"',                           :lambda => nil, :expected => on(agent, facter("fips_enabled")).stdout =~ /true/ ? '4ebf3a5527313f06c7965749d7764c15cba6fe86da11691ca9bd0ce448563979' : 'f16491bf0133c6103918b2edcd00cf89', :rvalue => true},
    {:name => :emerg,            :args => '"consider yourself emergent"',      :lambda => nil, :expected => 'consider yourself emergent', :rvalue => false},
    {:name => :err,              :args => '"consider yourself in err"',        :lambda => nil, :expected => 'consider yourself in err', :rvalue => false},
    {:name => :file,             :args => '"call_em_all/rickon.txt"',          :lambda => nil, :expected => 'who?', :rvalue => true},
    {:name => :fqdn_rand,        :args => '100000',                            :lambda => nil, :expected => /Fqdn_rand: Scope\(Class\[main\]\): \d{1,5}/, :rvalue => true},
    # generate requires a fully qualified exe; which requires specifics for windows vs posix
    #{:name => :generate,         :args => generator[:args],                    :lambda => nil, :expected => generator[:expected], :rvalue => true},
    {:name => :hiera_array,      :args => 'date,default_array',                :lambda => nil, :expected => 'default_array', :rvalue => true},
    {:name => :hiera_hash,       :args => 'date,default_hash',                 :lambda => nil, :expected => 'default_hash', :rvalue => true},
    {:name => :hiera_include,    :args => 'date,call_em_all',                  :lambda => nil, :expected => '', :rvalue => false},
    {:name => :hiera,            :args => 'date,default_date',                 :lambda => nil, :expected => 'default_date', :rvalue => true},
    {:name => :include,          :args => 'call_em_all',                       :lambda => nil, :expected => '', :rvalue => false},
    {:name => :info,             :args => '"consider yourself informed"',      :lambda => nil, :expected => '', :rvalue => false}, # no ouput unless in debug mode
    {:name => :inline_template,  :args => '\'empty<%= @x %>space\'',           :lambda => nil, :expected => 'emptyspace', :rvalue => true},
    # test the living life out of this thing in lookup.rb, and it doesn't allow for a default value
    #{:name => :lookup,           :args => 'date,lookup_date',                  :lambda => nil, :expected => '', :rvalue => true},  # well tested elsewhere
    # Use fips approved hash when running on fips enabled system
    {:name => on(agent, facter("fips_enabled")).stdout =~ /true/ ?  :sha256 : :md5,              :args => '"Bran"',                            :lambda => nil, :expected => on(agent, facter("fips_enabled")).stdout =~ /true/ ? '824264f7f73d6026550b52a671c50ad0c4452af66c24f3784e30f515353f2ce0' : '723f9ac32ceb881ddf4fb8fc1020cf83' , :rvalue => true},
    # Integer.new
    {:name => :Integer,          :args => '"100"',                             :lambda => nil, :expected => '100', :rvalue => true},
    {:name => :notice,           :args => '"consider yourself under notice"',  :lambda => nil, :expected => 'consider yourself under notice', :rvalue => false},
    {:name => :realize,          :args => 'User[arya]',                        :lambda => nil, :expected => '', :rvalue => false},  # TODO: create a virtual first
    {:name => :regsubst,         :args => '"Cersei","Cer(\\\\w)ei","Daenery\\\\1"',:lambda => nil, :expected => 'Daenerys', :rvalue => true},
    # explicitly called in call_em_all; implicitly called by the include above
    #{:name => :require,          :args => '[4,5,6]',                          :lambda => nil, :expected => '', :rvalue => true},
    # 4x output contains brackets around scanf output
    {:name => :scanf,            :args => '"Eddard Stark","%6s"',              :lambda => nil, :expected => '[Eddard]', :rvalue => true},
    {:name => :sha1,             :args => '"Sansa"',                           :lambda => nil, :expected => '4337ce5e4095e565d51e0ef4c80df1fecf238b29', :rvalue => true},
    {:name => :shellquote,       :args => '["-1", "--two"]',                   :lambda => nil, :expected => '-1 --two', :rvalue => true},
    # 4x output contains brackets around split output and commas btwn values
    {:name => :split,            :args => '"9,8,7",","',                       :lambda => nil, :expected => '[9, 8, 7]', :rvalue => true},
    {:name => :sprintf,          :args => '"%b","123"',                        :lambda => nil, :expected => '1111011', :rvalue => true},
    {:name => :step,             :args => '[100,99],1',                        :lambda => nil, :expected => 'Iterator[Integer]-Value', :rvalue => true},
    # explicitly called in call_em_all
    #{:name => :tag,              :args => '[4,5,6]',                          :lambda => nil, :expected => '', :rvalue => true},
    {:name => :tagged,           :args => '"yer_it"',                          :lambda => nil, :expected => 'false', :rvalue => true},
    {:name => :template,         :args => '"call_em_all/template.erb"',        :lambda => nil, :expected => 'no defaultsno space', :rvalue => true},
    {:name => :type,             :args => '42',                                :lambda => nil, :expected => 'Integer[42, 42]', :rvalue => true},
    {:name => :versioncmp,       :args => '"1","2"',                           :lambda => nil, :expected => '-1', :rvalue => true},
    {:name => :warning,          :args => '"consider yourself warned"',        :lambda => nil, :expected => 'consider yourself warned', :rvalue => false},
    # do this one last or it will not allow the others to run.
    {:name => :fail,             :args => '"Jon Snow"',                        :lambda => nil, :expected => /Error:.*Jon Snow/, :rvalue => false},
  ]

  puppet_version = on(agent, puppet('--version')).stdout.chomp

  functions_4x = [
    {:name => :assert_type,      :args => '"String[1]", "Valar morghulis"',    :lambda => nil, :expected => 'Valar morghulis', :rvalue => true},
    {:name => :each,             :args => '[1,2,3]',                           :lambda => '|$x| {$x}', :expected => '[1, 2, 3]', :rvalue => true},
    {:name => :epp,              :args => '"call_em_all/template.epp",{x=>droid}', :lambda => nil, :expected => 'This is the droid you are looking for!', :rvalue => true},
    {:name => :filter,           :args => '[4,5,6]',                           :lambda => '|$x| {true}', :expected => '[4, 5, 6]', :rvalue => true},
    # find_file() called by binary_file
    #{:name => :find_file,           :args => '[4,5,6]',                           :lambda => '|$x| {true}', :expected => '[4, 5, 6]', :rvalue => true},
    {:name => :inline_epp,       :args => '\'<%= $x %>\',{x=>10}',             :lambda => nil, :expected => '10', :rvalue => true},
    #{:name => :lest,             :args => '100',                               :lambda => '"100"', :expected => '100', :rvalue => true},
    {:name => :map,              :args => '[7,8,9]',                           :lambda => '|$x| {$x * $x}', :expected => '[49, 64, 81]', :rvalue => true},
    {:name => :match,            :args => '"abc", /b/',                        :lambda => nil, :expected => '[b]', :rvalue => true},
    #{:name => :next,             :args => '100',                               :lambda => nil, :expected => '100', :rvalue => true},
    {:name => :reduce,           :args => '[4,5,6]',                           :lambda => '|$sum, $n| { $sum+$n }', :expected => '15', :rvalue => true},
    #{:name => :return,           :args => '100',                               :lambda => nil, :expected => '100', :rvalue => true},
    {:name => :reverse_each,     :args => '[100,99]',                          :lambda => nil, :expected => 'Iterator[Integer]-Value', :rvalue => true},
    #         :reuse,:recycle
    {:name => :slice,            :args => '[1,2,3,4,5,6], 2',                  :lambda => nil, :expected => '[[1, 2], [3, 4], [5, 6]]', :rvalue => true},
    {:name => :strftime,         :args => 'Timestamp("4216-09-23T13:14:15.123 UTC"), "%C"',    :lambda => nil, :expected => '42', :rvalue => true},
    {:name => :then,             :args => '100',                               :lambda => '|$x| {$x}', :expected => '100', :rvalue => true},
    {:name => :with,             :args => '1, "Catelyn"',                      :lambda => '|$x, $y| {"$x, $y"}', :expected => '1, Catelyn', :rvalue => true},
  ]

  module_manifest = <<PP
File {
  ensure => directory,
}
file {
  '#{testdir}':;
  '#{testdir}/environments':;
  '#{testdir}/environments/production':;
  '#{testdir}/environments/production/modules':;
  '#{testdir}/environments/production/modules/tagged':;
  '#{testdir}/environments/production/modules/tagged/manifests':;
  '#{testdir}/environments/production/modules/contained':;
  '#{testdir}/environments/production/modules/contained/manifests':;
  '#{testdir}/environments/production/modules/required':;
  '#{testdir}/environments/production/modules/required/manifests':;
  '#{testdir}/environments/production/modules/call_em_all':;
  '#{testdir}/environments/production/modules/call_em_all/manifests':;
  '#{testdir}/environments/production/modules/call_em_all/templates':;
  '#{testdir}/environments/production/modules/call_em_all/files':;
}
file { '#{testdir}/environments/production/modules/tagged/manifests/init.pp':
  ensure  => file,
  content => 'class tagged {
    notice tagged
    tag     yer_it
    }',
}
file { '#{testdir}/environments/production/modules/required/manifests/init.pp':
  ensure  => file,
  content => 'class required {
    notice required
    }',
}
file { '#{testdir}/environments/production/modules/contained/manifests/init.pp':
  ensure  => file,
  content => 'class contained {
    notice contained
    }',
}
file { '#{testdir}/environments/production/modules/call_em_all/manifests/init.pp':
  ensure  => file,
  content => 'class call_em_all {
    notice call_em_all
    contain contained
    require required
    tag     yer_it
    }',
}
file { '#{testdir}/environments/production/modules/call_em_all/files/rickon.txt':
  ensure  => file,
  content => 'who?',
}
file { '#{testdir}/environments/production/modules/call_em_all/templates/template.epp':
  ensure  => file,
  content => 'This is the <%= $x %> you are looking for!',
}
file { '#{testdir}/environments/production/modules/call_em_all/templates/template.erb':
  ensure  => file,
  content => 'no defaults<%= @x %>no space',
}
PP

  apply_manifest_on(agent, module_manifest, :catch_failures => true)

  scope = 'Scope(Class[main]):'
  # apply the 4x function manifest with future parser
  puppet_apply_options = {:modulepath => "#{testdir}/environments/production/modules/",
     :acceptable_exit_codes => 1}
  puppet_apply_options[:future_parser] = true if puppet_version =~ /\A3\./
  apply_manifest_on(agent, manifest_call_each_function_from_array(functions_4x), puppet_apply_options) do |result|
       functions_4x.each do |function|
         expected = "#{function[:name].capitalize}: #{scope} #{function[:expected]}"
         unless agent['locale'] == 'ja'
           assert_match(expected, result.output,
                        "#{function[:name]} output didn't match expected value")
         end
       end
     end

   file_path = agent.tmpfile('apply_manifest.pp')

   create_remote_file(agent, file_path, manifest_call_each_function_from_array(functions_3x))

   trusted_3x = puppet_version =~ /\A3\./ ? '--trusted_node_data ' : ''
   on(agent, puppet("apply #{trusted_3x} --color=false  --modulepath #{testdir}/environments/production/modules/ #{file_path}"),
      :acceptable_exit_codes => 1 ) do |result|
        functions_3x.each do |function|
          # append the function name to the matcher so it's more expressive
          if function[:expected].is_a?(String)
            if function[:name] == :fail
              expected = function[:expected]
            elsif function[:name] == :crit
              expected = "#{function[:name].capitalize}ical: #{scope} #{function[:expected]}"
            elsif function[:name] == :emerg
              expected = "#{function[:name].capitalize}ency: #{scope} #{function[:expected]}"
            elsif function[:name] == :err
              expected = "#{function[:name].capitalize}or: #{scope} #{function[:expected]}"
            elsif function[:expected] == ''
              expected = "#{function[:name].capitalize}: #{function[:expected]}"
            else
              expected = "#{function[:name].capitalize}: #{scope} #{function[:expected]}"
            end
          elsif function[:expected].is_a?(Regexp)
            expected = function[:expected]
          else
            raise 'unhandled function expectation type (we allow String or Regexp)'
          end

          unless agent['locale'] == 'ja'
            assert_match(expected, result.output, "#{function[:name]} output didn't match expected value")
          end
        end
     end

end
