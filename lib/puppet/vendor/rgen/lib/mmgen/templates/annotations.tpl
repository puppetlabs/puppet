<% define 'Annotations', :for => EPackage do %>
	<% for a in eAnnotations %>
		annotation <% expand 'AnnotationArgs', :for => a %>
	<% end %>
<% end %>

<% define 'Annotations', :for => EClass do %>
	<% for a in eAnnotations %>
		annotation <% expand 'AnnotationArgs', :for => a %>
	<% end %>
<% end %>

<% define 'Annotations', :for => EStructuralFeature do %>
	<% oppositeAnnotations = (this.respond_to?(:eOpposite) && eOpposite && eOpposite.eAnnotations) || [] %>
	<% if eAnnotations.size > 0 || oppositeAnnotations.size > 0 %>
		do<%iinc%>
			<% for a in eAnnotations %>
				annotation <% expand 'AnnotationArgs', :for => a %>
			<% end %>
			<% for a in oppositeAnnotations %>
				opposite_annotation <% expand 'AnnotationArgs', :for => a %>
			<% end %><%idec%>
		end<%nows%>
	<% end %>
<% end %>

<% define 'AnnotationArgs', :for => EAnnotation do %>
	<% if source.nil? %>
		<% expand 'Details' %>
	<% else %>
		:source => "<%= source.to_s %>", :details => {<% expand 'Details' %>}<%nows%>
	<% end %>
<% end %>

<% define 'Details', :for => EAnnotation do %>
	<%= details.sort{|a,b| a.key<=>b.key}.collect{ |d| "\'" + d.key + "\' => \'"+ (d.value || "").gsub('\'','\\\'').to_s + "\'"}.join(', ') %><%nows%>
<% end %>