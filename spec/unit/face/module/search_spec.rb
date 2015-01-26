require 'spec_helper'
require 'puppet/face'
require 'puppet/application/module'
require 'puppet/module_tool'

describe "puppet module search" do
  subject { Puppet::Face[:module, :current] }

  let(:options) do
    {}
  end

  describe Puppet::Application::Module do
    subject do
      app = Puppet::Application::Module.new
      app.stubs(:action).returns(Puppet::Face.find_action(:module, :search))
      app
    end

    before { subject.render_as = :console }
    before { Puppet::Util::Terminal.stubs(:width).returns(100) }

    it 'should output nothing when receiving an empty dataset' do
      expect(subject.render({:answers => [], :result => :success}, ['apache', {}])).to eq("No results found for 'apache'.")
    end

    it 'should return error and exit when error returned' do
      results = {
        :result => :failure,
        :error => {
          :oneline => 'Something failed',
          :multiline => 'Something failed',
        }
      }
      expect { subject.render(results, ['apache', {}]) }.to raise_error 'Something failed'
    end

    it 'should output a header when receiving a non-empty dataset' do
      results = {
        :result => :success,
        :answers => [
          {'full_name' => '', 'author' => '', 'desc' => '', 'tag_list' => [] },
        ],
      }

      expect(subject.render(results, ['apache', {}])).to match(/NAME/)
      expect(subject.render(results, ['apache', {}])).to match(/DESCRIPTION/)
      expect(subject.render(results, ['apache', {}])).to match(/AUTHOR/)
      expect(subject.render(results, ['apache', {}])).to match(/KEYWORDS/)
    end

    it 'should output the relevant fields when receiving a non-empty dataset' do
      results = {
        :result => :success,
        :answers => [
          {'full_name' => 'Name', 'author' => 'Author', 'desc' => 'Summary', 'tag_list' => ['tag1', 'tag2'] },
        ]
      }

      expect(subject.render(results, ['apache', {}])).to match(/Name/)
      expect(subject.render(results, ['apache', {}])).to match(/Author/)
      expect(subject.render(results, ['apache', {}])).to match(/Summary/)
      expect(subject.render(results, ['apache', {}])).to match(/tag1/)
      expect(subject.render(results, ['apache', {}])).to match(/tag2/)
    end

    it 'should elide really long descriptions' do
      results = {
        :result => :success,
        :answers => [
          {
            'full_name' => 'Name',
            'author' => 'Author',
            'desc' => 'This description is really too long to fit in a single data table, guys -- we should probably set about truncating it',
            'tag_list' => ['tag1', 'tag2'],
          },
        ]
      }

      expect(subject.render(results, ['apache', {}])).to match(/\.{3}  @Author/)
    end

    it 'should never truncate the module name' do
      results = {
        :result => :success,
        :answers => [
          {
            'full_name' => 'This-module-has-a-really-really-long-name',
            'author' => 'Author',
            'desc' => 'Description',
            'tag_list' => ['tag1', 'tag2'],
          },
        ]
      }

      expect(subject.render(results, ['apache', {}])).to match(/This-module-has-a-really-really-long-name/)
    end

    it 'should never truncate the author name' do
      results = {
        :result => :success,
        :answers => [
          {
            'full_name' => 'Name',
            'author' => 'This-author-has-a-really-really-long-name',
            'desc' => 'Description',
            'tag_list' => ['tag1', 'tag2'],
          },
        ]
      }

      expect(subject.render(results, ['apache', {}])).to match(/@This-author-has-a-really-really-long-name/)
    end

    it 'should never remove tags that match the search term' do
      results = {
        :results => :success,
        :answers => [
          {
            'full_name' => 'Name',
            'author' => 'Author',
            'desc' => 'Description',
            'tag_list' => ['Supercalifragilisticexpialidocious'] + (1..100).map { |i| "tag#{i}" },
          },
        ]
      }

      expect(subject.render(results, ['Supercalifragilisticexpialidocious', {}])).to match(/Supercalifragilisticexpialidocious/)
      expect(subject.render(results, ['Supercalifragilisticexpialidocious', {}])).not_to match(/tag/)
    end

    {
      100 => "NAME          DESCRIPTION                                     AUTHOR         KEYWORDS#{' '*15}\n"\
             "Name          This description is really too long to fit ...  @JohnnyApples  tag1 tag2 taggitty3#{' '*4}\n",

      70  => "NAME          DESCRIPTION                 AUTHOR         KEYWORDS#{' '*5}\n"\
             "Name          This description is rea...  @JohnnyApples  tag1 tag2#{' '*4}\n",

      80  => "NAME          DESCRIPTION                        AUTHOR         KEYWORDS#{' '*8}\n"\
             "Name          This description is really too...  @JohnnyApples  tag1 tag2#{' '*7}\n",

      200 => "NAME          DESCRIPTION                                                                                                        AUTHOR         KEYWORDS#{' '*48}\n"\
             "Name          This description is really too long to fit in a single data table, guys -- we should probably set about trunca...  @JohnnyApples  tag1 tag2 taggitty3#{' '*37}\n"
    }.each do |width, expectation|
      it "should resize the table to fit the screen, when #{width} columns" do
        results = {
          :result => :success,
          :answers => [
            {
              'full_name' => 'Name',
              'author' => 'JohnnyApples',
              'desc' => 'This description is really too long to fit in a single data table, guys -- we should probably set about truncating it',
              'tag_list' => ['tag1', 'tag2', 'taggitty3'],
            },
          ]
        }

        Puppet::Util::Terminal.expects(:width).returns(width)
        result = subject.render(results, ['apache', {}])
        expect(result.lines.sort_by(&:length).last.chomp.length).to be <= width
        expect(result).to eq(expectation)
      end
    end
  end

  describe "option validation" do
    context "without any options" do
      it "should require a search term" do
        pattern = /wrong number of arguments/
        expect { subject.search }.to raise_error ArgumentError, pattern
      end
    end

    it "should accept the --module-repository option" do
      forge = mock("Puppet::Forge")
      searcher = mock("Searcher")
      options[:module_repository] = "http://forge.example.com"

      Puppet::Forge.expects(:new).with().returns(forge)
      Puppet::ModuleTool::Applications::Searcher.expects(:new).with("puppetlabs-apache", forge, has_entries(options)).returns(searcher)
      searcher.expects(:run)

      subject.search("puppetlabs-apache", options)
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :search }

    its(:summary)     { should =~ /search.*module/im }
    its(:description) { should =~ /search.*module/im }
    its(:returns)     { should =~ /array/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
