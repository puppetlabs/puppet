#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/package/ports'
require 'puppet/util/package/ports/functions'
require 'puppet/util/package/ports/pkg_record'
require 'puppet/util/package/ports/pkg_search'


describe Puppet::Util::Package::Ports::PkgSearch do
  let(:test_class) do
    Class.new do
      extend Puppet::Util::Package::Ports::PkgSearch
      def self.to_s; 'Pupept::Util::Package::Ports::PkgSearchTest'; end
      def self.command(what)
        if what == :portversion
          '/usr/local/sbin/portversion'
        else
          what
        end
      end
    end
  end

  PkgRecord = Puppet::Util::Package::Ports::PkgRecord

  version_pattern = '[a-zA-Z0-9][a-zA-Z0-9\\.,_]*'

  it { test_class.should be_a Puppet::Util::Package::Ports::Functions }

  describe "#search_packages(names,fields=PkgRecord.default_fields,options={})" do
    [
      # 1.
      [
        nil, [:pkgname, :portstatus, :portinfo], {},
        [
          ['apache22-2.2.26', 'www/apache22', "=", "up-to-date with ports"],
          ['rubygem-facter-1.6.18_2', 'sysutils/rubygem-facter', '<', 'needs updating (port has 1.7.3_1)']
        ],
        [
          PkgRecord[ {:pkgname => 'apache22-2.2.26', :portstatus => '=', :portinfo => 'up-to-date with ports'} ],
          PkgRecord[ {:pkgname => 'rubygem-facter-1.6.18_2', :portstatus => '<', :portinfo => 'needs updating (port has 1.7.3_1)'} ]
        ]
      ],
      # 2.
      [
        nil, [:portorigin, :portstatus, :portinfo], {},
        [
          ['apache22-2.2.26', 'www/apache22', "=", "up-to-date with ports"],
          ['rubygem-facter-1.6.18_2', 'sysutils/rubygem-facter', '<', 'needs updating (port has 1.7.3_1)']
        ],
        [
          PkgRecord[ {:portorigin => 'www/apache22', :portstatus => '=', :portinfo => 'up-to-date with ports'} ],
          PkgRecord[ {:portorigin => 'sysutils/rubygem-facter', :portstatus => '<', :portinfo => 'needs updating (port has 1.7.3_1)'} ]
        ]
      ],
      # 3.
      [
        nil, [:portorigin, :pkgname], {},
        [
          ['apache22-2.2.26', 'www/apache22', "=", "up-to-date with ports"],
          ['rubygem-facter-1.6.18_2', 'sysutils/rubygem-facter', '<', 'needs updating (port has 1.7.3_1)']
        ],
        [
          PkgRecord[ {:portorigin => 'www/apache22', :pkgname => 'apache22-2.2.26'} ],
          PkgRecord[ {:portorigin => 'sysutils/rubygem-facter', :pkgname => 'rubygem-facter-1.6.18_2' }]
        ]
      ],
      # 4.
      [
        ['apache22'], [:pkgname], {},
        [
          ['apache22-2.2.26', 'www/apache22', "=", "up-to-date with ports"]
        ],
        [
          ['apache22', PkgRecord[ {:pkgname => 'apache22-2.2.26'}]]
        ]
      ],
      # 5.
      [
        ['apache22', 'sysutils/rubygem-facter'], [:portorigin], {},
        [
          ['apache22-2.2.26', 'www/apache22', '=', 'up-to-date with ports'],
          ['rubygem-facter-1.6.18_2', 'sysutils/rubygem-facter', '<', 'needs updating (port has 1.7.3_1)']
        ],
        [
          ['apache22', PkgRecord[ {:portorigin => 'www/apache22'}]],
          ['sysutils/rubygem-facter', PkgRecord[ {:portorigin => 'sysutils/rubygem-facter'}]],
        ]
      ],
      # 6. (note the argument order w.r.t 5.)
      [
        ['sysutils/rubygem-facter', 'apache22'], [:portorigin], {},
        [
          ['apache22-2.2.26', 'www/apache22', '=', 'up-to-date with ports'],
          ['rubygem-facter-1.6.18_2', 'sysutils/rubygem-facter', '<', 'needs updating (port has 1.7.3_1)']
        ],
        [
          ['apache22', PkgRecord[ {:portorigin => 'www/apache22'}]],
          ['sysutils/rubygem-facter', PkgRecord[ {:portorigin => 'sysutils/rubygem-facter'}]],
        ]
      ],
      # 7.
      [
        ['apache22', 'sysutils/rubygem-facter'], [:pkgname, :portorigin], {},
        [
          ['apache22-2.2.26', 'www/apache22', '=', 'up-to-date with ports'],
          ['rubygem-facter-1.6.18_2', 'sysutils/rubygem-facter', '<', 'needs updating (port has 1.7.3_1)']
        ],
        [
          ['apache22', PkgRecord[ {:pkgname => 'apache22-2.2.26', :portorigin => 'www/apache22'}]],
          ['sysutils/rubygem-facter', PkgRecord[ {:pkgname => 'rubygem-facter-1.6.18_2', :portorigin => 'sysutils/rubygem-facter'}]],
        ]
      ],
      # 8.
      [
        ['ruby'], [:portorigin, :options_files, :options_file], {},
        [
          ['ruby-1.8.7.484,1', 'lang/ruby18', '=', 'up-to-date with ports'],
          ['ruby-1.9.3.484,1', 'lang/ruby19', '=', 'up-to-date with ports'],
        ],
        [
          [
            'ruby',
            PkgRecord[{
              :portorigin => 'lang/ruby18',
              :options_files => [
                '/var/db/ports/ruby/options',
                '/var/db/ports/ruby/options.local',
                '/var/db/ports/lang_ruby18/options',
                '/var/db/ports/lang_ruby18/options.local',
              ],
              :options_file => '/var/db/ports/lang_ruby18/options.local'
            }]
          ],
          [
            'ruby',
            PkgRecord[{
              :portorigin => 'lang/ruby19',
              :options_files => [
                '/var/db/ports/ruby/options',
                '/var/db/ports/ruby/options.local',
                '/var/db/ports/lang_ruby19/options',
                '/var/db/ports/lang_ruby19/options.local',
              ],
              :options_file => '/var/db/ports/lang_ruby19/options.local'
            }]
          ],
        ]
      ],
    ].each do |names,fields,options,output,result|
      context "#search_packages(#{names.inspect},#{fields.inspect},#{options.inspect})" do
        let(:names) { names }
        let(:out1) { output.collect { |o| [[o[0]] + o[2..3]] } }
        let(:out2) { output.collect { |o| [o[1..3]] } }
        let(:out3) { output.collect { |o| [[o[1]]] } }
        let(:result) { result }
        it {
          args = names  ? test_class.sort_names_for_portversion(names) : []
          test_class.stubs(:execute_portversion).with(%w{-v -F} + args, options).
            multiple_yields(*out1)
          test_class.stubs(:execute_portversion).with(%w{-v -o} + args, options).
            multiple_yields(*out2)
          test_class.stubs(:execute_portversion).with(%w{-Q -o} + args, options).
            multiple_yields(*out3)
          expect { |b|
            test_class.search_packages(names,fields,options,&b)
          }.to yield_successive_args(*result)
        }
      end
    end
  end

  describe "#portversion_search(names=nil,args=[],options={})" do
    [
      # 1.
      [
        ['php5'], [],
        [
          [
            ['/usr/local/sbin/portversion', 'php5'],
            'php5                        ='
          ]
        ],
        [
          [ 'php5', ['php5','='] ]
        ]
      ],
      # 2.
      [
        ['php5','openldap-client'], [],
        [
          [
            ['/usr/local/sbin/portversion', 'openldap-client', 'php5'],
            [
              'openldap-client             <',
              'php5                        ='
            ].join("\n")
          ]
        ],
        [
          [ 'openldap-client', ['openldap-client','<'] ],
          [ 'php5', ['php5','='] ]
        ]
      ],
      # 3.
      [
        ['php5','openldap-client','foobar'], [],
        [
          [
            ['/usr/local/sbin/portversion', 'foobar', 'openldap-client', 'php5'],
            [
              '** No matching package found: foobar',
              'openldap-client             <',
              'php5                        ='
            ].join("\n")
          ],
          [
            ['/usr/local/sbin/portversion', 'php5'],
            'php5                        ='
          ],
          [
            ['/usr/local/sbin/portversion', 'openldap-client'],
            'openldap-client             <'
          ],
          [
            ['/usr/local/sbin/portversion', 'foobar'],
            '** No matching package found: foobar'
          ]
        ],
        [
          [ 'openldap-client', ['openldap-client','<'] ],
          [ 'php5', ['php5','='] ]
        ]
      ],
      # 4.
      [
        ['lang/php5','net/openldap24-client'], [],
        [
          [
            ['/usr/local/sbin/portversion', 'net/openldap24-client', 'lang/php5'],
            [
              'openldap-client             <',
              'php5                        ='
            ].join("\n")
          ]
        ],
        [
          [ 'net/openldap24-client', ['openldap-client','<'] ],
          [ 'lang/php5', ['php5','='] ]
        ]
      ],
      # 5.
      [
        ['lang/php5','net/openldap24-client'], ['-F'],
        [
          [
            ['/usr/local/sbin/portversion', '-F', 'net/openldap24-client', 'lang/php5'],
            [
              'openldap-client-2.4.33      <',
              'php5-5.4.21                 ='
            ].join("\n")
          ]
        ],
        [
          [ 'net/openldap24-client', ['openldap-client-2.4.33','<'] ],
          [ 'lang/php5', ['php5-5.4.21','='] ]
        ]
      ],
      # 6.
      [
        ['php5','openldap-client'], ['-o'],
        [
          [
            ['/usr/local/sbin/portversion', '-o', 'openldap-client', 'php5'],
            [
              'net/openldap24-client       <',
              'lang/php5                   ='
            ].join("\n")
          ]
        ],
        [
          [ 'openldap-client', ['net/openldap24-client','<'] ],
          [ 'php5', ['lang/php5','='] ]
        ]
      ],
      # 7.
      [
        ['php5','openldap-client'], ['-v','-o'],
        [
          [
            ['/usr/local/sbin/portversion', '-v', '-o', 'openldap-client', 'php5'],
            [
              'net/openldap24-client       <  needs updating (port has 2.4.38)',
              'lang/php5                   =  up-to-date with port'

            ].join("\n")
          ]
        ],
        [
          [ 'openldap-client', ['net/openldap24-client','<','needs updating (port has 2.4.38)'] ],
          [ 'php5', ['lang/php5','=','up-to-date with port'] ]
        ]
      ],
      # 8.
      [
        nil, ['-v','-o'],
        [
          [
            ['/usr/local/sbin/portversion', '-v', '-o'],
            [
              'net/openldap24-client       <  needs updating (port has 2.4.38)',
              'lang/php5                   =  up-to-date with port'

            ].join("\n")
          ]
        ],
        [
          [ 'net/openldap24-client','<','needs updating (port has 2.4.38)' ],
          [ 'lang/php5','=','up-to-date with port' ]
        ]
      ]
    ].each do |names,args,cmds,result|
      context "#portversion_search(#{names.inspect},#{args.inspect})" do
        let(:names) {names}
        let(:args) { args }
        let(:cmds) { cmds }
        let(:result) { result }
        before do
          test_class.stubs(:command).with(:portversion).
            returns('/usr/local/sbin/portversion')
        end
        it do
          cmds.each do |cmd,output|
            Puppet::Util::Execution.stubs(:execpipe).with(cmd).yields(output)
          end
          expect { |b|
            test_class.portversion_search(names,args,&b)
          }.to yield_successive_args(*result)
        end
      end
    end
  end

  describe "#sort_names_for_portversion(names)" do
    [
      [
        [ 'apache22', 'ruby' ],
        [ 'apache22', 'ruby' ],
      ],
      [
        [ 'www/apache22', 'lang/ruby' ],
        [ 'www/apache22', 'lang/ruby' ],
      ],
      [
        [ 'ruby', 'apache22' ],
        [ 'apache22', 'ruby' ],
      ],
      [
        [ 'lang/ruby', 'www/apache22' ],
        [ 'www/apache22', 'lang/ruby' ],
      ],
      [
        [ 'ruby', 'www/apache22' ],
        [ 'www/apache22', 'ruby' ],
      ],
      [
        [ 'apache22', 'lang/ruby' ],
        [ 'apache22', 'lang/ruby' ],
      ],
    ].each do |names,result|
      context "#sort_names_for_portversion(#{names.inspect})" do
        let(:names) {names}
        let(:result) { result }
        it { test_class.sort_names_for_portversion(names).should == result }
      end
    end
  end

  describe "#execute_portversion(args,options={})" do
    [
      # 1.
      [
        ['-v', '-F'], {},
        ['/usr/local/sbin/portversion', '-v', '-F'],
        [
          'apache22-2.2.26            =   up-to-date with port',
          'openldap-client-2.4.33     <   needs updating (port has 2.4.38)',
        ].join("\n"),
        [
          ['apache22-2.2.26','=','up-to-date with port'],
          ['openldap-client-2.4.33','<','needs updating (port has 2.4.38)'],
        ]
      ],
      # 2.
      [
        ['-v', '-F', 'openldap-client', 'apache22', 'foobar-1.2.3'], {},
        ['/usr/local/sbin/portversion', '-v', '-F', 'openldap-client', 'apache22', 'foobar-1.2.3' ],
        [
          '** No matching package found: foobar-1.2.3',
          'apache22-2.2.26          =     up-to-date with port',
          'openldap-client-2.4.33   <     needs updating (port has 2.4.38)',
        ].join("\n"),
        [
          ['apache22-2.2.26','=','up-to-date with port'],
          ['openldap-client-2.4.33','<','needs updating (port has 2.4.38)']
        ]
      ]
    ].each do |args,options,cmd,output,result|
      context "#execute_portversion(#{args.inspect},#{options.inspect})" do
        let(:args) { args }
        let(:options) { options }
        let(:cmd) { cmd }
        let(:output) { output }
        let(:result) { result }
        it do
          Puppet::Util::Execution.stubs(:execpipe).with(cmd).
            multiple_yields(*output)
          expect { |b|
            test_class.execute_portversion(args,options,&b)
          }.to yield_successive_args(*result)
        end
      end
    end
  end

end
