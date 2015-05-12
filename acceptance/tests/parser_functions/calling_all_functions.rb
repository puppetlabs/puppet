test_name 'Calling all functions.. test in progress!'

# create list of 3x functions and args
# notes: hiera functions are well tested elsewhere, included for completeness
#   special cases: contain (call this from call_em_all)
#   do fail last because it errors out
testdir   = ''
generator = ''
agents.each do |agent|
  testdir = agent.tmpdir('calling_all_functions')
  if agent["platform"] =~ /win/
    generator = {:args => '"c:/windows/system32/tasklist.exe"', :expected => /\nImage Name/}
  else
    generator = {:args => '"/bin/date"',                        :expected => /\w\w\w.*?\d\d:\d\d\:\d\d/}
  end
end

functions_3x = [
  {:name => :alert,            :args => '"consider yourself on alert"',      :lambda => nil, :expected => 'consider yourself on alert', :rvalue => false},
  # this is explicitly called from call_em_all module which is included below
  #{:name => :contain,          :args => 'call_em_all',                       :lambda => nil, :expected => '', :rvalue => true},
  # below doens't instance the resource. no output
  {:name => :create_resources, :args => 'notify, {"w"=>{message=>"winter is coming"}}',      :lambda => nil, :expected => '', :rvalue => false},
  {:name => :crit,             :args => '"consider yourself critical"',      :lambda => nil, :expected => 'consider yourself critical', :rvalue => false},
  {:name => :debug,            :args => '"consider yourself bugged"',        :lambda => nil, :expected => '', :rvalue => false}, # no output expected unless run with debug
  {:name => :defined,          :args => 'File["/tmp"]',                      :lambda => nil, :expected => 'false', :rvalue => true},
  {:name => :digest,           :args => '"Sansa"',                           :lambda => nil, :expected => 'f16491bf0133c6103918b2edcd00cf89', :rvalue => true},
  {:name => :emerg,            :args => '"consider yourself emergent"',      :lambda => nil, :expected => 'consider yourself emergent', :rvalue => false},
  {:name => :err,              :args => '"consider yourself in err"',        :lambda => nil, :expected => 'consider yourself in err', :rvalue => false},
  {:name => :file,             :args => '"call_em_all/rickon.txt"',          :lambda => nil, :expected => 'who?', :rvalue => true},
  {:name => :fqdn_rand,        :args => '100000',                            :lambda => nil, :expected => /\d+\e/, :rvalue => true},
  # generate requires a fully qualified exe; which requires specifics for windows vs posix
  {:name => :generate,         :args => generator[:args],                    :lambda => nil, :expected => generator[:expected], :rvalue => true},
  {:name => :hiera_array,      :args => 'date,default_array',                :lambda => nil, :expected => 'default_array', :rvalue => true},
  {:name => :hiera_hash,       :args => 'date,default_hash',                 :lambda => nil, :expected => 'default_hash', :rvalue => true},
  {:name => :hiera_include,    :args => 'date,call_em_all',                  :lambda => nil, :expected => '', :rvalue => false},
  {:name => :hiera,            :args => 'date,default_date',                 :lambda => nil, :expected => 'default_date', :rvalue => true},
  {:name => :include,          :args => 'call_em_all',                       :lambda => nil, :expected => '', :rvalue => false},
  {:name => :info,             :args => '"consider yourself informed"',      :lambda => nil, :expected => 'consider yourself informed', :rvalue => false},
  {:name => :inline_template,  :args => '\'empty<%= @x %>space\'',           :lambda => nil, :expected => 'emptyspace', :rvalue => true},
  # test the living life out of this thing in lookup.rb, and it doesn't allow for a default value
  #{:name => :lookup,           :args => 'date,lookup_date',                  :lambda => nil, :expected => '', :rvalue => true},  # well tested elsewhere
  {:name => :md5,              :args => '"Bran"',                            :lambda => nil, :expected => '723f9ac32ceb881ddf4fb8fc1020cf83', :rvalue => true},
  {:name => :notice,           :args => '"consider yourself under notice"',  :lambda => nil, :expected => 'consider yourself under notice', :rvalue => false},
  {:name => :realize,          :args => 'User[arya]',                        :lambda => nil, :expected => '', :rvalue => false},  # TODO: create a virtual first
  {:name => :regsubst,         :args => '"Cersei","Cer(\\w)ei","Daenery\\1"',:lambda => nil, :expected => 'Daenerys', :rvalue => true},
  # explicitly called in call_em_all; implicitly called by the include above
  #{:name => :require,          :args => '[4,5,6]',                          :lambda => nil, :expected => '', :rvalue => true},
  {:name => :scanf,            :args => '"Eddard Stark","%6s"',              :lambda => nil, :expected => 'Eddard', :rvalue => true},
  {:name => :sha1,             :args => '"Sansa"',                           :lambda => nil, :expected => '4337ce5e4095e565d51e0ef4c80df1fecf238b29', :rvalue => true},
  {:name => :shellquote,       :args => '["-1", "--two"]',                   :lambda => nil, :expected => '-1 --two', :rvalue => true},
  {:name => :split,            :args => '"9,8,7",","',                       :lambda => nil, :expected => '9 8 7', :rvalue => true},
  {:name => :sprintf,          :args => '"%b","123"',                        :lambda => nil, :expected => '1111011', :rvalue => true},
  # explicitly called in call_em_all
  #{:name => :tag,              :args => '[4,5,6]',                          :lambda => nil, :expected => '', :rvalue => true},
  {:name => :tagged,           :args => '"yer_it"',                          :lambda => nil, :expected => 'false', :rvalue => true},
  {:name => :template,         :args => '"call_em_all/template.erb"',        :lambda => nil, :expected => 'no defaultsno space', :rvalue => true},
  {:name => :versioncmp,       :args => '"1","2"',                           :lambda => nil, :expected => '-1', :rvalue => true},
  {:name => :warning,          :args => '"consider yourself warned"',        :lambda => nil, :expected => 'consider yourself warned', :rvalue => false},
  # do this one last or it will not allow the others to run.
  {:name => :fail,             :args => '"Jon Snow"',                        :lambda => nil, :expected => 'Error: Jon Snow', :rvalue => false},
]


