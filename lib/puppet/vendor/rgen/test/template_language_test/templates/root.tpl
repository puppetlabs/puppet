<% define 'Root' do %>
	<% file 'testout.txt' do %>
		Document: <%= title %>
		<%nl%>
		<%iinc%>
		by <% expand 'content/author::Author', :foreach => authors, :separator => ' and ' %>
		<%idec%>
		<%nl%>
		Index:<%iinc%>
		<% for c in chapters %>
			<% nr = (nr || 0); nr += 1 %>
			<% expand 'index/chapter::Root', nr, this, :for => c %>
		<% end %><%idec%>
		<%nl%>
		----------------
		<%nl%>
		Chapters in one line:
		<% expand 'content/chapter::Root', :foreach => chapters, :separator => ", " %><%nl%>
		<%nl%>
		Chapters each in one line:
		<% expand 'content/chapter::Root', :foreach => chapters, :separator => ",\r\n" %><%nl%>
		<%nl%>
		Here are some code examples:
		<% expand 'code/array::ArrayDefinition', :for => sampleArray %>
	<% end %>
<% end %>

<% define 'TextFromRoot' do %>
	Text from Root
<% end %>

