<!--- 
File: CFCStubGenerator.cfc
Author: Brian Kotek
Site: http://www.briankotek.com/blog

Usage:
This CFC uses a simple text file to create stubs for CFCs and CFUnit/CFCUnit unit test files. Just create an instance of 
the component, and call the createStubs() method. The easiest way it to run the index.cfm configuration screen included in 
this zip file. The CFC and CFUnit files will all be created in the same directory as the text file. Any CFC paths or 
folder paths will be created using the path to the text file directory as well.

The format of the text file is:

User
getUserName
getAddress

Invoice
calculateTotal
addLineItem

This is just a component name and the names of the methods that you want stubbed out. Separate the components with 2 

carriage returns.
This file and related examples are available at my blog at www.briankotek.com/blog.
--->

<cfcomponent name="CFCStubGenerator" hint="Given a properly formatted text file, I generate CFC stubs, test harness stubs, and a test runner file.">
	
	<cffunction name="init" access="public" hint="Constructor">
		<cfset setCRLF('#chr(13)##chr(10)#') />
		<cfreturn this />
	</cffunction>
	
	<cffunction name="createStubs" access="public" output="false" hint="Create the CFC stubs, test harness stubs, and test runner file.">
		<cfargument name="hostName" required="true" hint="HTTP server name" />
		<cfargument name="cfcDataFile" required="true" hint="Absolute path to stub text file." />
		<cfargument name="targetFramework" type="string" required="true" default="cfunit" />
		<cfargument name="createMocks" type="string" required="true" default="yes" />
		<cfargument name="createColdSpring" type="string" required="true" default="yes" />
		<cfargument name="createTestRunner" type="string" required="true" default="yes" />
		<cfargument name="createBuildScript" type="string" required="true" default="yes" />
		<cfargument name="frameworkTestCasePath" type="string" required="false" default="" />
		<cfargument name="documentationLocation" type="string" required="true" default="hint" hint="hint or body" />
		<cfargument name="createGetSet" type="string" required="true" default="yes" hint="" />
		<cfargument name="addAggregates" type="string" required="true" default="yes" hint="" />
		<cfargument name="stripHTMLFromDocumentation" type="string" required="true" default="yes" hint="" />
		
		<cfset setHostName(arguments.hostName) />
		<cfset setUnitTestFramework(arguments.targetFramework) />
		<cfset setFrameworkTestCasePath(arguments.frameworkTestCasePath) />
		<cfset setRelativePath(arguments.cfcDataFile) />
		<cfset setCFCPath() />
		<cfset setTargetDirectory(arguments.cfcDataFile) />
		<cfset setCreateColdSpring(arguments.createColdSpring) />
		<cfset setCreateTestRunner(arguments.createTestRunner) />
		<cfset setCreateBuildScript(arguments.createBuildScript) />
		<cfset setCreateMocks(arguments.createMocks) />
		<cfset setDocumentationLocation(arguments.documentationLocation) />
		<cfset setCreateGetSet(arguments.createGetSet) />
		<cfset setAddAggregates(arguments.addAggregates) />
		<cfset setStripHTMLFromDocumentation(arguments.stripHTMLFromDocumentation) />
		<cfset parseCFCDataFile(readCFCDataFile(arguments.cfcDataFile)) />
		
		<cfreturn doStubGeneration() />
	</cffunction>
	
	<cffunction name="doStubGeneration" access="private" output="false" hint="">
		<cfset variables.instance.createdStubs = ArrayNew(1) />
		<cfprocessingdirective suppresswhitespace="false">
		<cfset createStubFiles() />
		<cfif getCreateColdSpring()>
			<cfset createColdSpringXML() />
		</cfif>
		<cfif getCreateTestRunner()>
			<cfset createTestRunner() />
		</cfif>
		<cfif getCreateBuildScript()>
			<cfset createTestANTBuildXML() />
		</cfif>
		</cfprocessingdirective>
		<cfreturn variables.instance.createdStubs />
	</cffunction>
	
	<cffunction name="getCRLF" access="private" output="false" hint="I return the CRLF.">
		<cfreturn variables.instance.CRLF />
	</cffunction>
		
	<cffunction name="setCRLF" access="private" output="false" hint="I set the CRLF.">
		<cfargument name="CRLF" type="string" required="true" hint="CRLF" />
		<cfset variables.instance.CRLF = arguments.CRLF />
	</cffunction>
	
	<cffunction name="getTargetDirectory" access="private" output="false" hint="I return the targetDirectory.">
		<cfreturn variables.instance.targetDirectory />
	</cffunction>
		
	<cffunction name="setTargetDirectory" access="private" output="false" hint="I set the targetDirectory.">
		<cfargument name="targetDirectory" required="true" hint="targetDirectory" />
		<cfset variables.instance.targetDirectory = getDirectoryFromPath(ExpandPath(arguments.targetDirectory)) />
	</cffunction>
	
	<cffunction name="getRelativePath" access="private" returntype="string" output="false" hint="I return the relativePath.">
		<cfreturn variables.instance.relativePath />
	</cffunction>
		
	<cffunction name="setRelativePath" access="private" output="false" hint="I set the relativePath.">
		<cfargument name="relativePath" required="true" hint="relativePath" />
		<cfset variables.instance.relativePath = ListDeleteAt(arguments.relativePath, ListLen(arguments.relativePath, '/'), '/') />
	</cffunction>
	
	<cffunction name="getHostName" access="private" returntype="string" output="false" hint="I return the hostName.">
		<cfreturn variables.instance.hostName />
	</cffunction>
		
	<cffunction name="setHostName" access="private" returntype="void" output="false" hint="I set the hostName.">
		<cfargument name="hostName" type="string" required="true" hint="hostName" />
		<cfset variables.instance.hostName = arguments.hostName />
	</cffunction>
	
	<cffunction name="getCFCPath" access="private" returntype="string" output="false" hint="I return the cfcPath.">
		<cfreturn variables.instance.cfcPath />
	</cffunction>
		
	<cffunction name="setCFCPath" access="private" output="false" hint="I set the relativePath.">
		<cfset variables.instance.cfcPath = Replace(getRelativePath(), '/', '.', 'all') />
		<cfset variables.instance.cfcPath = Right(variables.instance.cfcPath, len(variables.instance.cfcPath)-1) />
	</cffunction>
	
	<cffunction name="getCFCData" access="private" output="false" hint="I return the cfcData.">
		<cfreturn variables.instance.cfcData />
	</cffunction>
		
	<cffunction name="setCFCData" access="private" output="false" hint="I set the cfcData.">
		<cfargument name="cfcData" required="true" hint="cfcData" />
		<cfset variables.instance.cfcData = arguments.cfcData />
	</cffunction>
	
	<cffunction name="getUnitTestFramework" access="private" returntype="string" output="false" hint="I return the unitTestFramework.">
		<cfreturn variables.instance.unitTestFramework />
	</cffunction>
		
	<cffunction name="setUnitTestFramework" access="private" returntype="void" output="false" hint="I set the unitTestFramework.">
		<cfargument name="unitTestFramework" type="string" required="true" hint="unitTestFramework" />
		<cfset variables.instance.unitTestFramework = arguments.unitTestFramework />
	</cffunction>
	
	<cffunction name="getFrameworkTestCasePath" access="private" returntype="string" output="false" hint="I return the frameworkTestCasePath.">
		<cfreturn variables.instance.frameworkTestCasePath />
	</cffunction>
		
	<cffunction name="setFrameworkTestCasePath" access="private" returntype="void" output="false" hint="I set the frameworkTestCasePath.">
		<cfargument name="frameworkTestCasePath" type="string" required="true" hint="frameworkTestCasePath" />
		<cfif len(arguments.frameworkTestCasePath)>
			<cfset variables.instance.frameworkTestCasePath = arguments.frameworkTestCasePath />
		<cfelseif getUnitTestFramework() eq 'cfunit'>
			<cfset variables.instance.frameworkTestCasePath = "net.sourceforge.cfunit.framework.TestCase" />
		<cfelseif getUnitTestFramework() eq 'cfcunit'>
			<cfset variables.instance.frameworkTestCasePath = "org.cfcunit.framework.TestCase" />
		</cfif>	
	</cffunction>
	
	<cffunction name="getCreateBuildScript" access="private" returntype="string" output="false" hint="I return the createBuildScript.">
		<cfreturn variables.instance.createBuildScript />
	</cffunction>
		
	<cffunction name="setCreateBuildScript" access="private" returntype="void" output="false" hint="I set the createBuildScript.">
		<cfargument name="createBuildScript" type="string" required="true" hint="createBuildScript" />
		<cfset variables.instance.createBuildScript = arguments.createBuildScript />
	</cffunction>
	
	<cffunction name="getCreateTestRunner" access="private" returntype="string" output="false" hint="I return the createTestRunner.">
		<cfreturn variables.instance.createTestRunner />
	</cffunction>
		
	<cffunction name="setCreateTestRunner" access="private" returntype="void" output="false" hint="I set the createTestRunner.">
		<cfargument name="createTestRunner" type="string" required="true" hint="createTestRunner" />
		<cfset variables.instance.createTestRunner = arguments.createTestRunner />
	</cffunction>
	
	<cffunction name="getCreateColdSpring" access="private" returntype="string" output="false" hint="I return the createColdSpring.">
		<cfreturn variables.instance.createColdSpring />
	</cffunction>
		
	<cffunction name="setCreateColdSpring" access="private" returntype="void" output="false" hint="I set the createColdSpring.">
		<cfargument name="createColdSpring" type="string" required="true" hint="createColdSpring" />
		<cfset variables.instance.createColdSpring = arguments.createColdSpring />
	</cffunction>
	
	<cffunction name="getCreateMocks" access="private" returntype="string" output="false" hint="I return the createMocks.">
		<cfreturn variables.instance.createMocks />
	</cffunction>
		
	<cffunction name="setCreateMocks" access="private" returntype="void" output="false" hint="I set the createMocks.">
		<cfargument name="createMocks" type="string" required="true" hint="createMocks" />
		<cfif arguments.createMocks eq 'ColdMock'>
			<cfset variables.instance.createMocks = true />
			<cfset setUseColdMock(true) />
		<cfelse>
			<cfset variables.instance.createMocks = arguments.createMocks />
			<cfset setUseColdMock(false) />
		</cfif>
	</cffunction>
	
	<cffunction name="getUseColdMock" access="public" returntype="boolean" output="false" hint="I return the UseColdMock.">
		<cfreturn variables.instance.useColdMock />
	</cffunction>
		
	<cffunction name="setUseColdMock" access="public" returntype="void" output="false" hint="I set the UseColdMock.">
		<cfargument name="useColdMock" type="boolean" required="true" hint="UseColdMock" />
		<cfset variables.instance.useColdMock = arguments.useColdMock />
	</cffunction>
	
	<cffunction name="getDocumentationLocation" access="private" returntype="string" output="false" hint="I return the documentationLocation.">
		<cfreturn variables.instance.DocumentationLocation />
	</cffunction>
		
	<cffunction name="setDocumentationLocation" access="private" returntype="void" output="false" hint="I set the documentationLocation.">
		<cfargument name="documentationLocation" type="string" required="true" hint="documentationLocation" />
		<cfset variables.instance.documentationLocation = arguments.documentationLocation />
	</cffunction>
	
	<cffunction name="getCreateGetSet" access="private" returntype="string" output="false" hint="I return the createGetSet.">
		<cfreturn variables.instance.createGetSet />
	</cffunction>
		
	<cffunction name="setCreateGetSet" access="private" returntype="void" output="false" hint="I set the createGetSet.">
		<cfargument name="createGetSet" type="string" required="true" hint="createGetSet" />
		<cfset variables.instance.createGetSet = arguments.createGetSet />
	</cffunction>
	
	<cffunction name="getAddAggregates" access="private" returntype="string" output="false" hint="I return the addAggregates.">
		<cfreturn variables.instance.addAggregates />
	</cffunction>
		
	<cffunction name="setAddAggregates" access="private" returntype="void" output="false" hint="I set the addAggregates.">
		<cfargument name="addAggregates" type="string" required="true" hint="addAggregates" />
		<cfset variables.instance.addAggregates = arguments.addAggregates />
	</cffunction>
	
	<cffunction name="getStripHTMLFromDocumentation" access="private" returntype="string" output="false" hint="I return the stripHTMLFromDocumentation.">
		<cfreturn variables.instance.stripHTMLFromDocumentation />
	</cffunction>
		
	<cffunction name="setStripHTMLFromDocumentation" access="private" returntype="void" output="false" hint="I set the stripHTMLFromDocumentation.">
		<cfargument name="stripHTMLFromDocumentation" type="string" required="true" hint="stripHTMLFromDocumentation" />
		<cfset variables.instance.stripHTMLFromDocumentation = arguments.stripHTMLFromDocumentation />
	</cffunction>
	
	<cffunction name="stripHTMLTagsFromString" access="private" returntype="string" output="false" hint="">
		<cfargument name="targetString" type="string" required="true" />
		<cfreturn ReReplaceNoCase(arguments.targetString, '<(.|\n)*?>', '', 'All') />
	</cffunction>
	
	<cffunction name="getOSPathDelimeter" returntype="string">
		<cfset var r = "" />
		<cfif SERVER.OS.name CONTAINS "windows">
			<cfset r = "\" />
		<cfelse>
			<cfset r = "/" />
		</cfif>
		<cfreturn r />
	</cffunction>
	
</cfcomponent>