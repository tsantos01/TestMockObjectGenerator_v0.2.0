<!--- 
LICENSE 
Copyright 2007 Brian Kotek

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--->

<!--- 
File: CFCStubGenerator.cfc
Author: Brian Kotek
Site: http://www.briankotek.com/blog

Usage:
This CFC uses an XMI file to create stubs for CFCs and CFUnit/CFCUnit unit test files. Just create an instance of 
the component, and call the createStubs() method. The easiest way it to run the index.cfm configuration screen included in 
this zip file. The CFC and CFUnit files will all be created in the same directory as the text file. Any CFC paths or 
folder paths will be created using the path to the text file directory as well.

This XMI to CFC generator has been tested with Poseidon Community Edition 6.0.

This file and related examples are available at my blog at www.briankotek.com/blog.
--->

<cfcomponent name="CFCStubGenerator" extends="CFCStubGenerator" hint="Given a properly formatted XMI file, I generate CFC stubs, test harness stubs, and a test runner file.">
	
	<cffunction name="init" access="public" hint="Constructor">
		<cfset super.init() />
		<cfreturn this />
	</cffunction>
	
	<cffunction name="readCFCDataFile" access="private" output="false" hint="Read in the specified CFC text file.">
		<cfargument name="cfcDataFile" required="true" hint="Absolute path to stub text file." />
		<cfoutput><cfsavecontent variable="local.cfcDataFile"><cfinclude template="#arguments.cfcDataFile#" /></cfsavecontent></cfoutput>
		<cfreturn local.cfcDataFile />
	</cffunction>

	<cffunction name="parseCFCDataFile" access="private" output="false" hint="Parse the specified CFC text file and create an Array of Structs to hold the CFC data.">
		<cfargument name="cfcXML" required="true" hint="Stub text file data." />
		<cfset var local = StructNew() />
		
		<!--- Parse the xml --->
		<cfset cfcXML = xmlparse(cfcXML) />
		<cfset setCFCXML(cfcXML) />
		<cfset setModelName() />
		
		<cfset buildInheritanceArray() />
		<cfset buildAbstractionArray() />
		<cfset buildAssociationArray() />
		
		<!--- Build array of interface objects --->
		<cfset setInterfaceArray(buildRawObjectData('interface')) />
		
		<!--- Build classes --->
		<cfset setClassArray(buildRawObjectData('class')) />
		
		<!--- Transform object data into a more managable data structure for CFC generation. --->
		<cfset setCFCArray(buildCFCArray(getClassArray())) />
		<cfset setCFInterfaceArray(buildCFCArray(getInterfaceArray())) />
		
	</cffunction>
	
	<cffunction name="createStubFiles" access="private" output="false" hint="Create the CFC and test harness stubs.">
		<cfset var local = StructNew() />
		<cfset local.cfcData = getCFCArray() />
		<cfloop from="1" to="#ArrayLen(local.cfcData)#" index="local.thisCFC">
			<cfset createCFCStub(local.cfcData[local.thisCFC], 'component') />
			<cfset createTestStub(local.cfcData[local.thisCFC]) />
			<cfif getCreateMocks() and not getUseColdMock()>
				<cfset createMockStub(local.cfcData[local.thisCFC]) />
			</cfif>
		</cfloop>
		<cfset local.cfcData = getCFInterfaceArray() />
		<cfloop from="1" to="#ArrayLen(local.cfcData)#" index="local.thisCFC">
			<cfset createCFCStub(local.cfcData[local.thisCFC], 'interface') />
		</cfloop>
	</cffunction>
	
	<cffunction name="createFullPathListOfTypes" access="private" returntype="string" output="false" hint="">
		<cfargument name="typeArray" type="array" required="true" />
		<cfset var local = structNew() />
		<cfset local.typeList = "" />
		<cfloop from="1" to="#ArrayLen(typeArray)#" index="local.thisType">
			<cfset local.typeList = ListAppend(local.typeList, getFullPathFromType(typeArray[local.thisType])) />
		</cfloop>
		<cfreturn local.typeList />
	</cffunction>
	
	<cffunction name="getFullPathFromType" access="private" returntype="string" output="false" hint="">
		<cfargument name="type" type="string" required="true" />
		<cfargument name="cfcPrefix" type="string" required="false" default="" />
		<cfargument name="prependBasePathForPreexistingCFC" type="string" required="false" default="false" />
		<cfset var local = structNew() />
		<cfset local.cfcArray = getCFCArray() />
		<cfset local.path = "" />
		
		<cfloop from="1" to="#ArrayLen(local.cfcArray)#" index="local.thisCFC">
			<cfif local.cfcArray[local.thisCFC].type eq arguments.type>
				<cfset local.path = local.cfcArray[local.thisCFC].path  />
				<cfif arguments.prependBasePathForPreexistingCFC and local.cfcArray[local.thisCFC].isPreexistingCFC and ListFirst(local.path, '.') neq getModelName()>
					<cfset local.path = getModelName() & '.' & local.path />	
				</cfif>
				<cfif Len(Trim(arguments.cfcPrefix))>
					<cfset local.path = local.path & '.' & LCase(arguments.cfcPrefix) />
				</cfif>	
				<cfset local.path = local.path & '.' & arguments.cfcPrefix & local.cfcArray[local.thisCFC].type />
				<cfbreak />
			</cfif>
		</cfloop>
		
		<cfif not Len(Trim(local.path))>
			<cfset local.cfInterfaceArray = getCFInterfaceArray() />
			<cfloop from="1" to="#ArrayLen(local.cfInterfaceArray)#" index="local.thisCFC">
				<cfif local.cfInterfaceArray[local.thisCFC].type eq arguments.type>
					<cfset local.path = local.cfInterfaceArray[local.thisCFC].path & '.' & local.cfInterfaceArray[local.thisCFC].type />
					<cfbreak />
				</cfif>
			</cfloop>
		</cfif>
		
		<cfif not Len(Trim(local.path))>
			<cfset local.path = arguments.type />
		</cfif>
		
		<cfreturn local.path />
		
	</cffunction>
	
	<cffunction name="createCFCStub" access="private" output="false" hint="Create a single CFC stub.">
		<cfargument name="cfcData" required="true" hint="" />
		<cfargument name="componentOrInterface" required="true" hint="" />
		<cfset var local = StructNew() />
		
		<cfif not arguments.cfcData.isPreexistingCFC>
			<cftry>
			<cfoutput>
			<cfsavecontent variable="local.cfcCode">
#chr(60)#<cfif arguments.componentOrInterface eq 'component'>cfcomponent<cfelse>cfinterface</cfif> name="#arguments.cfcData.type#" hint="#arguments.cfcData.hint#" <cfif StructKeyExists(arguments.cfcData, 'extends')> extends="#createFullPathListOfTypes(arguments.cfcData.extends)#"</cfif><cfif StructKeyExists(arguments.cfcData, 'implements')> implements="#createFullPathListOfTypes(arguments.cfcData.implements)#"</cfif><cfif getAddAggregates() and StructKeyExists(arguments.cfcData, 'has_a')> aggregates="#createFullPathListOfTypes(arguments.cfcData.has_a)#"</cfif>#chr(62)#
<cfloop from="1" to="#ArrayLen(arguments.cfcData.properties)#" index="local.thisProperty"><cfif arguments.cfcData.properties[local.thisProperty].access eq 'public'>	#chr(60)#cfproperty name="#arguments.cfcData.properties[local.thisProperty].name#" type="#getFullPathFromType(arguments.cfcData.properties[local.thisProperty].type)#" /#chr(62)#
</cfif></cfloop>
<cfloop from="1" to="#ArrayLen(arguments.cfcData.properties)#" index="local.thisProperty"><cfif arguments.cfcData.properties[local.thisProperty].access eq 'public'>	#chr(60)#cfset this.#arguments.cfcData.properties[local.thisProperty].name# = "" /#chr(62)#
</cfif></cfloop>

