<% define 'Test', :for => Object do %>
	<%iinc%>
	xxx<% expand 'NoIndent1' %>
	xxx<% expand 'NoIndent2' %>
	xxx<% expand 'NoIndent3' %>
	xxx<% expand 'NoIndent4' %>
	<%idec%>
<% end %>

<% define 'NoIndent1', :for => Object do %>
	<---<%nows%>
<% end %>

<% define 'NoIndent2', :for => Object do %>
	<% expand 'NoIndent1' %>
<% end %>

<% define 'NoIndent3', :for => Object do %>
	<% expand 'no_indent::NoIndent' %>
<% end %>

<% define 'NoIndent4', :for => Object do %>
	<% expand 'sub1/no_indent::NoIndent' %>
<% end %>
