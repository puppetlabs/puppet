#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/package/ports'
require 'puppet/util/package/ports/functions'
require 'puppet/util/package/ports/port_record'
require 'puppet/util/package/ports/port_search'


describe Puppet::Util::Package::Ports::PortSearch do
  let(:test_class) do
    Class.new do
      extend Puppet::Util::Package::Ports::PortSearch
      def self.to_s; 'Pupept::Util::Package::Ports::PortSearchTest'; end
      def self.command(what)
        if what == :portversion
          '/usr/local/sbin/portversion'
        else
          what
        end
      end
    end
  end

  version_pattern = '[a-zA-Z0-9][a-zA-Z0-9\\.,_]*'

  it { test_class.should be_a Puppet::Util::Package::Ports::Functions }

  describe "#search_ports(names,fields=PORT_SEARCH_FIELDS,options={})" do
    existing_ports = [
      {
        :portorigin => 'www/apache22',
        :pkgname => 'apache22-2.2.26',
        :portname => 'apache22',
        :path => '/usr/ports/www/apache22'
      },
      {
        :portorigin => 'lang/php5',
        :pkgname => 'php5-5.4.21',
        :portname => 'php5',
        :path => '/usr/ports/lang/php5'
      }
    ]
    ###
    [
      # 1.
      [
        'www/apache22', [:portorigin],
        [
          [
            'www/apache22',
            Puppet::Util::Package::Ports::PortRecord[{
              :portorigin => 'www/apache22',
            }]
          ]
        ],
      ],
      # 2.
      [
        'apache22', [:portname],
        [
          [
            'apache22',
            Puppet::Util::Package::Ports::PortRecord[{
              :portname => 'apache22',
            }]
          ]
        ],
      ],
      # 3.
      [
        'apache22-2.2.26', [:pkgname],
        [
          [
            'apache22-2.2.26',
            Puppet::Util::Package::Ports::PortRecord[{
              :pkgname=> 'apache22-2.2.26',
            }]
          ]
        ],
      ],
      # 4.
      [
        ['apache22', 'lang/php5' ], [:pkgname, :portorigin],
        [
          [
            'lang/php5',
            Puppet::Util::Package::Ports::PortRecord[{
              :pkgname=> 'php5-5.4.21',
              :portorigin => 'lang/php5'
            }]
          ],
          [
            'apache22',
            Puppet::Util::Package::Ports::PortRecord[{
              :pkgname=> 'apache22-2.2.26',
              :portorigin => 'www/apache22'
            }]
          ]
        ],
      ],
    ].each do |names,fields,result|
      context "#search_ports(#{names.inspect},#{fields.inspect})" do
        let(:names) { names }
        let(:fields) { fields }
        let(:result) { result }
        let(:existing_ports) { existing_ports }
        it do

          if (not names.is_a?(Enumerable)) or names.instance_of?(String)
            names = [names]
          end

          origins = names.select{|name| test_class.portorigin?(name)}
          pkg_or_port_names = names - origins

          ports_by_portorigin = []
          existing_ports.each do |port|
            if origins.include?(port[:portorigin])
              pkg_or_port_names.delete(port[:pkgname])
              pkg_or_port_names.delete(port[:portname])
              rec = port.dup
              rec.delete_if { |key,val| not fields.include?(key) }
              ports_by_portorigin << [port[:portorigin],rec]
            end
          end
          test_class.stubs(:search_ports_by).
            with(:portorigin,origins,fields,{}).
              multiple_yields(*ports_by_portorigin)

          portnames = pkg_or_port_names.dup
          ports_by_pkgname = []
          existing_ports.each do |port|
            if pkg_or_port_names.include?(port[:pkgname])
              rec = port.dup
              portnames.delete(port[:pkgname])
              portnames.delete(port[:portname])
              rec.delete_if { |key,val| not fields.include?(key) }
              ports_by_pkgname << [port[:pkgname],rec]
            end
          end
          test_class.stubs(:search_ports_by).
            with(:pkgname,pkg_or_port_names,fields,{}).
              multiple_yields(*ports_by_pkgname)

          ports_by_portname = []
          existing_ports.each do |port|
            if portnames.include?(port[:portname])
              rec = port.dup
              rec.delete_if { |key,val| not fields.include?(key) }
              ports_by_portname << [port[:portname],rec]
            end
          end
          test_class.stubs(:search_ports_by).
            with(:portname,portnames,fields,{}).
              multiple_yields(*ports_by_portname)

          expect { |b|
            test_class.search_ports(names,fields,&b)
          }.to yield_successive_args(*result)
        end
      end
    end
  end

  # note, this test does not involve slices.
  describe "#search_ports_by(key, keyvals, fields=PORT_SEARCH_FIELDS, options={})" do
    [
      # 1.
      [
        :name, 'apache22-2.2.26', [:pkgname, :portorigin, :options_file],
        :name, '^(apache22-2\\.2\\.26)$',
        [
          {
            :name => 'apache22-2.2.26',
            :pkgname => 'apache22-2.2.26',
            :portorigin => 'www/apache22',
            :options_file => '/var/db/ports/www_apache22/options.local'
          }
        ],
        [
          [
            'apache22-2.2.26',
            {
              :pkgname => 'apache22-2.2.26',
              :portorigin => 'www/apache22',
              :options_file => '/var/db/ports/www_apache22/options.local'
            }
          ]
        ]
      ],
      # 2.
      [
        :pkgname, 'apache22-2.2.26', [:pkgname, :portorigin, :options_file],
        :name, '^(apache22-2\\.2\\.26)$',
        [
          {
            :pkgname => 'apache22-2.2.26',
            :portorigin => 'www/apache22',
            :options_file => '/var/db/ports/www_apache22/options.local'
          }
        ],
        [
          [
            'apache22-2.2.26',
            {
              :pkgname => 'apache22-2.2.26',
              :portorigin => 'www/apache22',
              :options_file => '/var/db/ports/www_apache22/options.local'
            }
          ]
        ]
      ],
      # 3.
      [
        :portname, 'apache22', [:pkgname, :portorigin, :options_file],
        :name, "^(apache22)-#{version_pattern}$",
        [
          {
            :portname=> 'apache22',
            :pkgname => 'apache22-2.2.26',
            :portorigin => 'www/apache22',
            :options_file => '/var/db/ports/www_apache22/options.local'
          }
        ],
        [
          [
            'apache22',
            {
              :pkgname => 'apache22-2.2.26',
              :portorigin => 'www/apache22',
              :options_file => '/var/db/ports/www_apache22/options.local'
            }
          ]
        ]
      ],
      # 4.
      [
        :portorigin, 'www/apache22', [:pkgname, :options_file],
        :path, '^/usr/ports/(www/apache22)$',
        [
          {
            :portorigin => 'www/apache22',
            :pkgname => 'apache22-2.2.26',
            :options_file => '/var/db/ports/www_apache22/options.local',
          }
        ],
        [
          [
            'www/apache22',
            {
              :pkgname => 'apache22-2.2.26',
              :options_file => '/var/db/ports/www_apache22/options.local'
            }
          ]
        ]
      ],
      # 5.
      [
        :path, '/usr/ports/www/apache22', [:pkgname, :options_file],
        :path, '^(/usr/ports/www/apache22)$',
        [
          {
            :path=> '/usr/ports/www/apache22',
            :pkgname => 'apache22-2.2.26',
            :options_file => '/var/db/ports/www_apache22/options.local'
          }
        ],
        [
          [
            '/usr/ports/www/apache22',
            {
              :pkgname => 'apache22-2.2.26',
              :options_file => '/var/db/ports/www_apache22/options.local'
            }
          ]
        ]
      ],
      # 6.
      [
        :portname, ['apache22', 'php5'], [:pkgname, :portorigin, :options_file],
        :name, "^(apache22|php5)-#{version_pattern}$",
        [
          Puppet::Util::Package::Ports::PortRecord[{
            :portname => 'apache22',
            :pkgname => 'apache22-2.2.26',
            :portorigin => 'www/apache22',
            :options_file => '/var/db/ports/www_apache22/options.local'
          }],
          Puppet::Util::Package::Ports::PortRecord[{
            :portname => 'php5',
            :pkgname => 'php5-5.4.21',
            :portorigin => 'lang/php5',
            :options_file => '/var/db/ports/lang_php5/options.local'
          }],
        ],
        [
          [
            'apache22',
            Puppet::Util::Package::Ports::PortRecord[{
              :pkgname => 'apache22-2.2.26',
              :portorigin => 'www/apache22',
              :options_file => '/var/db/ports/www_apache22/options.local'
            }]
          ],
          [
            'php5',
            Puppet::Util::Package::Ports::PortRecord[{
              :pkgname => 'php5-5.4.21',
              :portorigin => 'lang/php5',
              :options_file => '/var/db/ports/lang_php5/options.local'
            }]
          ]
        ]
      ]
    ].each do |key, names, fields, search_key, pattern, output, result|
      context "#search_ports_by(#{key.inspect},#{names.inspect},#{fields.inspect})" do
        let(:key) { key }
        let(:names) { names }
        let(:fields) { fields }
        let(:pattern) { pattern }
        let(:output) { output }
        let(:result) { result }
        it do
          names = [names] if names.instance_of?(String)
          output = output.collect {|o| [o]} # needed by multiple_yields
          test_class.stubs(:execute_make_search).with(search_key,pattern,fields,{}).
            multiple_yields(*output)
          expect { |b|
            test_class.search_ports_by(key,names,fields,&b)
          }.to yield_successive_args(*result)
        end
      end
    end
  end

  describe "#execute_make_search(key,pattern,fields=PORT_SEARCH_FIELDS,options={})" do
    context "#execute_make_search(:baz,'foo')" do
      before(:each) { Puppet::Util::Execution.stubs(:execpipe) }
      it do
        expect {
          test_class.execute_make_search(:baz,'foo')
        }.to raise_error ArgumentError, "Invalid search key baz"
      end
    end
    [
      # 1.
      [
        :name, '^apache22-2.2.26$', [:name,:path,:info,:maint,:www],
        [
          'Port:   apache22-2.2.26',
          'Path:   /usr/ports/www/apache22',
          'Info:   Version 2.2.x of Apache web server with prefork MPM.',
          'Maint:  apache@FreeBSD.org',
          'B-deps: apr-1.4.8.1.5.3 autoconf-2.69 autoconf-wrapper-20130530',
          'R-deps: apr-1.4.8.1.5.3 db42-4.2.52_5 expat-2.1.0 gdbm-1.10',
          'WWW:    http://httpd.apache.org/'
        ].join("\n"),
        [
          {
            :name => 'apache22-2.2.26',
            :path => '/usr/ports/www/apache22',
            :info => 'Version 2.2.x of Apache web server with prefork MPM.',
            :maint => 'apache@FreeBSD.org',
            :www => 'http://httpd.apache.org/'
          }
        ]
      ],
      # 2.
      [
        :name,
        "^(apache22|apache22-event-mpm)-#{version_pattern}$",
        [:pkgname, :portorigin, :options_file],
        [
          'Port:   apache22-2.2.26',
          'Path:   /usr/ports/www/apache22',
          'Info:   Version 2.2.x of Apache web server with prefork MPM.',
          'Maint:  apache@FreeBSD.org',
          'B-deps: apr-1.4.8.1.5.3 autoconf-2.69 autoconf-wrapper-20130530',
          'R-deps: apr-1.4.8.1.5.3 db42-4.2.52_5 expat-2.1.0 gdbm-1.10',
          'WWW:    http://httpd.apache.org/',
          '',
          'Port:   apache22-event-mpm-2.2.26',
          'Path:   /usr/ports/www/apache22-event-mpm',
          'Info:   Version 2.2.x of Apache web server with event MPM.',
          'Maint:  apache@FreeBSD.org',
          'B-deps: apr-1.4.8.1.5.3 autoconf-2.69 autoconf-wrapper-20130530',
          'R-deps: apr-1.4.8.1.5.3 db42-4.2.52_5 expat-2.1.0 gdbm-1.1',
          'WWW:    http://httpd.apache.org/',
          ''
        ].join("\n"),
        [
          {
            :pkgname => 'apache22-2.2.26',
            :portorigin => 'www/apache22',
            :options_file => '/var/db/ports/www_apache22/options.local'
          },
          {
            :pkgname => 'apache22-event-mpm-2.2.26',
            :portorigin => 'www/apache22-event-mpm',
            :options_file => '/var/db/ports/www_apache22-event-mpm/options.local'
          },
        ]
      ]
    ].each do |key,pattern,fields,output,result|
      context "#execute_make_search(#{key.inspect},#{pattern.inspect},#{fields.inspect})" do
        let(:key) { key }
        let(:pattern) { pattern }
        let(:fields) { fields }
        let(:output) { output }
        let(:result) { result }
        it do
          record_class = Puppet::Util::Package::Ports::PortRecord
          search_fields = record_class.determine_search_fields(fields,key)
          cmd = test_class.make_search_command(key, pattern,search_fields,{})
          Puppet::Util::Execution.stubs(:execpipe).with(cmd).yields(output)
          expect { |b|
            test_class.execute_make_search(key,pattern,fields,&b)
          }.to yield_successive_args(*result)
        end
      end
    end
  end
end