<cfloop from="1" to="#ArrayLen(arguments.cfcData.properties)#" index="local.thisProperty"><cfif arguments.cfcData.properties[local.thisProperty].access neq 'public'>	#chr(60)#cfset variables.instance.#arguments.cfcData.properties[local.thisProperty].name# = "" /#chr(62)#
</cfif></cfloop>
	<cfloop from="1" to="#ArrayLen(arguments.cfcData.methods)#" index="local.thisMethod">
	#chr(60)#cffunction name="#arguments.cfcData.methods[local.thisMethod].name#" returnType="#getFullPathFromType(arguments.cfcData.methods[local.thisMethod].returnType)#" access="#arguments.cfcData.methods[local.thisMethod].access#" output="false"<cfif getDocumentationLocation() is "hint"> hint="#arguments.cfcData.methods[local.thisMethod].hint#"</cfif>#chr(62)#
<cfloop from="1" to="#ArrayLen(arguments.cfcData.methods[local.thisMethod].arguments)#" index="local.thisArgument">		#chr(60)#cfargument name="#arguments.cfcData.methods[local.thisMethod].arguments[local.thisArgument].name#" type="#getFullPathFromType(arguments.cfcData.methods[local.thisMethod].arguments[local.thisArgument].type)#" required="true" hint="#arguments.cfcData.methods[local.thisMethod].arguments[local.thisArgument].hint#" /#chr(62)##getCRLF()#</cfloop>
<cfif getDocumentationLocation() is "body" and Len(Trim(arguments.cfcData.methods[local.thisMethod].hint))>		#chr(60)#!--- #arguments.cfcData.methods[local.thisMethod].hint# ---#chr(62)#</cfif>

<cfif arguments.componentOrInterface eq 'component'>
<cfif not arguments.cfcData.methods[local.thisMethod].isAbstract and getCreateGetSet() and isSetter(arguments.cfcData.methods[local.thisMethod].name) and ArrayLen(arguments.cfcData.methods[local.thisMethod].arguments) eq 1>
		#chr(60)#cfset variables.instance.#getVarNameFromMethod(arguments.cfcData.methods[local.thisMethod].name)# = arguments.#arguments.cfcData.methods[local.thisMethod].arguments[1].name# /#chr(62)#
<cfelseif not arguments.cfcData.methods[local.thisMethod].isAbstract and getCreateGetSet() and isGetter(arguments.cfcData.methods[local.thisMethod].name)>
		#chr(60)#cfreturn variables.instance.#getVarNameFromMethod(arguments.cfcData.methods[local.thisMethod].name)# /#chr(62)#
<cfelseif arguments.cfcData.methods[local.thisMethod].name eq 'init'>
		#chr(60)#cfreturn this /#chr(62)#
<cfelseif not arguments.cfcData.methods[local.thisMethod].isAbstract>
		#chr(60)#cfthrow type="#arguments.cfcData.type#.unimplementedMethod" message="Method #arguments.cfcData.methods[local.thisMethod].name#() in component #arguments.cfcData.type# not implemented yet." /#chr(62)#
<cfelse>
		#chr(60)#cfthrow type="#arguments.cfcData.type#.unimplementedMethod" message="Method #arguments.cfcData.methods[local.thisMethod].name#() in component #arguments.cfcData.type# is abstract and must be overridden by a subclass." /#chr(62)#</cfif></cfif>
	#chr(60)#/cffunction#chr(62)#
	</cfloop>
#chr(60)#/<cfif arguments.componentOrInterface eq 'component'>cfcomponent<cfelse>cfinterface</cfif>#chr(62)#	
			</cfsavecontent>
			</cfoutput>
			
			<cfcatch type="any">
				<cfoutput>
				Error attempting to create CFC stub. The error was: #cfcatch.Message#<br/>
				<cfif FindNoCase('returnType', cfcatch.message)>
					The error appears to be due to a method in <cfif arguments.componentOrInterface eq 'component'>cfcomponent<cfelse>cfinterface</cfif> #arguments.cfcData.type# that does not have a valid return type.<br/>
				<cfelseif FindNoCase('type', cfcatch.message)>	
					The error appears to be due to an argument in <cfif arguments.componentOrInterface eq 'component'>cfcomponent<cfelse>cfinterface</cfif> #arguments.cfcData.type# that does not have a valid type.<br/>
				</cfif>
				</cfoutput>
				<cfabort>	
			</cfcatch>
			
			</cftry>
			
			<cfif not DirectoryExists('#getAbsolutePathFromType(arguments.cfcData.path)#')>
				<cfdirectory action="create" directory="#getAbsolutePathFromType(arguments.cfcData.path)#" />
			</cfif>
			
			<cfset local.targetFile = "#getAbsolutePathFromType(arguments.cfcData.path)##arguments.cfcData.type#.cfc" />
			<cfif not FileExists(local.targetFile)>
				<cffile action="write" file="#local.targetFile#" output="#formatCFCOutput(local.cfcCode)#" addnewline="false" />
				<cfset ArrayAppend(variables.instance.createdStubs, '#local.targetFile#') />
			</cfif>
		</cfif>
	</cffunction>
	
	<cffunction name="createTestStub" access="private" output="false" hint="Create a single test harness stub.">
		<cfargument name="cfcData" required="true" hint="" />
		<cfset var local = StructNew() />
		
		<cfoutput>
		<cfsavecontent variable="local.testCode">	
#chr(60)#cfcomponent name="Test#arguments.cfcData.type#" extends="#getFrameworkTestCasePath()#"#chr(62)#

	#chr(60)#cffunction name="setUp" access="public" output="false" hint=""#chr(62)#
		#chr(60)#cfset var local = StructNew() /#chr(62)#
		<cfif getCreateColdSpring()>#chr(60)#cfset local.serviceDefinitionLocation = ExpandPath( '#getRelativePath()#/testsuite/coldspring.xml' ) /#chr(62)#
		#chr(60)#cfset beanFactory = CreateObject('component', 'coldspring.beans.DefaultXmlBeanFactory').init() /#chr(62)#
		#chr(60)#cfset beanFactory.loadBeansFromXmlFile(local.serviceDefinitionLocation) /#chr(62)#
		#chr(60)#cfset set#arguments.cfcData.type#(beanFactory.getBean('#arguments.cfcData.type#')) /#chr(62)#
