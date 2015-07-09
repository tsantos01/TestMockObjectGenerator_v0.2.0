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

<cfcomponent name="CFCStubGenerator" extends="CFCStubGenerator" hint="Given a properly formatted text file, I generate CFC stubs, test harness stubs, and a test runner file.">
	
	<cffunction name="init" access="public" hint="Constructor">
		<cfset super.init() />
		<cfreturn this />
	</cffunction>
	
	<cffunction name="readCFCDataFile" access="private" output="false" hint="Read in the specified CFC text file.">
		<cfargument name="cfcDataFile" required="true" hint="Absolute path to stub text file." />
		<cfoutput><cfsavecontent variable="local.cfcDataFile"><cfinclude template="#arguments.cfcDataFile#" /></cfsavecontent></cfoutput>
		<cfset local.cfcDataFile = Replace(local.cfcDataFile, '#getCRLF()##getCRLF()#', '|', 'all') />
		<cfreturn local.cfcDataFile />
	</cffunction> 
	
	<cffunction name="parseCFCDataFile" access="private" output="false" hint="Parse the specified CFC text file and create an Array of Structs to hold the CFC data.">
		<cfargument name="CFCDataFile" required="true" hint="Stub text file data." />
		<cfset var local = StructNew() />
		<cfset variables.instance.cfcData = ArrayNew(1) />
		<cfset local.CFCData = ArrayNew(1) />
		<cfloop List="#arguments.CFCDataFile#" delimiters="|" index="local.thisCFCData">
			<cfset ArrayAppend(local.cfcData, StructNew()) />
			<cfset local.currentIndex = ArrayLen(local.cfcData) />
			<cfset local.currentCFCName = ListGetAt(local.thisCFCData, 1, getCRLF()) />
			<cfset local.cfcData[local.currentIndex].cfcName = local.currentCFCName />
			<cfset local.cfcData[local.currentIndex].cfcPath = '' />
			<cfset local.thisCFCData = ListDeleteAt(local.thisCFCData, 1, getCRLF())/>
			<cfset local.cfcData[local.currentIndex].methods = ArrayNew(1) />
			<cfloop List="#local.thisCFCData#" delimiters="#getCRLF()#" index="local.thisMethod">
				<cfset ArrayAppend(local.cfcData[local.currentIndex].methods, local.thisMethod) />
			</cfloop>
		</cfloop>
		<cfset setCFCData(local.cfcData) />
	</cffunction>
	
	<cffunction name="createStubFiles" access="private" output="false" hint="Create the CFC and test harness stubs.">
		<cfset var local = StructNew() />
		<cfset local.cfcData = getCFCData() />
		<cfloop from="1" to="#ArrayLen(local.cfcData)#" index="local.thisCFC">
			<cfset createCFCStub(local.cfcData[local.thisCFC]) />
			<cfset createTestStub(local.cfcData[local.thisCFC]) />
			<cfif getCreateMocks()>
				<cfset createMockStub(local.cfcData[local.thisCFC]) />
			</cfif>	
		</cfloop>
	</cffunction>

	<cffunction name="createCFCStub" access="private" output="false" hint="Create a single CFC stub.">
		<cfargument name="cfcData" required="true" hint="" />
		<cfset var local = StructNew() />
		<cfoutput>
		<cfsavecontent variable="local.cfcCode">
#chr(60)#cfcomponent name="#arguments.cfcData.cfcName#" hint=""#chr(62)#

	#chr(60)#cffunction name="init" access="public" output="false" hint="Constructor"#chr(62)#
		#chr(60)#cfreturn this /#chr(62)#
	#chr(60)#/cffunction#chr(62)#
	<cfloop from="1" to="#ArrayLen(arguments.cfcData.methods)#" index="local.thisMethod">
	#chr(60)#cffunction name="#arguments.cfcData.methods[local.thisMethod]#" access="public" output="false" hint=""#chr(62)#
		#chr(60)#cfthrow type="#arguments.cfcData.cfcName#.unimplementedMethod" message="Method #arguments.cfcData.methods[local.thisMethod]#() in component #arguments.cfcData.cfcName# not implemented yet." /#chr(62)#
	#chr(60)#/cffunction#chr(62)#
	</cfloop>
