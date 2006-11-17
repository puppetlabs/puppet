#--
# Copyright (c) 2006 Shawn Patrick Garbett
# Copyright (c) 2002,2004,2005 by Horst Duchene
# 
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice(s),
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of the Shawn Garbett nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#++


module GRATR

  # Edge includes classes for representing egdes of directed and
  # undirected graphs. There is no need for a Vertex class, because any ruby
  # object can be a vertex of a graph.
  #
  # Edge's base is a Struct with a :source, a :target and a :label
  Struct.new("EdgeBase",:source, :target, :label)

  class Edge < Struct::EdgeBase

    def initialize(p_source,p_target,p_label=nil)
      super(p_source, p_target, p_label)
    end

    # Ignore labels for equality
    def eql?(other) self.class == other.class and target==other.target and source==other.source; end

    # Alias for eql?
    alias == eql?

    # Returns (v,u) if self == (u,v).
    def reverse() self.class.new(target, source, label); end

    # Sort support
    def <=>(rhs) [source,target] <=> [rhs.source,rhs.target]; end

    # Edge.new[1,2].to_s => "(1-2 'label')"
    def to_s
      l = label ? " '#{label.to_s}'" : ''
      "(#{source}-#{target}#{l})"
    end
    
    # Hash is defined in such a way that label is not
    # part of the hash value
    def hash() source.hash ^ (target.hash+1); end

    # Shortcut constructor. Instead of Edge.new(1,2) one can use Edge[1,2]
    def self.[](p_source, p_target, p_label=nil)
      new(p_source, p_target, p_label)
    end
    
    def inspect() "#{self.class.to_s}[#{source.inspect},#{target.inspect},#{label.inspect}]"; end
    
  end
    
  # An undirected edge is simply an undirected pair (source, target) used in
  # undirected graphs. UndirectedEdge[u,v] == UndirectedEdge[v,u]
  class UndirectedEdge < Edge

    # Equality allows for the swapping of source and target
    def eql?(other) super or (self.class == other.class and target==other.source and source==other.target); end
      
    # Alias for eql?
    alias == eql?

    # Hash is defined such that source and target can be reversed and the
    # hash value will be the same
    #
    # This will cause problems with self loops
    def hash() source.hash ^ target.hash; end

    # Sort support
    def <=>(rhs)
      [[source,target].max,[source,target].min] <=> 
      [[rhs.source,rhs.target].max,[rhs.source,rhs.target].min]
    end
    
    # UndirectedEdge[1,2].to_s == "(1=2 'label)"
    def to_s
      l = label ? " '#{label.to_s}'" : ''
      s = source.to_s
      t = target.to_s
      "(#{[s,t].min}=#{[s,t].max}#{l})"
    end
    
  end
  
  # This module provides for internal numbering of edges for differentiating between mutliple edges
  module EdgeNumber
    
    attr_accessor :number # Used to differentiate between mutli-edges
    
    def initialize(p_source,p_target,p_number,p_label=nil)
      self.number = p_number 
      super(p_source, p_target, p_label)
    end

    # Returns (v,u) if self == (u,v).
    def reverse() self.class.new(target, source, number, label); end
    def hash() super ^ number.hash; end    
    def to_s() super + "[#{number}]"; end
    def <=>(rhs) (result = super(rhs)) == 0 ? number <=> rhs.number : result; end 
    def inspect() "#{self.class.to_s}[#{source.inspect},#{target.inspect},#{number.inspect},#{label.inspect}]"; end
    def eql?(rhs) super(rhs) and (rhs.number.nil? or number.nil? or number == rhs.number); end 
    def ==(rhs) eql?(rhs); end

    # Shortcut constructor. Instead of Edge.new(1,2) one can use Edge[1,2]
    def self.included(cl)
      
      def cl.[](p_source, p_target, p_number=nil, p_label=nil)
        new(p_source, p_target, p_number, p_label)
      end
    end

  end
  
  class MultiEdge < Edge
    include EdgeNumber
  end
  
  class MultiUndirectedEdge < UndirectedEdge
    include EdgeNumber
  end
  
end