<cfif getUseColdMock() and StructKeyExists(arguments.cfcData, 'has_a')><cfloop from="1" to="#ArrayLen(arguments.cfcData.has_a)#" index="local.thisAggregate">		#chr(60)#cfset #arguments.cfcData.has_a[local.thisAggregate]# = beanFactory.getBean('Mock#arguments.cfcData.has_a[local.thisAggregate]#') /#chr(62)#
</cfloop></cfif><cfelse>		#chr(60)#cfset set#arguments.cfcData.type#(CreateObject('component','#getFullPathFromType(arguments.cfcData.type)#').init()) /#chr(62)#</cfif>
	#chr(60)#/cffunction#chr(62)#
	<cfloop from="1" to="#ArrayLen(arguments.cfcData.methods)#" index="local.thisMethod"><cfif not arguments.cfcData.methods[local.thisMethod].isAbstract and arguments.cfcData.methods[local.thisMethod].name neq 'init' and ListFindNoCase('public', arguments.cfcData.methods[local.thisMethod].access)>
	#chr(60)#cffunction name="test_#arguments.cfcData.methods[local.thisMethod].name#" returntype="void" access="public" output="false" hint=""#chr(62)#
		#chr(60)#cfset var local = StructNew() /#chr(62)#
		#chr(60)#cfset fail('Test not yet implemented for method #arguments.cfcData.methods[local.thisMethod].name#().') /#chr(62)#
	#chr(60)#/cffunction#chr(62)#
	</cfif></cfloop>
	#chr(60)#cffunction name="get#arguments.cfcData.type#" access="private" output="false" hint="I return the #arguments.cfcData.type#."#chr(62)#
		#chr(60)#cfreturn variables.instance.#arguments.cfcData.type# /#chr(62)#
	#chr(60)#/cffunction#chr(62)#
		
	#chr(60)#cffunction name="set#arguments.cfcData.type#" access="private" output="false" hint="I set the #arguments.cfcData.type#."#chr(62)#
		#chr(60)#cfargument name="#arguments.cfcData.type#" required="true" hint="#arguments.cfcData.type#" /#chr(62)#
		#chr(60)#cfset variables.instance.#arguments.cfcData.type# = arguments.#arguments.cfcData.type# /#chr(62)#
	#chr(60)#/cffunction>
	
#chr(60)#/cfcomponent#chr(62)#
		</cfsavecontent>
		</cfoutput>
		
		<cfif not DirectoryExists('#getAbsolutePathFromType(arguments.cfcData.path, arguments.cfcData.isPreexistingCFC)#test')>
			<cfdirectory action="create" directory="#getAbsolutePathFromType(arguments.cfcData.path, arguments.cfcData.isPreexistingCFC)#test" />
		</cfif>
		<cfset local.targetFile = "#getAbsolutePathFromType(arguments.cfcData.path, arguments.cfcData.isPreexistingCFC)#test#getOSPathDelimeter()#Test#arguments.cfcData.type#.cfc" />
		
		<cfif not FileExists(local.targetFile)>
			<cffile action="write" file="#local.targetFile#" output="#formatCFCOutput(local.testCode)#" addnewline="false" />
			<cfset ArrayAppend(variables.instance.createdStubs, '#local.targetFile#') />
		</cfif>	
	</cffunction>
	
	<cffunction name="createMockStub" access="private" output="false" hint="Create a single CFC stub.">
		<cfargument name="cfcData" required="true" hint="" />
		<cfset var local = StructNew() />
		
		<cfoutput>
		<cfsavecontent variable="local.cfcCode">
#chr(60)#cfcomponent name="Mock#arguments.cfcData.type#" extends="#getFullPathFromType(arguments.cfcData.type)#" <cfif StructKeyExists(arguments.cfcData, 'implements')> implements="#createFullPathListOfTypes(arguments.cfcData.implements)#" </cfif> hint="I am a Mock object that can be used to replace the #arguments.cfcData.type# CFC when testing other components."#chr(62)#

	<cfloop from="1" to="#ArrayLen(arguments.cfcData.methods)#" index="local.thisMethod"><cfif ListFindNoCase('public,package', arguments.cfcData.methods[local.thisMethod].access)>
	#chr(60)#cffunction name="#arguments.cfcData.methods[local.thisMethod].name#" returnType="#getFullPathFromType(arguments.cfcData.methods[local.thisMethod].returnType)#" access="#arguments.cfcData.methods[local.thisMethod].access#" output="false" hint="#arguments.cfcData.methods[local.thisMethod].hint#"#chr(62)#
<cfloop from="1" to="#ArrayLen(arguments.cfcData.methods[local.thisMethod].arguments)#" index="local.thisArgument">		#chr(60)#cfargument name="#arguments.cfcData.methods[local.thisMethod].arguments[local.thisArgument].name#" type="#getFullPathFromType(arguments.cfcData.methods[local.thisMethod].arguments[local.thisArgument].type)#" required="true" hint="#arguments.cfcData.methods[local.thisMethod].arguments[local.thisArgument].hint#" /#chr(62)##getCRLF()#</cfloop>
		<cfif arguments.cfcData.methods[local.thisMethod].name eq 'init'>#chr(60)#cfreturn this /#chr(62)#<cfelse>#chr(60)#cfthrow type="Mock#arguments.cfcData.type#.unimplementedMethod" message="Method #arguments.cfcData.methods[local.thisMethod].name#() in component #arguments.cfcData.type# not implemented yet." /#chr(62)#</cfif>
	#chr(60)#/cffunction#chr(62)#
	</cfif></cfloop>
#chr(60)#/cfcomponent#chr(62)#
		</cfsavecontent>
		</cfoutput>
		
		<cfif not DirectoryExists('#getAbsolutePathFromType(arguments.cfcData.path, arguments.cfcData.isPreexistingCFC)#mock')>
			<cfdirectory action="create" directory="#getAbsolutePathFromType(arguments.cfcData.path, arguments.cfcData.isPreexistingCFC)#mock" />
		</cfif>
		
		<cfset local.targetFile = "#getAbsolutePathFromType(arguments.cfcData.path, arguments.cfcData.isPreexistingCFC)#mock#getOSPathDelimeter()#Mock#arguments.cfcData.type#.cfc" />
		<cfif not FileExists(local.targetFile)>
			<cffile action="write" file="#local.targetFile#" output="#formatCFCOutput(local.cfcCode)#" addnewline="false" />
			<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()#mock#getOSPathDelimeter()#Mock#arguments.cfcData.type#.cfc') />
		</cfif>
	</cffunction>
	
	<cffunction name="createColdSpringXML" access="private" output="false" hint="Create the ColdSpring XML file.">
		<cfset var local = StructNew() />
		<cfset local.cfcPath = getCFCPath() />
		
		<cfoutput>
		<cfsavecontent variable="local.coldSpringCode">
			
#chr(60)#!DOCTYPE beans PUBLIC "-//SPRING//DTD BEAN//EN" "http://www.springframework.org/dtd/spring-beans.dtd"#chr(62)#

#chr(60)#beans#chr(62)#	
	<cfloop from="1" to="#ArrayLen(variables.instance.cfcArray)#" index="local.thisCFC">
<cfif StructKeyExists(variables.instance.cfcArray[local.thisCFC], 'has_a')>	#chr(60)#bean id="#variables.instance.cfcArray[local.thisCFC].type#" class="#getFullPathFromType(variables.instance.cfcArray[local.thisCFC].type)#"#chr(62)#
<cfloop from="1" to="#ArrayLen(variables.instance.cfcArray[local.thisCFC].has_a)#" index="local.thisAggregate">		#chr(60)#property name="#variables.instance.cfcArray[local.thisCFC].has_a[local.thisAggregate]#"#chr(62)#	
			#chr(60)#ref bean="<cfif getCreateMocks()>Mock</cfif>#variables.instance.cfcArray[local.thisCFC].has_a[local.thisAggregate]#" /#chr(62)#
		#chr(60)#/property#chr(62)#