functions_4x = [
  {:name => :assert_type,      :args => '"String[1]", "Valar morghulis"',    :lambda => nil, :expected => 'Valar morghulis', :rvalue => true},
  {:name => :each,             :args => '[1,2,3]',                           :lambda => '|$x| {notice $x}', :expected => '[1, 2, 3]', :rvalue => true},
  {:name => :epp,              :args => '"call_em_all/template.epp",{x=>droid}', :lambda => nil, :expected => 'This is the droid you are looking for!', :rvalue => true},
  {:name => :filter,           :args => '[4,5,6]',                           :lambda => '|$x| {true}', :expected => '[4, 5, 6]', :rvalue => true},
  {:name => :inline_epp,       :args => '\'<%= $x %>\',{x=>10}',             :lambda => nil, :expected => '10', :rvalue => true},
  {:name => :map,              :args => '[7,8,9]',                           :lambda => '|$x| {notice $x}', :expected => '[7, 8, 9]', :rvalue => true},
  {:name => :match,            :args => '"abc", /b/',                        :lambda => nil, :expected => '[b]', :rvalue => true},
  {:name => :reduce,           :args => '[4,5,6]',                           :lambda => '|$sum, $n| { $sum+$n }', :expected => '15', :rvalue => true},
  #         :reuse,:recycle
  {:name => :slice,            :args => '[1,2,3,4,5,6], 2',                  :lambda => nil, :expected => '[[1, 2], [3, 4], [5, 6]]', :rvalue => true},
  {:name => :with,             :args => '1, "Catelyn"',                      :lambda => '|$x| {notice $x}', :expected => '1', :rvalue => true},
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

# create single manifest calling all functions
step 'Apply manifest containing all function calls'
def manifest_call_each_function_from_array(functions)
  manifest = ''
  # use index to work around puppet's imutable variables
  # use variables so we can contatenate strings
  functions.each_with_index do |function,index|
    if function[:rvalue]
      manifest << "notice #{function[:name]}(#{function[:args]}) #{function[:lambda]}\n"
    else
      manifest << "#{function[:name]}(#{function[:args]}) #{function[:lambda]}\n"
    end
  end
  manifest
end

agents.each do |agent|
  # apply the setup manifest
  apply_manifest_on(agent, module_manifest, :catch_failures => true)

  # apply the 4x function manifest with future parser
  apply_manifest_on(agent, manifest_call_each_function_from_array(functions_4x),
                    {:modulepath => "#{testdir}/environments/production/modules/",
                     :future_parser => true,
                     :acceptable_exit_codes => 1} ) do |result|
    functions_4x.each do |function|
      assert_match(function[:expected], result.output, "#{function[:name]} output didn't match expected value")
    end
  end

  # apply the 3x function manifest with current parser
  # do these after the 4x functions because they include a call to fail, which errors out!
  apply_manifest_on(agent, manifest_call_each_function_from_array(functions_3x),
                    {:modulepath => "#{testdir}/environments/production/modules/",
                     :acceptable_exit_codes => 1} ) do |result|
    functions_3x.each do |function|
      assert_match(function[:expected], result.output, "#{function[:name]} output didn't match expected value")
    end
  end
end
