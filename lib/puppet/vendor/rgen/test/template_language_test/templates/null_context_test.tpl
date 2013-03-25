<% define 'NullContextTestBad', :for => Object do %>
	<%# this must raise an exception %>
	<% expand 'Callee', :for => nil %>
<% end %>

<% define 'NullContextTestBad2', :for => Object do %>
	<%# this must raise an exception %>
	<% expand 'Callee', :foreach => nil %>
<% end %>

<% define 'NullContextTestOk', :for => Object do %>
	<%# however this is ok %>
	<% expand 'Callee' %>
<% end %>

<% define 'Callee', :for => Object do %>
<% end %>