</cfloop>	#chr(60)#/bean#chr(62)#<cfelse>	#chr(60)#bean id="#variables.instance.cfcArray[local.thisCFC].type#" class="#getFullPathFromType(variables.instance.cfcArray[local.thisCFC].type)#" /#chr(62)#</cfif>		
	<cfif getCreateMocks() and not getUseColdMock()>#chr(60)#bean id="Mock#variables.instance.cfcArray[local.thisCFC].type#" class="#getFullPathFromType(variables.instance.cfcArray[local.thisCFC].type, 'Mock', true)#" /#chr(62)#<cfelseif getCreateMocks() and getUseColdMock()>
	#chr(60)#bean id="Mock#variables.instance.cfcArray[local.thisCFC].type#" factory-bean="MockFactory" factory-method="createMock"#chr(62)#
		#chr(60)#constructor-arg name="objectToMock"#chr(62)#
			#chr(60)#value#chr(62)##getFullPathFromType(variables.instance.cfcArray[local.thisCFC].type)##chr(60)#/value#chr(62)#
		#chr(60)#/constructor-arg#chr(62)#
	#chr(60)#/bean#chr(62)#</cfif>
</cfloop><cfif getUseColdMock()>
	#chr(60)#bean id="MockFactory" class="coldmock.MockFactory" /#chr(62)#</cfif>
	
#chr(60)#/beans#chr(62)#
		</cfsavecontent>
		</cfoutput>
		
		<cfif not DirectoryExists('#getTargetDirectory()#testsuite')>
			<cfdirectory action="create" directory="#getTargetDirectory()#testsuite" />
		</cfif>
		<cffile action="write" file="#getTargetDirectory()#testsuite#getOSPathDelimeter()#coldspring.xml" output="#formatCFCOutput(local.coldSpringCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()#testsuite#getOSPathDelimeter()#coldspring.xml') />
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

<cfloop from="1" to="#ArrayLen(variables.instance.cfcArray)#" index="local.thisCFC">#chr(60)#cfset ArrayAppend(tests, "#getFullPathFromType(variables.instance.cfcArray[local.thisCFC].type, 'Test', variables.instance.cfcArray[local.thisCFC].isPreexistingCFC)#") /#chr(62)#
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
<cfloop from="1" to="#ArrayLen(variables.instance.cfcArray)#" index="local.thisCFC">		#chr(60)#cfset testSuite.addTestSuite(CreateObject("component", "#getFullPathFromType(variables.instance.cfcArray[local.thisCFC].type, 'Test', variables.instance.cfcArray[local.thisCFC].isPreexistingCFC)#")) /#chr(62)#
</cfloop>
		#chr(60)#cfreturn testSuite/#chr(62)#
	#chr(60)#/cffunction#chr(62)# 
