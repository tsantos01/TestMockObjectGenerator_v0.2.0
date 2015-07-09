<cfif not StructKeyExists(form, 'setupForm')>
	<cfset pageTitle = "CFC Stub Generator Setup">
<cfelse>
	<cfset pageTitle = "CFC Stub Generator Results">
</cfif>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

<html>
<head>
	<cfoutput><title>#pageTitle#</title></cfoutput>
</head>

<body>
<cfif not StructKeyExists(form, 'cfcDataFile')>
	<h2>Pick the options you want to enable, then generate your CFC stubs.</h2>
	
	<form method="post" action="index.cfm" name="setupForm">
		<table border="1" cellspacing="0" cellpadding="8">
			<tr>
				<td>Server (with port if necessary): </td>
				<td><input type="text" name="hostName" value="localhost" size="25" /></td>
			</tr>
			<tr>
				<td>Absolute path from web root to CFC text file or XMI file: </td>
				<td><input type="text" name="cfcDataFile" value="/path/file.txt" size="50" /></td>
			</tr>
			<tr>
				<td>Choose Target Framework: </td>
				<td>
					<select name="targetFramework">
						<option value="cfunit">CFUnit</option>
						<option value="cfcunit">CFCUnit</option>
					</select>
				</td>
			</tr>
			<tr>
				<td>Generate Mock Objects? </td>
				<td>
					<input type="radio" name="createMocks" value="Yes" checked="true" /> Yes 
					<input type="radio" name="createMocks" value="No" /> No<br />
					<input type="radio" name="createMocks" value="ColdMock" /> Yes, using ColdMock (requires ColdMock to be installed under /coldmock)
				</td>
			</tr>
			<tr>
				<td>Generate Test Runner? </td>
				<td>
					<input type="radio" name="createTestRunner" value="Yes" checked="true" /> Yes  
					<input type="radio" name="createTestRunner" value="No" /> No
				</td>
			</tr>
			<tr>
				<td>Generate ColdSpring XML File?</td>
				<td>
					<input type="radio" name="createColdSpring" value="Yes" checked="true" /> Yes  
					<input type="radio" name="createColdSpring" value="No" /> No
				</td>
			</tr>
			<tr>
				<td>Generate CFEclipse ANT Build Script?</td>
				<td>
					<input type="radio" name="createBuildScript" value="Yes" checked="true" /> Yes  
					<input type="radio" name="createBuildScript" value="No" /> No
				</td>
			</tr>
			<tr>
				<td colspan="2" bgcolor="DDDDDD">XMI-Only Configuration Options (if using a Text file just ignore the following options)</td>
			</tr>
			<tr>
				<td>Write Method Documentation in Hints or Body?</td>
				<td>
					<input type="radio" name="documentationLocation" value="hint" checked="true" /> Hints  
					<input type="radio" name="documentationLocation" value="body" /> Body
				</td>
			</tr>
			<tr>
				<td>Strip HTML Markup from UML Documentation?</td>
				<td>
					<input type="radio" name="stripHTMLFromDocumentation" value="Yes" checked="true" /> Yes  
					<input type="radio" name="stripHTMLFromDocumentation" value="No" /> No
				</td>
			</tr>
			<tr>
				<td>Attempt to Generate Basic Getters and Setters?</td>
				<td>
					<input type="radio" name="createGetSet" value="Yes" checked="true" /> Yes  
					<input type="radio" name="createGetSet" value="No" /> No
				</td>
			</tr>
			<tr>
				<td>Add Custom Attribute "aggregates" to Generated CFCOMPONENT Tags<br/>To Document Aggregation/Composition?</td>
				<td>
					<input type="radio" name="addAggregates" value="Yes" checked="true" /> Yes  
					<input type="radio" name="addAggregates" value="No" /> No
				</td>
			</tr>
			<tr>
				<td colspan="2"><input type="submit" value="Generate CFC Stubs" /></td>
			</tr>
		</table>	
	</form>
<cfelse>
	
	<cfif ListLast(form.cfcDataFile, '.') eq "xmi">
		<cfset testRunnerDirectory = "/testsuite" />
		<cfset stubber = createObject('component','stubgenerator.CFCStubGeneratorFromXMI').init() />
	<cfelse>
		<cfset testRunnerDirectory = "" />
		<cfset stubber = createObject('component','stubgenerator.CFCStubGeneratorFromText').init() />
	</cfif>
	
	<h2>Generating CFC file and unit test stubs...</h2>
	
	<cfdump var="#stubber.createStubs(argumentCollection=form)#" label="Stub Files Created"><br />
	
	<cfoutput>
		<cfif form.createTestRunner and form.targetFramework eq "cfunit">
			<a href="#listDeleteAt(form.cfcDataFile, listLen(form.cfcDataFile, '/'), '/')##testRunnerDirectory#/testrunner.cfm" target="_blank">Run the Tests</a> | 
		<cfelseif form.createTestRunner and form.targetFramework eq "cfcunit">
			<cfset testSuitePath = Replace(Replace('#listDeleteAt(form.cfcDataFile, listLen(form.cfcDataFile, '/'), '/')##testRunnerDirectory#', '/', '.', 'All'), '.', '') />
			<a href="/cfcunit/index.cfm?event=runTest&testClassName=#testSuitePath#.AllTests&runnerType=text" target="_blank">Run the Tests</a> | 
		</cfif>
		<a href="index.cfm">Return to Configuration</a>  
	</cfoutput>
	
</cfif>

</body>
</html>