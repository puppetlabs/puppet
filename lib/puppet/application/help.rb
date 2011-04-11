# -*- coding: utf-8 -*-
require 'puppet/application/faces_base'

class Puppet::Application::Help < Puppet::Application::FacesBase
  # Meh.  Disable the default behaviour, which is to inspect the
  # string and return that – not so helpful. --daniel 2011-04-11
  def render(result) result end
end
