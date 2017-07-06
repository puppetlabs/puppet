<% define 'Test', :for => Object do %>
<%iinc%><%iinc%>
return <% expand 'Call1' %>;
<%idec%><%idec%>
<% end %>

<% define 'Call1', :for => Object do %>
	x<% expand 'Call2' %><%nows%>
<% end %>

<% define 'Call2', :for => Object do %>
	xxx<%nows%>
<% end %>