#chr(60)#/cfcomponent#chr(62)#
			</cfsavecontent>
		</cfif>
		</cfoutput>
		<cfif not DirectoryExists('#getTargetDirectory()#testsuite')>
			<cfdirectory action="create" directory="#getTargetDirectory()#testsuite" />
		</cfif>
		<cffile action="write" file="#getTargetDirectory()#testsuite#getOSPathDelimeter()##local.runnerFileName#" output="#formatCFCOutput(local.runnerCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()#testsuite#getOSPathDelimeter()##local.runnerFileName#') />
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
	#chr(60)#property name="path" value="#getRelativePath()#/testsuite/" /#chr(62)#
	
	#chr(60)#target name="testgroup1"#chr(62)#
		<cfloop from="1" to="#ArrayLen(variables.instance.cfcArray)#" index="local.thisCFC">#chr(60)#CFUnit testcase="${domain}#Replace(getFullPathFromType(variables.instance.cfcArray[local.thisCFC].type, 'Test'), '.', '/', 'all')#.cfc" verbose="true" /#chr(62)#
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
	#chr(60)#property name="path" value="#local.cfcpath#.testsuite." /#chr(62)#
	
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
		<cfif not DirectoryExists('#getTargetDirectory()#testsuite')>
			<cfdirectory action="create" directory="#getTargetDirectory()#testsuite" />
		</cfif>
		<cffile action="write" file="#getTargetDirectory()#testsuite#getOSPathDelimeter()#build.xml" output="#formatCFCOutput(local.buildCode)#" addnewline="false" />
		<cfset ArrayAppend(variables.instance.createdStubs, '#getTargetDirectory()#testsuite#getOSPathDelimeter()#build.xml') />
	</cffunction>
	
	<cffunction name="buildCFCArray" access="private" returntype="array" output="false" hint="">
		<cfargument name="objectArray" type="array" required="true" />
		<cfset var local = structNew() />
		<!--- Build more managable CF specific arrays. --->
		<cfset local.cfcArray = ArrayNew(1) />
		
		<cfloop from="1" to="#ArrayLen(arguments.objectArray)#" index="local.thisClass">
			<cfset local.cfcData = StructNew() />
			<cfset local.cfcData.type = arguments.objectArray[local.thisClass].attributes.name />
			<cfset local.cfcData.hint = arguments.objectArray[local.thisClass].hint />
			<cfset local.cfcData.path = arguments.objectArray[local.thisClass].path />
			<cfset local.cfcData.isAbstract = false />
			<cfset local.cfcData.isPreexistingCFC = false />
			<cfif arguments.objectArray[local.thisClass].attributes.isAbstract>
				<cfset local.cfcData.isAbstract = true />
			</cfif>
			<cfif StructKeyExists(arguments.objectArray[local.thisClass].attributes, 'isActive') and arguments.objectArray[local.thisClass].attributes.isActive>
				<cfset local.cfcData.isPreexistingCFC = true />
			</cfif>
			
			<cfset local.cfcData.properties = ArrayNew(1) />
			<cfloop from="1" to="#ArrayLen(arguments.objectArray[local.thisClass].properties)#" index="local.thisProperty">
				<cfset local.tempProperty = StructNew() />
				<cfset local.tempProperty.name = arguments.objectArray[local.thisClass].properties[local.thisProperty].attributes.name />
				<cfset local.tempProperty.access = arguments.objectArray[local.thisClass].properties[local.thisProperty].attributes.visibility />
				<cfset local.tempProperty.type = arguments.objectArray[local.thisClass].properties[local.thisProperty].type />
				<cfset ArrayAppend(local.cfcData.properties, local.tempProperty) />
			</cfloop>
			
			<cfset local.cfcData.methods = ArrayNew(1) />
			<cfloop from="1" to="#ArrayLen(arguments.objectArray[local.thisClass].operations)#" index="local.thisMethod">
				<cfset local.tempMethod = StructNew() />
				<cfset local.tempMethod.name = arguments.objectArray[local.thisClass].operations[local.thisMethod].attributes.name />
				<cfset local.tempMethod.arguments = ArrayNew(1) />
				<cftry>
				<cfloop from="1" to="#ArrayLen(arguments.objectArray[local.thisClass].operations[local.thisMethod].parameters)#" index="local.thisParameter">
					<cfif arguments.objectArray[local.thisClass].operations[local.thisMethod].parameters[local.thisParameter].attributes.kind eq "in">
						<cfset argumentData = StructNew() />
						<cfset argumentData.name = arguments.objectArray[local.thisClass].operations[local.thisMethod].parameters[local.thisParameter].attributes.name />
						<cfset argumentData.type = arguments.objectArray[local.thisClass].operations[local.thisMethod].parameters[local.thisParameter].types[1].type />
						<cfset argumentData.hint = arguments.objectArray[local.thisClass].operations[local.thisMethod].parameters[local.thisParameter].hint />
						<cfset ArrayAppend(local.tempMethod.arguments, argumentData) />
					<cfelse>
						<cfset local.tempMethod.returnType = arguments.objectArray[local.thisClass].operations[local.thisMethod].parameters[local.thisParameter].types[1].type />
					</cfif>
				</cfloop>
				<cfcatch type="any">
					<cfthrow message="Could not find argument or return type for method '#local.cfcData.type#.#local.tempMethod.name#'." />
				</cfcatch>
				</cftry>
				<cfset local.tempMethod.access = arguments.objectArray[local.thisClass].operations[local.thisMethod].attributes.visibility />
				<cfset local.tempMethod.hint = arguments.objectArray[local.thisClass].operations[local.thisMethod].hint />
				
				<cfset local.tempMethod.isAbstract = false />
				<cfif arguments.objectArray[local.thisClass].operations[local.thisMethod].attributes.isAbstract>
					<cfset local.tempMethod.isAbstract = true />
				</cfif>
				
				<cfset ArrayAppend(local.cfcData.methods, local.tempMethod) />
			</cfloop>
			
			<cfif StructKeyExists(arguments.objectArray[local.thisClass], 'associations')>
				<cfset local.cfcData.has_a = ArrayNew(1) />
				<cfloop from="1" to="#ArrayLen(arguments.objectArray[local.thisClass].associations)#" index="thisAssociation">
					<cfset ArrayAppend(local.cfcData.has_a, arguments.objectArray[local.thisClass].associations[thisAssociation].type) />
				</cfloop>
			</cfif>
			
			<cfif StructKeyExists(arguments.objectArray[local.thisClass], 'extends')>
				<cfset local.cfcData.extends = ArrayNew(1) />
				<cfloop from="1" to="#ArrayLen(arguments.objectArray[local.thisClass].extends)#" index="local.thisSuperclass">
					<cfset ArrayAppend(local.cfcData.extends, arguments.objectArray[local.thisClass].extends[local.thisSuperclass].type) />
				</cfloop>
			</cfif>
						
			<cfif StructKeyExists(arguments.objectArray[local.thisClass], 'implements')>
				<cfset local.cfcData.implements = ArrayNew(1) />
				<cfloop from="1" to="#ArrayLen(arguments.objectArray[local.thisClass].implements)#" index="local.thisInterface">
					<cfset ArrayAppend(local.cfcData.implements, arguments.objectArray[local.thisClass].implements[local.thisInterface].type) />
				</cfloop>
			</cfif>
			
			<cfset ArrayAppend(local.cfcArray, local.cfcData) />	
		</cfloop>
		<cfreturn local.cfcArray />
	</cffunction>
	
	<cffunction name="buildInheritanceArray" access="private" returntype="void" output="false" hint="">
		<cfset var local = structNew() />
		<cfset local.inheritance = XMLSearch(getCFCXML(), "//UML:Model[@name]//UML:Generalization[@xmi.id]") />
		<cfset local.inheritanceArray = ArrayNew(1) />
		
		<cfloop from="1" to="#ArrayLen(local.inheritance)#" index="local.thisInheritance">
			<cfset local.thisInheritanceXMLPath = "//UML:Generalization[@xmi.id='#local.inheritance[local.thisInheritance].XMLAttributes['xmi.id']#']" />
			<cfset local.inheritanceData = StructNew() />
			<cfset local.inheritanceData.attributes = local.inheritance[local.thisInheritance].XMLAttributes />
			
			<cfset local.temp = XMLSearch(getCFCXML(), "//UML:Generalization[@xmi.id='#local.inheritance[local.thisInheritance].XMLAttributes['xmi.id']#']//UML:Generalization.child//UML:Class | //UML:Generalization[@xmi.id='#local.inheritance[local.thisInheritance].XMLAttributes['xmi.id']#']//UML:Generalization.child//UML:Interface") />
			<cfset local.inheritanceData.child = StructNew() />
			<cfset local.inheritanceData.child['xmi.idref'] = local.temp[1].xmlAttributes['xmi.idref'] />
			<cfset local.tempTypeReference = XMLSearch(getCFCXML(), "//UML:Class[@xmi.id='#local.temp[1].xmlAttributes['xmi.idref']#'] | //UML:Interface[@xmi.id='#local.temp[1].xmlAttributes['xmi.idref']#']") />
			<cfset local.inheritanceData.child.type = local.tempTypeReference[1].xmlAttributes.name />
			
			<cfset local.temp = XMLSearch(getCFCXML(), "//UML:Generalization[@xmi.id='#local.inheritance[local.thisInheritance].XMLAttributes['xmi.id']#']//UML:Generalization.parent//UML:Class | //UML:Generalization[@xmi.id='#local.inheritance[local.thisInheritance].XMLAttributes['xmi.id']#']//UML:Generalization.parent//UML:Interface") />
			<cfset local.inheritanceData.parent = StructNew() />
			<cfset local.inheritanceData.parent['xmi.idref'] = local.temp[1].xmlAttributes['xmi.idref'] />
			<cfset local.tempTypeReference = XMLSearch(getCFCXML(), "//UML:Class[@xmi.id='#local.temp[1].xmlAttributes['xmi.idref']#'] | //UML:Interface[@xmi.id='#local.temp[1].xmlAttributes['xmi.idref']#']") />
			<cfset local.inheritanceData.parent.type = local.tempTypeReference[1].xmlAttributes.name />
			
			<cfset ArrayAppend(local.inheritanceArray, local.inheritanceData) />	
		</cfloop>
		<cfset setInheritanceArray(local.inheritanceArray) />
	</cffunction>
	
	<cffunction name="buildAbstractionArray" access="private" returntype="void" output="false" hint="">
		<cfset var local = structNew() />
		
		<cfset local.abstractions = XMLSearch(getCFCXML(), "//UML:Model[@name]//UML:Abstraction[@xmi.id]") />
		<cfset local.abstractionArray = ArrayNew(1) />
		
		<cfloop from="1" to="#ArrayLen(local.abstractions)#" index="local.thisAbstraction">
			<cfset local.thisAbstractionXMLPath = "//UML:Abstraction[@xmi.id='#local.abstractions[local.thisAbstraction].XMLAttributes['xmi.id']#']" />
			<cfset local.abstractionData = StructNew() />
			<cfset local.abstractionData.attributes = local.abstractions[local.thisAbstraction].XMLAttributes />
			
			<cfset local.tempClient = XMLSearch(getCFCXML(), "#local.thisAbstractionXMLPath#//UML:Dependency.client//UML:Class") />
			<cfset local.abstractionData.client['xmi.idref'] = local.tempClient[1].xmlAttributes['xmi.idref'] />
			<cfset tempTypeReference = XMLSearch(getCFCXML(), "//UML:Class[@xmi.id='#local.tempClient[1].xmlAttributes['xmi.idref']#']") />
			<cfset local.abstractionData.client.type = tempTypeReference[1].xmlAttributes.name />
			
			<cfset local.tempSupplier = XMLSearch(getCFCXML(), "#local.thisAbstractionXMLPath#//UML:Dependency.supplier//UML:Interface") />
			<cfset local.abstractionData.supplier['xmi.idref'] = local.tempSupplier[1].xmlAttributes['xmi.idref'] />
			<cfset tempTypeReference = XMLSearch(getCFCXML(), "//UML:Interface[@xmi.id='#local.tempSupplier[1].xmlAttributes['xmi.idref']#']") />
			<cfset local.abstractionData.supplier.type = tempTypeReference[1].xmlAttributes.name />
			
			<cfset ArrayAppend(local.abstractionArray, local.abstractionData) />
		</cfloop>
		<cfset setAbstractionArray(local.abstractionArray) />
	</cffunction>
	
	<cffunction name="buildAssociationArray" access="private" returntype="void" output="false" hint="">
		<cfset var local = structNew() />
		
		<cfset local.associations = XMLSearch(getCFCXML(), "//UML:Model[@name]//UML:Association[@xmi.id]") />
		<cfset local.associationArray = ArrayNew(1) />
		
		<cfloop from="1" to="#ArrayLen(local.associations)#" index="local.thisAssociation">
			<cfset local.thisAssociationXMLPath = "//UML:Association[@xmi.id='#local.associations[local.thisAssociation].XMLAttributes['xmi.id']#']" />
			<cfset local.associationData = StructNew() />
			<cfset local.associationData.attributes = local.associations[local.thisAssociation].XMLAttributes />
			<cfset local.associationData.associationEnds = ArrayNew(1) />
			
			<cfset local.associationEnds = XMLSearch(getCFCXML(), "#local.thisAssociationXMLPath#//UML:AssociationEnd") />
			
			<cfloop from="1" to="#ArrayLen(local.associationEnds)#" index="local.thisEnd">
				<cfset local.associationEndData = StructNew() />
				<cfset local.associationEndData.attributes = local.associationEnds[local.thisEnd].xmlAttributes />
				<cfset local.participant = XMLSearch(getCFCXML(), "#local.thisAssociationXMLPath#//UML:AssociationEnd[@xmi.id='#local.associationEnds[local.thisEnd].xmlAttributes['xmi.id']#']//UML:AssociationEnd.participant//UML:Class") />
				<cfset local.associationEndData.participant = StructNew() />
				<cfset local.associationEndData.participant['xmi.idref'] = local.participant[1].xmlAttributes['xmi.idref'] />
				
				<cfset local.tempTypeReference = XMLSearch(getCFCXML(), "//UML:Class[@xmi.id='#local.participant[1].xmlAttributes['xmi.idref']#']") />
				<cfset local.associationEndData.participant.type = local.tempTypeReference[1].xmlAttributes.name />
				
				<cfset ArrayAppend(local.associationData.associationEnds, local.associationEndData) />
			</cfloop>
			
			<cfset ArrayAppend(local.associationArray, local.associationData) />	
		</cfloop>
		<cfset setAssociationArray(local.associationArray) />
		
	</cffunction>
	
	<cffunction name="buildRawObjectData" access="private" returntype="array" output="false" hint="">
		<cfargument name="objectType" type="string" required="true" />
		<cfset var local = structNew() />
		
		<cfif objectType eq 'interface'>
			<cfset local.objectType = 'Interface' />
			<cfset xmlArray = XMLSearch(getCFCXML(), "//UML:Model[@name]//UML:Interface[@xmi.id]") />
		<cfelseif objectType eq 'class'>
			<cfset local.objectType = 'Class' />
			<cfset xmlArray = XMLSearch(getCFCXML(), '//UML:Model[@name]//UML:Class[@name]') />
		</cfif>
		
		<cfset local.objectArray = buildObjects(xmlArray, local.objectType) />
		
		<cfreturn local.objectArray />
		
	</cffunction>
	
	<cffunction name="buildObjects" access="private" returntype="array" output="false" hint="">
		<cfargument name="xmlArray" type="array" required="true" />
		<cfargument name="objectType" type="string" required="true" />
		<cfset var local = StructNew() />
		
		<cfset local.objectArray = ArrayNew(1) />
		<cfloop from="1" to="#ArrayLen(arguments.xmlArray)#" index="local.thisObject">
			<cfset local.thisObjectXMLPath = "//UML:Model[@name]//UML:#arguments.objectType#[@xmi.id='#arguments.xmlArray[local.thisObject].xmlAttributes['xmi.id']#']" />
			<cfset local.objectData = StructNew() />
			<cfset local.objectData.attributes = arguments.xmlArray[local.thisObject].xmlAttributes />
			<cfset local.objectData.path = buildPathForObject(local.thisObjectXMLPath) />
			<cfset local.objectData.properties = buildPropertiesForObject(local.thisObjectXMLPath) />
			<cfset local.objectData.operations = buildOperationsForObject(local.thisObjectXMLPath) />
			<cfset local.objectData.hint = getHint(local.thisObjectXMLPath) />
			
			<cfset local.inheritanceArray = buildInheritanceForObject(local.objectData.attributes['xmi.id']) />
			<cfif ArrayLen(local.inheritanceArray)>
				<cfset local.objectData.extends = local.inheritanceArray />
			</cfif>
			
			<!--- If this is a full CFC and not an interface, determine associations and interfaces. --->
			<cfif arguments.objectType eq 'class'>
				
				<cfset local.associationArray = buildAssociationsForObject(local.objectData.attributes['xmi.id']) />
				<cfif ArrayLen(local.associationArray)>
					<cfset local.objectData.associations = local.associationArray />
				</cfif>
				
				<cfset local.interfaceArray = buildInterfacesForObject(local.objectData.attributes['xmi.id']) />
				<cfif ArrayLen(local.interfaceArray)>
					<cfset local.objectData.implements = local.interfaceArray />
				</cfif>
				
			</cfif>
			
			<cfset ArrayAppend(local.objectArray, local.objectData) />
		</cfloop>
		
		<cfreturn local.objectArray />
	</cffunction>
	
	<cffunction name="buildInterfacesForObject" access="private" returntype="array" output="false" hint="">
		<cfargument name="childXMIID" type="string" required="true" />
		<cfset var local = structNew() />
		<cfset local.implements = ArrayNew(1) />
		<cfset local.abstractionArray = getAbstractionArray() />
		<cfloop from="1" to="#ArrayLen(local.abstractionArray)#" index="local.thisAbstraction">
			<cfif arguments.childXMIID eq local.abstractionArray[local.thisAbstraction].client['xmi.idref']>
				<cfset local.interfaceData = StructNew() />
				<cfset local.interfaceData['xmi.idref'] = local.abstractionArray[local.thisAbstraction].supplier['xmi.idref'] />
				<cfset local.interfaceData.type = local.abstractionArray[local.thisAbstraction].supplier.type />
				<cfset ArrayAppend(local.implements, local.interfaceData)/>
			</cfif>
		</cfloop>
		<cfreturn local.implements />
	</cffunction>
	
	
	<cffunction name="buildAssociationsForObject" access="private" returntype="array" output="false" hint="">
		<cfargument name="aggregatorXMIID" type="string" required="true" />
		<cfset var local = structNew() />
		<cfset local.associations = ArrayNew(1) />
		<cfset local.associationArray = getAssociationArray() />
		<cfloop from="1" to="#ArrayLen(local.associationArray)#" index="local.thisAssociation">
			<cfloop from="1" to="#ArrayLen(local.associationArray[local.thisAssociation].associationEnds)#" index="local.thisEnd">
				<cfif arguments.aggregatorXMIID eq local.associationArray[local.thisAssociation].associationEnds[local.thisEnd].participant['xmi.idref'] and
					  local.associationArray[local.thisAssociation].associationEnds[local.thisEnd].attributes.aggregation neq "none">
					<cfloop from="1" to="#ArrayLen(local.associationArray[local.thisAssociation].associationEnds)#" index="local.thisOtherEnd">
						<cfif arguments.aggregatorXMIID neq local.associationArray[local.thisAssociation].associationEnds[local.thisOtherEnd].participant['xmi.idref']>
							<cfparam name="local.objectData.associations" default="#ArrayNew(1)#" />
							<cfset local.associationData = StructNew() />
							<cfset local.associationData['xmi.idref'] = local.associationArray[local.thisAssociation].associationEnds[local.thisOtherEnd].participant['xmi.idref'] />
							<cfset local.associationData.type = local.associationArray[local.thisAssociation].associationEnds[local.thisOtherEnd].participant.type />
							<cfset ArrayAppend(local.associations, local.associationData) />
						</cfif>
					</cfloop>
				</cfif>
			</cfloop>
		</cfloop>
		<cfreturn local.associations />
	</cffunction>
	
	<cffunction name="buildInheritanceForObject" access="private" returntype="array" output="false" hint="">
		<cfargument name="childXMIID" type="string" required="true" />
		<cfset var local = structNew() />
		<cfset local.extends = ArrayNew(1) />
		<cfset local.inheritanceArray = getInheritanceArray() />
		<cfloop from="1" to="#ArrayLen(local.inheritanceArray)#" index="local.thisInheritance">
			<cfif arguments.childXMIID eq local.inheritanceArray[local.thisInheritance].child['xmi.idref']>
				<cfset local.tempInheritance = StructNew() />
				<cfset local.tempInheritance['xmi.idref'] = local.inheritanceArray[local.thisInheritance].child['xmi.idref'] />
				<cfset local.tempInheritance.type = local.inheritanceArray[local.thisInheritance].parent.type />
				<cfset ArrayAppend(local.extends, local.tempInheritance) />
			</cfif>
		</cfloop>
		<cfreturn local.extends />
	</cffunction>
	
	<cffunction name="buildPathForObject" access="private" returntype="string" output="false" hint="">
		<cfargument name="xmlPath" type="string" required="true" />
		<cfset var local = structNew() />
		<cfset packages = XMLSearch(getCFCXML(), "#arguments.xmlPath#/ancestor::UML:Package") />
		<cfset local.path = getModelName() />
		<cfloop from="1" to="#ArrayLen(packages)#" index="local.thisPackage">
			<cfif not packages[local.thisPackage].xmlAttributes.isRoot>
				<cfset local.path = local.path & '.' & packages[local.thisPackage].xmlAttributes.name />
			<cfelseif local.thisPackage eq 1>
				<cfset local.path = packages[local.thisPackage].xmlAttributes.name />	
			</cfif>
		</cfloop>
		<cfreturn local.path />
	</cffunction>
	
	<cffunction name="buildPropertiesForObject" access="private" returntype="array" output="false" hint="">
		<cfargument name="xmlPath" type="string" required="true" />
		<cfset var local = structNew() />
		
		<cfset local.properties = XMLSearch(getCFCXML(), "#arguments.xmlPath#//UML:Attribute[@name]") />
		<cfset local.propertyArray = ArrayNew(1) />
		
		<!--- Get each operation --->
		<cfloop from="1" to="#ArrayLen(local.properties)#" index="local.thisProperty">
			<cfset local.thisPropertyXMLPath = "//UML:Attribute[@xmi.id='#local.properties[local.thisProperty].xmlAttributes['xmi.id']#']" />
			<cfset local.propertyData = StructNew() />
			<cfset local.propertyData.attributes = local.properties[local.thisProperty].xmlAttributes />
			<cfset local.tempTypeTranslation = buildParameterTypes(local.thisPropertyXMLPath) />
			<cfset local.propertyData.type = local.tempTypeTranslation[1].type />
			<cfset ArrayAppend(local.propertyArray, local.propertyData) />
		</cfloop>
		
		<cfreturn local.propertyArray />
	</cffunction>
	
	<cffunction name="buildOperationsForObject" access="private" returntype="array" output="false" hint="">
		<cfargument name="xmlPath" type="string" required="true" />
		<cfset var local = structNew() />
		
		<cfset local.operations = XMLSearch(getCFCXML(), "#arguments.xmlPath#//UML:Operation[@name]") />
		<cfset local.operationArray = ArrayNew(1) />
		
		<!--- Get each operation --->
		<cfloop from="1" to="#ArrayLen(local.operations)#" index="local.thisOperation">
			<cfset local.thisOperationXMLPath = "//UML:Operation[@xmi.id='#local.operations[local.thisOperation].xmlAttributes['xmi.id']#']" />
			<cfset local.operationData = StructNew() />
			<cfset local.operationData.attributes = local.operations[local.thisOperation].xmlAttributes />
			<cfset local.operationData.parameters = buildParametersForOperation("#local.thisOperationXMLPath#//UML:Parameter[@name]") />
			<cfset local.operationData.hint = getHint(local.thisOperationXMLPath) />
			<cfset ArrayAppend(local.operationArray, local.operationData) />
		</cfloop>
		
		<cfreturn local.operationArray />
	</cffunction>
	
	
	<cffunction name="buildParametersForOperation" access="private" returntype="array" output="false" hint="">
		<cfargument name="xmlPath" type="string" required="true" />
		<cfset var local = structNew() />
		<cfset local.parameters = XMLSearch(getCFCXML(), arguments.xmlPath) />
		<cfset local.parameterArray = ArrayNew(1) />
		
		<!--- Get each operation parameter. --->
		<cfloop from="1" to="#ArrayLen(local.parameters)#" index="local.thisParameter">
			<cfset local.thisParameterXMLPath = "//UML:Parameter[@xmi.id='#local.parameters[local.thisParameter].xmlAttributes['xmi.id']#']" />
			<cfset local.parameterData = StructNew() />
			<cfset local.parameterData.attributes = local.parameters[local.thisParameter].xmlAttributes />
			<cfset local.parameterData.types = buildParameterTypes(local.thisParameterXMLPath) />
			<cfset local.parameterData.hint = getHint(local.thisParameterXMLPath) />
			<cfset ArrayAppend(local.parameterArray, local.parameterData) />
		</cfloop>
		
		<cfreturn local.parameterArray />
	</cffunction>
	
	<cffunction name="getHint" access="private" returntype="string" output="false" hint="">
		<cfargument name="xmlPath" type="string" required="true" />
		<cfset var local = structNew() />
		<!--- Find hint specified Node. --->
		<cfset local.hint = "" />
		<cfset local.tempHint = XMLSearch(getCFCXML(), "#arguments.xmlPath#/UML:ModelElement.taggedValue/UML:TaggedValue/UML:TaggedValue.dataValue") />
		<cfif ArrayLen(local.tempHint)>
			<cfset local.hint = local.tempHint[1].xmlText />
		</cfif>
		<cfif getStripHTMLFromDocumentation()>
			<cfset local.hint = stripHTMLTagsFromString(local.hint) />
		</cfif>
		<cfreturn local.hint />
	</cffunction>
	
	<cffunction name="buildParameterTypes" access="private" returntype="array" output="false" hint="">
		<cfargument name="xmlPath" type="string" required="true" />
		<cfset var local = structNew() />
		<cfset local.typeArray = ArrayNew(1) />
		<cfset local.typeArray = translateParameterType(local.typeArray, arguments.xmlPath, 'class') />
		<cfset local.typeArray = translateParameterType(local.typeArray, arguments.xmlPath, 'datatype') />
		<cfset local.typeArray = translateParameterType(local.typeArray, arguments.xmlPath, 'interface') />
		<cfreturn local.typeArray />
	</cffunction>
	
	<cffunction name="translateParameterType" access="private" returntype="array" output="false" hint="">
		<cfargument name="typeArray" type="array" required="true" />
		<cfargument name="xmlPath" type="string" required="true" />
		<cfargument name="typeCategory" type="string" required="true" />
		<cfset var local = structNew() />
		
		<cfif arguments.typeCategory eq 'class'>
			<cfset local.targetType = "Class" />
		<cfelseif arguments.typeCategory eq 'datatype'>
			<cfset local.targetType = "DataType" />
		<cfelseif arguments.typeCategory eq 'interface'>
			<cfset local.targetType = "Interface" />	
		</cfif>
		
		<!--- Find parameters that reference other CFCs or data types. --->
		<cfset local.parameterTypes = XMLSearch(getCFCXML(), "#arguments.xmlPath#//UML:#local.targetType#") />
		<cfloop from="1" to="#ArrayLen(local.parameterTypes)#" index="local.thisType">
			<cfset local.thisParameterTypeData = StructNew() />
			<cfset local.thisParameterTypeData.attributes = local.parameterTypes[local.thisType].xmlAttributes />
			<cfset local.tempTypeReference = XMLSearch(getCFCXML(), "//UML:#local.targetType#[@xmi.id='#local.parameterTypes[local.thisType].xmlAttributes['xmi.idref']#']") />
			<cfset local.thisParameterTypeData.type = local.tempTypeReference[1].xmlAttributes.name />
			<cfset ArrayAppend(arguments.typeArray, local.thisParameterTypeData) />
		</cfloop>
		
		<cfreturn arguments.typeArray />
	</cffunction>
	
	<cffunction name="getInterfaceArray" access="private" returntype="array" output="false" hint="I return the interfaceArray.">
		<cfreturn variables.instance.interfaceArray />
	</cffunction>
		
	<cffunction name="setInterfaceArray" access="private" returntype="void" output="false" hint="I set the interfaceArray.">
		<cfargument name="interfaceArray" type="array" required="true" hint="interfaceArray" />
		<cfset variables.instance.interfaceArray = arguments.interfaceArray />
	</cffunction>
	
	<cffunction name="getClassArray" access="private" returntype="array" output="false" hint="I return the classArray.">
		<cfreturn variables.instance.classArray />
	</cffunction>
		
	<cffunction name="setClassArray" access="private" returntype="void" output="false" hint="I set the classArray.">
		<cfargument name="classArray" type="array" required="true" hint="classArray" />
		<cfset variables.instance.classArray = arguments.classArray />
	</cffunction>
	
	<cffunction name="getCFCXML" access="private" returntype="xml" output="false" hint="I return the cfcXML.">
		<cfreturn variables.instance.cfcXML />
	</cffunction>
		
	<cffunction name="setCFCXML" access="private" returntype="void" output="false" hint="I set the cfcXML.">
		<cfargument name="cfcXML" type="xml" required="true" hint="cfcXML" />
		<cfset variables.instance.cfcXML = arguments.cfcXML />
	</cffunction>
	
	<cffunction name="getInheritanceArray" access="private" returntype="array" output="false" hint="I return the inheritanceArray.">
		<cfreturn variables.instance.inheritanceArray />
	</cffunction>
		
	<cffunction name="setInheritanceArray" access="private" returntype="void" output="false" hint="I set the inheritanceArray.">
		<cfargument name="inheritanceArray" type="array" required="true" hint="inheritanceArray" />
		<cfset variables.instance.inheritanceArray = arguments.inheritanceArray />
	</cffunction>
	
	<cffunction name="getAbstractionArray" access="private" returntype="array" output="false" hint="I return the abstractionArray.">
		<cfreturn variables.instance.abstractionArray />
	</cffunction>
		
	<cffunction name="setAbstractionArray" access="private" returntype="void" output="false" hint="I set the abstractionArray.">
		<cfargument name="abstractionArray" type="array" required="true" hint="abstractionArray" />
		<cfset variables.instance.abstractionArray = arguments.abstractionArray />
	</cffunction>
	
	<cffunction name="getAssociationArray" access="private" returntype="array" output="false" hint="I return the associationArray.">
		<cfreturn variables.instance.associationArray />
	</cffunction>
		
	<cffunction name="setAssociationArray" access="private" returntype="void" output="false" hint="I set the associationArray.">
		<cfargument name="associationArray" type="array" required="true" hint="associationArray" />
		<cfset variables.instance.associationArray = arguments.associationArray />
	</cffunction>
	
	<cffunction name="getModelName" access="private" returntype="string" output="false" hint="I return the modelName.">
		<cfreturn variables.instance.modelName />
	</cffunction>
		
	<cffunction name="setModelName" access="private" returntype="void" output="false" hint="I set the modelName.">
		<cfset var local = StructNew() />
		<cfset local.model = XMLSearch(getCFCXML(), '//UML:Model[@name]') />
		<cfset variables.instance.modelName = local.model[1].xmlAttributes.name />
	</cffunction>
	
	<cffunction name="getCFCArray" access="private" returntype="array" output="false" hint="I return the cfcArray.">
		<cfreturn variables.instance.cfcArray />
	</cffunction>
		
	<cffunction name="setCFCArray" access="private" returntype="void" output="false" hint="I set the cfcArray.">
		<cfargument name="cfcArray" type="array" required="true" hint="cfcArray" />
		<cfset variables.instance.cfcArray = arguments.cfcArray />
	</cffunction>
	
	<cffunction name="getCFInterfaceArray" access="private" returntype="array" output="false" hint="I return the cfInterfaceArray.">
		<cfreturn variables.instance.cfInterfaceArray />
	</cffunction>
		
	<cffunction name="setCFInterfaceArray" access="private" returntype="void" output="false" hint="I set the cfInterfaceArray.">
		<cfargument name="cfInterfaceArray" type="array" required="true" hint="cfInterfaceArray" />
		<cfset variables.instance.cfInterfaceArray = arguments.cfInterfaceArray />
	</cffunction>
	
	<cffunction name="getAbsolutePathFromType" access="private" returntype="string" output="false" hint="">
		<cfargument name="path" type="string" required="true" />
		<cfargument name="isPreexistingCFC" type="boolean" required="false" default="false" />
		<cfif arguments.isPreexistingCFC and ListFirst(arguments.path, '.') neq getModelName()>
			<cfset arguments.path = getModelName() & '.' & arguments.path />	
		</cfif>
		<cfreturn ExpandPath('/#Replace(arguments.path, '.', '/', 'all')#/') />
	</cffunction>
	
	<cffunction name="formatCFCOutput" access="private" returntype="string" output="false" hint="">
		<cfargument name="cfcOutput" type="string" required="true" />
		<cfreturn Trim(ReplaceNoCase(ReplaceNoCase(arguments.cfcOutput, '#getCRLF()##getCRLF()##getCRLF()#', getCRLF(), 'all'), '#getCRLF()##getCRLF()#', getCRLF(), 'all')) />
	</cffunction>
	
	<cffunction name="isSetter" access="private" returntype="string" output="false" hint="">
		<cfargument name="methodName" type="string" required="true" />
		<cfset var local = structNew() />
		<cfset local.isSetter = false />
		<cfif Left(arguments.methodName, 3) eq "set">
			<cfset local.isSetter = true />
		</cfif>
		<cfreturn local.isSetter />	
	</cffunction>
	
	<cffunction name="isGetter" access="private" returntype="string" output="false" hint="">
		<cfargument name="methodName" type="string" required="true" />
		<cfset var local = structNew() />
		<cfset local.isGetter = false />
		<cfif Left(arguments.methodName, 3) eq "get">
			<cfset local.isGetter = true />
		</cfif>
		<cfreturn local.isGetter />
	</cffunction>
	
	<cffunction name="getVarNameFromMethod" access="private" returntype="string" output="false" hint="">
		<cfargument name="methodName" type="string" required="true" />
		<cfreturn "#LCase(Mid(arguments.methodName, 4, 1))##Right(arguments.methodName, Len(arguments.methodName)-4)#" />
	</cffunction>
	
</cfcomponent>