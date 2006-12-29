require 'puppet/rails/external/tagging/acts_as_taggable'
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Taggable)

require 'puppet/rails/external/tagging/tagging'
require 'puppet/rails/external/tagging/tag'
