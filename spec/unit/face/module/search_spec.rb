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
      subject.render([], ['apache', {}]).should == ''
    end

    it 'should output a header when receiving a non-empty dataset' do
      results = [
        {'full_name' => '', 'author' => '', 'desc' => '', 'tag_list' => [] },
      ]

      subject.render(results, ['apache', {}]).should =~ /NAME/
      subject.render(results, ['apache', {}]).should =~ /DESCRIPTION/
      subject.render(results, ['apache', {}]).should =~ /AUTHOR/
      subject.render(results, ['apache', {}]).should =~ /KEYWORDS/
    end

    it 'should output the relevant fields when receiving a non-empty dataset' do
      results = [
        {'full_name' => 'Name', 'author' => 'Author', 'desc' => 'Summary', 'tag_list' => ['tag1', 'tag2'] },
      ]

      subject.render(results, ['apache', {}]).should =~ /Name/
      subject.render(results, ['apache', {}]).should =~ /Author/
      subject.render(results, ['apache', {}]).should =~ /Summary/
      subject.render(results, ['apache', {}]).should =~ /tag1/
      subject.render(results, ['apache', {}]).should =~ /tag2/
    end

    it 'should elide really long descriptions' do
      results = [
        {
          'full_name' => 'Name',
          'author' => 'Author',
          'desc' => 'This description is really too long to fit in a single data table, guys -- we should probably set about truncating it',
          'tag_list' => ['tag1', 'tag2'],
        },
      ]

      subject.render(results, ['apache', {}]).should =~ /\.{3}  @Author/
    end

    it 'should never truncate the module name' do
      results = [
        {
          'full_name' => 'This-module-has-a-really-really-long-name',
          'author' => 'Author',
          'desc' => 'Description',
          'tag_list' => ['tag1', 'tag2'],
        },
      ]

      subject.render(results, ['apache', {}]).should =~ /This-module-has-a-really-really-long-name/
    end

    it 'should never truncate the author name' do
      results = [
        {
          'full_name' => 'Name',
          'author' => 'This-author-has-a-really-really-long-name',
          'desc' => 'Description',
          'tag_list' => ['tag1', 'tag2'],
        },
      ]

      subject.render(results, ['apache', {}]).should =~ /@This-author-has-a-really-really-long-name/
    end

    it 'should never remove tags that match the search term' do
      results = [
        {
          'full_name' => 'Name',
          'author' => 'Author',
          'desc' => 'Description',
          'tag_list' => ['Supercalifragilisticexpialidocious'] + (1..100).map { |i| "tag#{i}" },
        },
      ]

      subject.render(results, ['Supercalifragilisticexpialidocious', {}]).should =~ /Supercalifragilisticexpialidocious/
      subject.render(results, ['Supercalifragilisticexpialidocious', {}]).should_not =~ /tag/
    end

    {
      100 => <<-EOT,
NAME          DESCRIPTION                                      AUTHOR        KEYWORDS               
Name          This description is really too long to fit i...  @Author       tag1 tag2 taggitty3    
EOT

      70 => <<-EOT,
NAME          DESCRIPTION                  AUTHOR        KEYWORDS     
Name          This description is real...  @Author       tag1 tag2    
EOT

      80 => <<-EOT,
NAME          DESCRIPTION                         AUTHOR        KEYWORDS        
Name          This description is really too ...  @Author       tag1 tag2       
EOT

      200 => <<-EOT,
NAME          DESCRIPTION                                                                                                         AUTHOR        KEYWORDS                                                
Name          This description is really too long to fit in a single data table, guys -- we should probably set about truncat...  @Author       tag1 tag2 taggitty3                                     
EOT
    }.each do |width, expectation|
      it 'should resize the table to fit the screen, when #{width} columns' do
        results = [
          {
            'full_name' => 'Name',
            'author' => 'Author',
            'desc' => 'This description is really too long to fit in a single data table, guys -- we should probably set about truncating it',
            'tag_list' => ['tag1', 'tag2', 'taggitty3'],
          },
        ]

        Puppet::Util::Terminal.expects(:width).returns(width)
        result = subject.render(results, ['apache', {}])
        result.lines.max_by(&:length).chomp.length.should <= width
        result.should == expectation
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
      options[:module_repository] = "http://forge.example.com"
      Puppet::Module::Tool::Applications::Searcher.expects(:run).with("puppetlabs-apache", options).once
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
