<% define 'IndentStringTest', :for => Object do %>
	<% file 'indentStringTestDefaultIndent.out' do %>
		<%iinc%>
		<- your default here
		<%idec%>
	<% end %>
	<% file 'indentStringTestTabIndent.out', "\t" do %>
		<%iinc%>
		<- tab
		<%idec%>
	<% end %>
<% end %>