#chr(60)#/cfcomponent#chr(62)#	
		</cfsavecontent>
		</cfoutput>
		<cffile action="write" file="#getTargetDirectory()##arguments.cfcData.cfcName#.cfc" output="#Trim(local.cfcCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()##arguments.cfcData.cfcName#.cfc') />
	</cffunction>

	<cffunction name="createTestStub" access="private" output="false" hint="Create a single test harness stub.">
		<cfargument name="cfcData" required="true" hint="" />
		<cfset var local = StructNew() />
		
		<cfoutput>
		<cfsavecontent variable="local.testCode">	
#chr(60)#cfcomponent name="Test#arguments.cfcData.cfcName#" extends="#getFrameworkTestCasePath()#"#chr(62)#

	#chr(60)#cffunction name="setUp" access="public" output="false" hint=""#chr(62)#
		#chr(60)#cfset var local = StructNew() /#chr(62)#
		<cfif getCreateColdSpring()>#chr(60)#cfset local.serviceDefinitionLocation = ExpandPath( '#getRelativePath()#/coldspring.xml' ) /#chr(62)#
		#chr(60)#cfset local.beanFactory = CreateObject('component', 'coldspring.beans.DefaultXmlBeanFactory').init() /#chr(62)#
		#chr(60)#cfset local.beanFactory.loadBeansFromXmlFile(local.serviceDefinitionLocation) /#chr(62)#
		#chr(60)#cfset set#arguments.cfcData.cfcName#(local.beanFactory.getBean('#arguments.cfcData.cfcName#')) /#chr(62)#<cfelse>#chr(60)#cfset set#arguments.cfcData.cfcName#(CreateObject('component','#arguments.cfcData.cfcPath##arguments.cfcData.cfcName#').init()) /#chr(62)#</cfif>
	#chr(60)#/cffunction#chr(62)#
	<cfloop from="1" to="#ArrayLen(arguments.cfcData.methods)#" index="local.thisMethod">
	#chr(60)#cffunction name="test_#arguments.cfcData.methods[local.thisMethod]#" returntype="void" access="public" output="false" hint=""#chr(62)#
		#chr(60)#cfset var local = StructNew() /#chr(62)#
		#chr(60)#cfset fail('Test not yet implemented for method #arguments.cfcData.methods[local.thisMethod]#().') /#chr(62)#
	#chr(60)#/cffunction#chr(62)#
	</cfloop>
	#chr(60)#cffunction name="get#arguments.cfcData.cfcName#" access="private" output="false" hint="I return the #arguments.cfcData.cfcName#."#chr(62)#
		#chr(60)#cfreturn variables.instance.#arguments.cfcData.cfcName# /#chr(62)#
	#chr(60)#/cffunction#chr(62)#
		
	#chr(60)#cffunction name="set#arguments.cfcData.cfcName#" access="private" output="false" hint="I set the #arguments.cfcData.cfcName#."#chr(62)#
		#chr(60)#cfargument name="#arguments.cfcData.cfcName#" required="true" hint="#arguments.cfcData.cfcName#" /#chr(62)#
		#chr(60)#cfset variables.instance.#arguments.cfcData.cfcName# = arguments.#arguments.cfcData.cfcName# /#chr(62)#
	#chr(60)#/cffunction>
	
#chr(60)#/cfcomponent#chr(62)#
		</cfsavecontent>
		</cfoutput>
		<cffile action="write" file="#getTargetDirectory()#Test#arguments.cfcData.cfcName#.cfc" output="#Trim(local.testCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()#Test#arguments.cfcData.cfcName#.cfc') />
	</cffunction>
	
	<cffunction name="createMockStub" access="private" output="false" hint="Create a single CFC stub.">
		<cfargument name="cfcData" required="true" hint="" />
		<cfset var local = StructNew() />
		<cfoutput>
		<cfsavecontent variable="local.cfcCode">
