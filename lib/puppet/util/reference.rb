# frozen_string_literal: true

require_relative '../../puppet/util/instance_loader'
require 'fileutils'

# Manage Reference Documentation.
class Puppet::Util::Reference
  include Puppet::Util
  include Puppet::Util::Docs

  extend Puppet::Util::InstanceLoader

  instance_load(:reference, 'puppet/reference')

  def self.modes
    %w[text]
  end

  def self.newreference(name, options = {}, &block)
    ref = new(name, **options, &block)
    instance_hash(:reference)[name.intern] = ref

    ref
  end

  def self.page(*sections)
    depth = 4
    # Use the minimum depth
    sections.each do |name|
      section = reference(name) or raise _("Could not find section %{name}") % { name: name }
      depth = section.depth if section.depth < depth
    end
  end

  def self.references(environment)
    instance_loader(:reference).loadall(environment)
    loaded_instances(:reference).sort_by(&:to_s)
  end

  attr_accessor :page, :depth, :header, :title, :dynamic
  attr_writer :doc

  def doc
    if defined?(@doc)
      "#{@name} - #{@doc}"
    else
      @title
    end
  end

  def dynamic?
    dynamic
  end

  def initialize(name, title: nil, depth: nil, dynamic: nil, doc: nil, &block)
    @name = name
    @title = title
    @depth = depth
    @dynamic = dynamic
    @doc = doc

    meta_def(:generate, &block)

    # Now handle the defaults
    @title ||= _("%{name} Reference") % { name: @name.to_s.capitalize }
    @page ||= @title.gsub(/\s+/, '')
    @depth ||= 2
    @header ||= ""
  end

  # Indent every line in the chunk except those which begin with '..'.
  def indent(text, tab)
    text.gsub(/(^|\A)/, tab).gsub(/^ +\.\./, "..")
  end

  def option(name, value)
    ":#{name.to_s.capitalize}: #{value}\n"
  end

  def text
    puts output
  end

  def to_markdown(withcontents = true)
    # First the header
    text = markdown_header(@title, 1)

    text << @header

    text << generate

    text
  end
end
