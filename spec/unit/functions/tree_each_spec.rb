require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'shared_behaviours/iterative_functions'

describe 'the tree_each function' do
  include PuppetSpec::Compiler

  context "can be called on" do
    it 'an Array, yielding path and value when lambda has arity 2' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each() |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: [] value: [1, 2, 3]',
          'path: [0] value: 1',
          'path: [1] value: 2',
          'path: [2] value: 3',
          ''
          ].join("\n"))
    end

    it 'an Array, yielding only value  when lambda has arity 1' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each() | $v| { -%>
          path: - value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: - value: [1, 2, 3]',
          'path: - value: 1',
          'path: - value: 2',
          'path: - value: 3',
          ''
          ].join("\n"))
    end

    it 'a Hash, yielding path and value when lambda has arity 2' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>'apple','b'=>'banana'}
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each() |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: [] value: {a => apple, b => banana}',
          'path: [a] value: apple',
          'path: [b] value: banana',
          ''
          ].join("\n"))
    end

    it 'a Hash, yielding only value when lambda has arity 1' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>'apple','b'=>'banana'}
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each() | $v| { -%>
          path: - value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: - value: {a => apple, b => banana}',
          'path: - value: apple',
          'path: - value: banana',
          ''
          ].join("\n"))
    end

    it 'an Object, yielding path and value when lambda has arity 2' do
      # this also tests that include_refs => true includes references
      catalog = compile_to_catalog(<<-MANIFEST)
        type Person = Object[{attributes => {
          name => String,
          father => Optional[Person],
          mother => { kind => reference, type => Optional[Person] }
        }}]
        $adam  = Person({name => 'Adam'})
        $eve   = Person({name => 'Eve'})
        $cain  = Person({name => 'Cain',  mother => $eve,  father => $adam})
        $awan  = Person({name => 'Awan',  mother => $eve,  father => $adam})
        $enoch = Person({name => 'Enoch', mother => $awan, father => $cain})

        $msg = inline_epp(@(TEMPLATE))
          <% $enoch.tree_each({include_containers=>false, include_refs => true}) |$path, $v| { unless $v =~ Undef {-%>
          path: <%= $path %> value: <%= $v %>
          <% }} -%>
          | TEMPLATE
        notify {'with_refs': message => $msg}

      MANIFEST

      expect(catalog.resource(:notify, 'with_refs')['message']).to eq(
        [
          'path: [name] value: Enoch',
          'path: [father, name] value: Cain',
          'path: [father, father, name] value: Adam',
          'path: [father, mother, name] value: Eve',
          'path: [mother, name] value: Awan',
          'path: [mother, father, name] value: Adam',
          'path: [mother, mother, name] value: Eve',
          ''
          ].join("\n"))
    end
  end

  context 'a yielded path' do
    it 'holds integer values for Array index at each level' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3]]]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each() |$path, $v| { -%>
          path: <%= $path %> t: <%= $path.map |$x| { type($x, generalized) } %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: [] t: [] value: [1, [2, [3]]]',
          'path: [0] t: [Integer] value: 1',
          'path: [1] t: [Integer] value: [2, [3]]',
          'path: [1, 0] t: [Integer, Integer] value: 2',
          'path: [1, 1] t: [Integer, Integer] value: [3]',
          'path: [1, 1, 0] t: [Integer, Integer, Integer] value: 3',
          ''
          ].join("\n"))
    end

    it 'holds Any values for Hash keys at each level' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {a => 1, /fancy/=> {c => 2, d=>{[e] => 3}}}
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each() |$path, $v| { -%>
          path: <%= $path %> t: <%= $path.map |$x| { type($x, generalized) } %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: [] t: [] value: {a => 1, /fancy/ => {c => 2, d => {[e] => 3}}}',
          'path: [a] t: [String] value: 1',
          'path: [/fancy/] t: [Regexp[/fancy/]] value: {c => 2, d => {[e] => 3}}',
          'path: [/fancy/, c] t: [Regexp[/fancy/], String] value: 2',
          'path: [/fancy/, d] t: [Regexp[/fancy/], String] value: {[e] => 3}',
          'path: [/fancy/, d, [e]] t: [Regexp[/fancy/], String, Array[String]] value: 3',
          ''
          ].join("\n"))
    end
  end

  it 'errors when asked to operate on a String' do
    expect {
      compile_to_catalog(<<-MANIFEST)
      "hello".tree_each() |$path, $v| {
        notice "$v"
      }
    MANIFEST
    }.to raise_error(/expects a value of type Iterator, Array, Hash, or Object/)
  end

  context 'produces' do
    it 'the receiver when given a lambda' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, 3, 2]
        $b = $a.tree_each |$path, $x| { "unwanted" }
        file { "/file_${b[1]}":
          ensure => present
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_3")['ensure']).to eq('present')
    end

    it 'an Iterator when not given a lambda' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, 3, 2]
        $b = $a.tree_each
        file { "/file_${$b =~ Iterator}":
          ensure => present
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_true")['ensure']).to eq('present')
    end
  end

  context 'a produced iterator' do
    ['depth_first', 'breadth_first'].each do |order|
      context "for #{order} can be unrolled by creating an Array using" do
        it "the () operator" do
          catalog = compile_to_catalog(<<-MANIFEST)
            $a = [1, 3, 2]
            $b = Array($a.tree_each({order => #{order}}))
            $msg = inline_epp(@(TEMPLATE))
              <% $b.each() |$v| { -%>
              path: <%= $v[0] %> value: <%= $v[1] %>
              <% } -%>
              | TEMPLATE
            notify {'test': message => $msg}
          MANIFEST

          expect(catalog.resource(:notify, "test")['message']).to eq([
            'path: [] value: [1, 3, 2]',
            'path: [0] value: 1',
            'path: [1] value: 3',
            'path: [2] value: 2',
            ''
            ].join("\n"))
        end

        it "the splat operator" do
          catalog = compile_to_catalog(<<-MANIFEST)
            $a = [1, 3, 2]
            $b = *$a.tree_each({order => #{order}})
            assert_type(Array[Array], $b)
            $msg = inline_epp(@(TEMPLATE))
              <% $b.each() |$v| { -%>
              path: <%= $v[0] %> value: <%= $v[1] %>
              <% } -%>
              | TEMPLATE
            notify {'test': message => $msg}
          MANIFEST

          expect(catalog.resource(:notify, "test")['message']).to eq([
            'path: [] value: [1, 3, 2]',
            'path: [0] value: 1',
            'path: [1] value: 3',
            'path: [2] value: 2',
            ''
            ].join("\n"))
        end
      end
    end
  end

  context 'recursively yields under the control of options such that' do
    it 'both containers and leafs are included by default' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3]]]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each() |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: [] value: [1, [2, [3]]]',
          'path: [0] value: 1',
          'path: [1] value: [2, [3]]',
          'path: [1, 0] value: 2',
          'path: [1, 1] value: [3]',
          'path: [1, 1, 0] value: 3',
          ''
          ].join("\n"))
    end

    it 'containers are skipped when option include_containers=false is used' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3]]]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each({include_containers => false}) |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 
          'path: [0] value: 1',
          'path: [1, 0] value: 2',
          'path: [1, 1, 0] value: 3',
          ''
          ].join("\n"))
    end

    it 'values are skipped when option include_values=false is used' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3]]]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each({include_values => false}) |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: [] value: [1, [2, [3]]]',
          'path: [1] value: [2, [3]]',
          'path: [1, 1] value: [3]',
          ''
          ].join("\n"))
    end

    it 'the root container is skipped when option include_root=false is used' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3]]]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each({include_root => false, include_values => false}) |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 'path: [1] value: [2, [3]]',
          'path: [1, 1] value: [3]',
          ''
          ].join("\n"))
    end

    it 'containers must be included for root to be included' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3]]]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each({include_containers => false, include_root => true}) |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [ 
          'path: [0] value: 1',
          'path: [1, 0] value: 2',
          'path: [1, 1, 0] value: 3',
          ''
          ].join("\n"))
    end

    it 'errors when asked to exclude both containers and values' do
      expect {
        compile_to_catalog(<<-MANIFEST)
          [1,2,3].tree_each({include_containers => false, include_values => false}) |$path, $v| {
          notice "$v"
        }
      MANIFEST
      }.to raise_error(/Options 'include_containers' and 'include_values' cannot both be false/)
    end

    it 'tree nodes are yielded in depth first order if option order=depth_first' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3], 4], 5]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each({order => depth_first, include_containers => false}) |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [
          'path: [0] value: 1',
          'path: [1, 0] value: 2',
          'path: [1, 1, 0] value: 3',
          'path: [1, 2] value: 4',
          'path: [2] value: 5',
          ''
          ].join("\n"))
    end

    it 'tree nodes are yielded in breadth first order if option order=breadth_first' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3], 4], 5]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each({order => breadth_first, include_containers => false}) |$path, $v| { -%>
          path: <%= $path %> value: <%= $v %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [
          'path: [0] value: 1',
          'path: [2] value: 5',
          'path: [1, 0] value: 2',
          'path: [1, 2] value: 4',
          'path: [1, 1, 0] value: 3',
          ''
          ].join("\n"))
    end

    it 'attributes of an Object of "reference" kind are not yielded by default' do
      catalog = compile_to_catalog(<<-MANIFEST)
        type Person = Object[{attributes => {
          name => String,
          father => Optional[Person],
          mother => { kind => reference, type => Optional[Person] }
        }}]
        $adam  = Person({name => 'Adam'})
        $eve   = Person({name => 'Eve'})
        $cain  = Person({name => 'Cain',  mother => $eve,  father => $adam})
        $awan  = Person({name => 'Awan',  mother => $eve,  father => $adam})
        $enoch = Person({name => 'Enoch', mother => $awan, father => $cain})

        $msg = inline_epp(@(TEMPLATE))
          <% $enoch.tree_each({include_containers=>false }) |$path, $v| { unless $v =~ Undef {-%>
          path: <%= $path %> value: <%= $v %>
          <% }} -%>
          | TEMPLATE
        notify {'by_default': message => $msg}

        $msg2 = inline_epp(@(TEMPLATE))
          <% $enoch.tree_each({include_containers=>false, include_refs => false}) |$path, $v| { unless $v =~ Undef {-%>
          path: <%= $path %> value: <%= $v %>
          <% }} -%>
          | TEMPLATE
        notify {'when_false': message => $msg2}

      MANIFEST

      expected_refs_excluded_result = [
        'path: [name] value: Enoch',
        'path: [father, name] value: Cain',
        'path: [father, father, name] value: Adam',
        ''
        ].join("\n")

      expect(catalog.resource(:notify, 'by_default')['message']).to eq(expected_refs_excluded_result)
      expect(catalog.resource(:notify, 'when_false')['message']).to eq(expected_refs_excluded_result)
    end
  end

  context 'can be chained' do
    it 'with reverse_each()' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3]]]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each({include_containers => false}).reverse_each |$v| { -%>
          path: <%= $v[0] %> value: <%= $v[1] %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [
          'path: [1, 1, 0] value: 3',
          'path: [1, 0] value: 2',
          'path: [0] value: 1',
          ''
          ].join("\n"))
    end

    it 'with step()' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,[2,[3,[4,[5]]]]]
        $msg = inline_epp(@(TEMPLATE))
          <% $a.tree_each({include_containers => false}).step(2) |$v| { -%>
          path: <%= $v[0] %> value: <%= $v[1] %>
          <% } -%>
          | TEMPLATE
        notify {'test': message => $msg}
      MANIFEST

      expect(catalog.resource(:notify, 'test')['message']).to eq(
        [
          'path: [0] value: 1',
          'path: [1, 1, 0] value: 3',
          'path: [1, 1, 1, 1, 0] value: 5',
          ''
          ].join("\n"))
    end
  end
end
