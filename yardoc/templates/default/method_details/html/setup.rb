def init
  super
end

def format_method_detail_extras(object)
  result = ""
  if object
    if object.respond_to?(:visibility)
      if object.visibility != :public
        result << "<span class=\"note title #{object.visibility}\">#{object.visibility}</span>"
      end
    end
      if object.has_tag?(:abstract)
        result << '<span class="abstract note title">abstract</span>'
      end
      if object.has_tag?(:deprecated)
        result << '<span class="deprecated note title">deprecated</span>'
      end
    if object.respond_to?(:visibility)
      if object.has_tag?(:api) && object.tag(:api).text == 'private' && object.visibility != :private
        result << '<span class="private note title">private</span>'
      end
    else  
      if object.has_tag?(:api) && object.tag(:api).text == 'private'
        result << '<span class="private note title">private</span>'
      end
    end
    if object.has_tag?(:dsl)
      result << '<span class="note title readonly">DSL</span>'
    end
  end
  # separate the extras with one space
  if result != ""
    result = "&nbsp;" + result
  end
  result
end