#chr(60)#cfcomponent name="Mock#arguments.cfcData.cfcName#" extends="#getCFCPath()#.#arguments.cfcData.cfcName#" hint="I am a Mock object that can be used to replace the #arguments.cfcData.cfcName# CFC when testing other components."#chr(62)#

	#chr(60)#cffunction name="init" access="public" output="false" hint="Constructor"#chr(62)#
		#chr(60)#cfreturn this /#chr(62)#
	#chr(60)#/cffunction#chr(62)#
	<cfloop from="1" to="#ArrayLen(arguments.cfcData.methods)#" index="local.thisMethod">
	#chr(60)#cffunction name="#arguments.cfcData.methods[local.thisMethod]#" access="public" output="false" hint=""#chr(62)#
		#chr(60)#cfthrow type="Mock#arguments.cfcData.cfcName#.unimplementedMethod" message="Method #arguments.cfcData.methods[local.thisMethod]#() in component Mock#arguments.cfcData.cfcName# not implemented yet." /#chr(62)#
	#chr(60)#/cffunction#chr(62)#
	</cfloop>
#chr(60)#/cfcomponent#chr(62)#	
		</cfsavecontent>
		</cfoutput>
		<cffile action="write" file="#getTargetDirectory()#Mock#arguments.cfcData.cfcName#.cfc" output="#Trim(local.cfcCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()#Mock#arguments.cfcData.cfcName#.cfc') />
	</cffunction>
	
	<cffunction name="createColdSpringXML" access="private" output="false" hint="Create the ColdSpring XML file.">
		<cfset var local = StructNew() />
		<cfset local.cfcPath = getCFCPath() />
		<cfoutput>
		<cfsavecontent variable="local.coldSpringCode">
			
#chr(60)#!DOCTYPE beans PUBLIC "-//SPRING//DTD BEAN//EN" "http://www.springframework.org/dtd/spring-beans.dtd"#chr(62)#

#chr(60)#beans#chr(62)#
	
	<cfloop from="1" to="#ArrayLen(variables.instance.cfcData)#" index="local.thisCFC">#chr(60)#bean id="#variables.instance.cfcData[local.thisCFC].cfcName#" class="#local.cfcPath#.#variables.instance.cfcData[local.thisCFC].cfcName#" /#chr(62)#
	#chr(60)#bean id="Mock#variables.instance.cfcData[local.thisCFC].cfcName#" class="#local.cfcPath#.Mock#variables.instance.cfcData[local.thisCFC].cfcName#" /#chr(62)#
	</cfloop>
#chr(60)#/beans#chr(62)#
		</cfsavecontent>
		</cfoutput>
		<cffile action="write" file="#getTargetDirectory()#coldspring.xml" output="#Trim(local.coldSpringCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()#coldspring.xml') />
	</cffunction>
	
	<cffunction name="createTestRunner" access="private" output="false" hint="Create the test runner file.">
		<cfset var local = StructNew() />
		<cfset local.cfcPath = Replace(getRelativePath(), '/', '.', 'all') />
		<cfset local.cfcPath = Right(local.cfcPath, len(local.cfcPath)-1) />
		<cfoutput>
		<cfif getUnitTestFramework() eq 'cfunit'>
			<cfset local.runnerFileName = "testrunner.cfm" />	
			<cfsavecontent variable="local.runnerCode">	
#chr(60)#cfset cfUnitRoot = "net.sourceforge.cfunit" /#chr(62)#
#chr(60)#cfset tests = ArrayNew(1) /#chr(62)#

<cfloop from="1" to="#ArrayLen(variables.instance.cfcData)#" index="local.thisCFC">#chr(60)#cfset ArrayAppend(tests, "#local.cfcPath#.Test#variables.instance.cfcData[local.thisCFC].cfcName#") /#chr(62)#
</cfloop>
#chr(60)#cfset testSuite = CreateObject("component", "#chr(35)#CFUnitRoot#chr(35)#.framework.TestSuite").init(tests) /#chr(62)#
 
#chr(60)#h1#chr(62)#Test Results#chr(60)#/h1#chr(62)#
#chr(60)#cfset testSuite = CreateObject("component", "#chr(35)#CFUnitRoot#chr(35)#.framework.TestRunner").run(testSuite, 'Test Suite') /#chr(62)#
			</cfsavecontent>
		<cfelseif getUnitTestFramework() eq 'cfcunit'>
			<cfset local.runnerFileName = "AllTests.cfc" />
			<cfsavecontent variable="local.runnerCode">	
#chr(60)#cfcomponent displayname="AllTests" output="false"#chr(62)#  
	#chr(60)#cffunction name="suite" returntype="org.cfcunit.framework.TestSuite" access="public" output="false"#chr(62)#  
		#chr(60)#cfset var testSuite = CreateObject("component", "org.cfcunit.framework.TestSuite").init("Test Suite") /#chr(62)#
