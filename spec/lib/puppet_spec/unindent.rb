class String
  def unindent(left_padding = '')
    gsub(/^#{scan(/^\s*/).min_by{ |l| l.length }}/, left_padding)
  end
end
