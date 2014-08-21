<% define 'Author', :for => Author do %>
	<% expand 'SubAuthor' %>
<% end %>

<% define 'SubAuthor', :for => Author do %>
	<%= name %>, EMail: <%= email.sub('@','(at)') %><%nows%>
<% end %>
