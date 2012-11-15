#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:cron).provider(:crontab) do
  subject do
    provider = Puppet::Type.type(:cron).provider(:crontab)
    provider.initvars
    provider
  end

  context "with the simple samples" do
    FIELDS = {
      :crontab => %w{command minute hour month monthday weekday}.collect { |o| o.intern },
      :freebsd_special => %w{special command}.collect { |o| o.intern },
      :environment => [:line],
      :blank => [:line],
      :comment => [:line],
    }

    def compare_crontab_record(have, want)
      want.each do |param, value|
        have.should be_key param
        have[param].should == value
      end

      (FIELDS[have[:record_type]] - want.keys).each do |name|
        have[name].should == :absent
      end
    end

    def compare_crontab_text(have, want)
      # We should have four header lines, and then the text...
      have.lines.to_a[0..3].should be_all {|x| x =~ /^# / }
      have.lines.to_a[4..-1].join('').should == want
    end

    ########################################################################
    # Simple input fixtures for testing.
    samples = YAML.load(File.read(my_fixture('single_line.yaml')))

    samples.each do |name, data|
      it "should parse crontab line #{name} correctly" do
        compare_crontab_record subject.parse_line(data[:text]), data[:record]
      end

      it "should reconstruct the crontab line #{name} from the record" do
        subject.to_line(data[:record]).should == data[:text]
      end
    end

    records = []
    text    = ""

    # Sorting is from the original, and avoids :empty being the last line,
    # since the provider will ignore that and cause this to fail.
    samples.sort_by {|x| x.first.to_s }.each do |name, data|
      records << data[:record]
      text    << data[:text] + "\n"
    end

    it "should parse all sample records at once" do
      subject.parse(text).zip(records).each do |round|
        compare_crontab_record *round
      end
    end

    it "should reconstitute the file from the records" do
      compare_crontab_text subject.to_file(records), text
    end

    context "multi-line crontabs" do
      tests = { :simple    => [:spaces_in_command_with_times],
        :with_name => [:name, :spaces_in_command_with_times],
        :with_env  => [:environment, :spaces_in_command_with_times],
        :with_multiple_envs => [:environment, :lowercase_environment, :spaces_in_command_with_times],
        :with_name_and_env => [:name_with_spaces, :another_env, :spaces_in_command_with_times],
        :with_name_and_multiple_envs => [:long_name, :another_env, :fourth_env, :spaces_in_command_with_times]
      }

      all_records = []
      all_text    = ''

      tests.each do |name, content|
        data    = content.map {|x| samples[x] or raise "missing sample data #{x}" }
        text    = data.map {|x| x[:text] }.join("\n") + "\n"
        records = data.map {|x| x[:record] }

        # Capture the whole thing for later, too...
        all_records += records
        all_text    += text

        context name.to_s.gsub('_', ' ') do
          it "should regenerate the text from the record" do
            compare_crontab_text subject.to_file(records), text
          end

          it "should parse the records from the text" do
            subject.parse(text).zip(records).each do |round|
              compare_crontab_record *round
            end
          end
        end
      end

      it "should parse the whole set of records from the text" do
        subject.parse(all_text).zip(all_records).each do |round|
          compare_crontab_record *round
        end
      end

      it "should regenerate the whole text from the set of all records" do
        compare_crontab_text subject.to_file(all_records), all_text
      end
    end
  end
end