<cfloop from="1" to="#ArrayLen(variables.instance.cfcData)#" index="local.thisCFC">		#chr(60)#cfset testSuite.addTestSuite(CreateObject("component", "#local.cfcPath#.Test#variables.instance.cfcData[local.thisCFC].cfcName#")) /#chr(62)#  
</cfloop>
		#chr(60)#cfreturn testSuite/#chr(62)#
	#chr(60)#/cffunction#chr(62)# 
#chr(60)#/cfcomponent#chr(62)#
			</cfsavecontent>	
		</cfif>
		</cfoutput>
		<cffile action="write" file="#getTargetDirectory()##local.runnerFileName#" output="#Trim(local.runnerCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()##local.runnerFileName#') />
	</cffunction>
	
	<cffunction name="createTestANTBuildXML" access="private" output="false" hint="Create the ANT build script for CFUnit.">
		<cfset var local = StructNew() />
		<cfset local.cfcPath = Replace(getRelativePath(), '/', '.', 'all') />
		<cfset local.cfcPath = Right(local.cfcPath, len(local.cfcPath)-1) />
		<cfoutput>
		<cfif getUnitTestFramework() eq 'cfunit'>	
			<cfsavecontent variable="local.buildCode">
#chr(60)#?xml version="1.0"?#chr(62)#

#chr(60)#project name="CFUnit" default="allTests" basedir="."#chr(62)#
	#chr(60)#taskdef name="CFUnit" classname="net.sourceforge.cfunit.ant.CFUnit"/#chr(62)#
	
	#chr(60)#property name="domain" value="http://#getHostName()#/" /#chr(62)#
	#chr(60)#property name="path" value="#getRelativePath()#/" /#chr(62)#
	
	#chr(60)#target name="testgroup1"#chr(62)#
		<cfloop from="1" to="#ArrayLen(variables.instance.cfcData)#" index="local.thisCFC">#chr(60)#CFUnit testcase="${domain}${path}Test#variables.instance.cfcData[local.thisCFC].cfcName#.cfc" verbose="true" /#chr(62)#
		</cfloop>
	#chr(60)#/target#chr(62)#
	
	#chr(60)#!-- Use a comma-delimited list of target names to run multiple targets. --#chr(62)#
	#chr(60)#target name="allTests" depends="testgroup1" /#chr(62)#
	
#chr(60)#/project#chr(62)#
			</cfsavecontent>
		<cfelseif getUnitTestFramework() eq 'cfcunit'>
			<cfsavecontent variable="local.buildCode">
#chr(60)#?xml version="1.0"?#chr(62)#
#chr(60)#project default="allTests" name="MyTest"#chr(62)#

	#chr(60)#property name="cfcUnitLib" value="C:\Inetpub\wwwroot\org\cfcunit\lib" /#chr(62)#
	#chr(60)#property name="hostname" value="#getHostName()#" /#chr(62)#
	#chr(60)#property name="path" value="#local.cfcpath#." /#chr(62)#
	
	#chr(60)#taskdef resource="org/cfcunit/ant/antlib.xml"#chr(62)#  
		#chr(60)#classpath#chr(62)#  
			#chr(60)#pathelement location="lib/ant-cfcunit.jar"/#chr(62)#  
		#chr(60)#/classpath#chr(62)#  
	#chr(60)#/taskdef#chr(62)#
		
	#chr(60)#target name="testgroup1"#chr(62)#	
		#chr(60)#cfcunit verbose="true"#chr(62)#  
			#chr(60)#service hostname="${hostname}"/#chr(62)#
			#chr(60)#testclass name="${path}AllTests" /#chr(62)#
		#chr(60)#/cfcunit#chr(62)#		
  	#chr(60)#/target>
		
	#chr(60)#!-- Use a comma-delimited list of target names to run multiple targets. --#chr(62)#
	#chr(60)#target name="allTests" depends="testgroup1" /#chr(62)#
#chr(60)#/project#chr(62)#
			</cfsavecontent>
		</cfif>	
		</cfoutput>
		<cffile action="write" file="#getTargetDirectory()#build.xml" output="#Trim(local.buildCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()#build.xml') />
	</cffunction>
	
</cfcomponent>