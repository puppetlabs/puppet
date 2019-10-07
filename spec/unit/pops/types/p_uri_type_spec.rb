require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'URI type' do
  context 'when used in Puppet expressions' do
    include PuppetSpec::Compiler
    it 'is equal to itself only' do
      expect(eval_and_collect_notices(<<-CODE)).to eq(%w(true true false false))
          $t = URI
          notice(URI =~ Type[URI])
          notice(URI == URI)
          notice(URI < URI)
          notice(URI > URI)
      CODE
    end

    context "when parameterized" do
      it 'is equal other types with the same parameterization' do
        code = <<-CODE
            notice(URI == URI[{}])
            notice(URI['http://example.com'] == URI[scheme => http, host => 'example.com'])
            notice(URI['urn:a:b:c'] == URI[scheme => urn, opaque => 'a:b:c'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true true true))
      end

      it 'is assignable from more qualified types' do
        expect(eval_and_collect_notices(<<-CODE)).to eq(%w(true true true))
          notice(URI > URI['http://example.com'])
          notice(URI['http://example.com'] > URI['http://example.com/path'])
          notice(URI[scheme => Enum[http, https]] > URI['http://example.com'])
        CODE
      end

      it 'is not assignable unless scheme is assignable' do
        expect(eval_and_collect_notices(<<-CODE)).to eq(%w(false))
          notice(URI[scheme => Enum[http, https]] > URI[scheme => 'ftp'])
        CODE
      end

      it 'presents parsable string form' do
        code = <<-CODE
          notice(URI['https://user:password@www.example.com:3000/some/path?x=y#frag'])
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "URI[{'scheme' => 'https', 'userinfo' => 'user:password', 'host' => 'www.example.com', 'port' => '3000', 'path' => '/some/path', 'query' => 'x=y', 'fragment' => 'frag'}]",
        ])
      end
    end

    context 'a URI instance' do
      it 'can be created from a string' do
        code = <<-CODE
            $o = URI('https://example.com/a/b')
            notice(String($o, '%p'))
            notice(type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "URI('https://example.com/a/b')",
          "URI[{'scheme' => 'https', 'host' => 'example.com', 'path' => '/a/b'}]"
        ])
      end

      it 'which is opaque, can be created from a string' do
        code = <<-CODE
            $o = URI('urn:a:b:c')
            notice(String($o, '%p'))
            notice(type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "URI('urn:a:b:c')",
          "URI[{'scheme' => 'urn', 'opaque' => 'a:b:c'}]"
        ])
      end

      it 'can be created from a hash' do
        code = <<-CODE
            $o = URI(scheme => 'https', host => 'example.com', path => '/a/b')
            notice(String($o, '%p'))
            notice(type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "URI('https://example.com/a/b')",
          "URI[{'scheme' => 'https', 'host' => 'example.com', 'path' => '/a/b'}]"
        ])
      end

      it 'which is opaque, can be created from a hash' do
        code = <<-CODE
            $o = URI(scheme => 'urn', opaque => 'a:b:c')
            notice(String($o, '%p'))
            notice(type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "URI('urn:a:b:c')",
          "URI[{'scheme' => 'urn', 'opaque' => 'a:b:c'}]"
        ])
      end

      it 'is an instance of its type' do
        code = <<-CODE
            $o = URI('https://example.com/a/b')
            notice($o =~ type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true'])
      end

      it 'is an instance of matching parameterized URI' do
        code = <<-CODE
            $o = URI('https://example.com/a/b')
            notice($o =~ URI[scheme => https, host => 'example.com'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true'])
      end

      it 'is an instance of matching default URI' do
        code = <<-CODE
            $o = URI('https://example.com/a/b')
            notice($o =~ URI)
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true'])
      end

      it 'path is not matched by opaque' do
        code = <<-CODE
            $o = URI('urn:a:b:c')
            notice($o =~ URI[path => 'a:b:c'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['false'])
      end

      it 'opaque is not matched by path' do
        code = <<-CODE
            $o = URI('https://example.com/a/b')
            notice($o =~ URI[opaque => '/a/b'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['false'])
      end

      it 'is not an instance unless parameters matches' do
        code = <<-CODE
            $o = URI('https://example.com/a/b')
            notice($o =~ URI[scheme => http])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['false'])
      end

      it 'individual parts of URI can be accessed using accessor methods' do
        code = <<-CODE
            $o = URI('https://bob:pw@example.com:8080/a/b?a=b#frag')
            notice($o.scheme)
            notice($o.userinfo)
            notice($o.host)
            notice($o.port)
            notice($o.path)
            notice($o.query)
            notice($o.fragment)
        CODE
        expect(eval_and_collect_notices(code)).to eq(['https', 'bob:pw', 'example.com', '8080', '/a/b', 'a=b', 'frag'])
      end

      it 'individual parts of opaque URI can be accessed using accessor methods' do
        code = <<-CODE
            $o = URI('urn:a:b:c')
            notice($o.scheme)
            notice($o.opaque)
        CODE
        expect(eval_and_collect_notices(code)).to eq(['urn', 'a:b:c'])
      end

      it 'An URI can be merged with a String using the + operator' do
        code = <<-CODE
          notice(String(URI('https://example.com') + '/a/b', '%p'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(["URI('https://example.com/a/b')"])
      end

      it 'An URI can be merged with another URI using the + operator' do
        code = <<-CODE
          notice(String(URI('https://example.com') + URI('/a/b'), '%p'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(["URI('https://example.com/a/b')"])
      end
    end
  end
end
end
end
