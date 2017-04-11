package fr.inria.diverse.objectalgebragenerator

import ale.xtext.ale.AddOperation
import ale.xtext.ale.AleClass
import ale.xtext.ale.Block
import ale.xtext.ale.BooleanAndOperation
import ale.xtext.ale.BooleanLiteral
import ale.xtext.ale.BooleanOrOperation
import ale.xtext.ale.BooleanXorOperation
import ale.xtext.ale.ChainedCall
import ale.xtext.ale.ChainedCallArrow
import ale.xtext.ale.CompareGEOperation
import ale.xtext.ale.CompareGOperation
import ale.xtext.ale.CompareLEOperation
import ale.xtext.ale.CompareLOperation
import ale.xtext.ale.CompareNEOperation
import ale.xtext.ale.ConstructorOperation
import ale.xtext.ale.DivOperation
import ale.xtext.ale.EqualityOperation
import ale.xtext.ale.Expression
import ale.xtext.ale.ForLoop
import ale.xtext.ale.IfStatement
import ale.xtext.ale.ImpliesOperation
import ale.xtext.ale.IntLiteral
import ale.xtext.ale.IntRange
import ale.xtext.ale.LetStatement
import ale.xtext.ale.LiteralType
import ale.xtext.ale.MultOperation
import ale.xtext.ale.NegInfixOperation
import ale.xtext.ale.NotInfixOperation
import ale.xtext.ale.NullLiteral
import ale.xtext.ale.OADenot
import ale.xtext.ale.OperationCallOperation
import ale.xtext.ale.OrderedSetDecl
import ale.xtext.ale.OrderedSetType
import ale.xtext.ale.OutOfScopeType
import ale.xtext.ale.RealLiteral
import ale.xtext.ale.ReturnStatement
import ale.xtext.ale.Root
import ale.xtext.ale.SelfRef
import ale.xtext.ale.SequenceDecl
import ale.xtext.ale.SequenceType
import ale.xtext.ale.StringLiteral
import ale.xtext.ale.SubOperation
import ale.xtext.ale.SuperRef
import ale.xtext.ale.Type
import ale.xtext.ale.VarAssign
import ale.xtext.ale.VarRef
import ale.xtext.ale.WhileStatement
import fr.inria.diverse.objectalgebragenerator.Graph.GraphNode
import java.util.Collection
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.ETypedElement

//import ale.xtext.ale.OADenot

class GenerateAlgebra {

	public def List<EClass> getListAllClasses(EPackage ePackage, List<EPackage> dependencies) {
		val graph = buildGraph(ePackage, dependencies)
		graph.nodes.map[elem].toList
	}

	public def Graph<EClass> buildGraph(EPackage ePackage, List<EPackage> otherPackages) {
		val graph1 = new Graph<EClass>()
		val vp = newHashSet()
		visitPackages(vp, ePackage, graph1)
		if(otherPackages != null) otherPackages.forEach[visitPackages(vp, it, graph1)]
		graph1
	}

	private def Map<String, List<GraphNode<EClass>>> buildAllTypes(List<List<GraphNode<EClass>>> clusters) {
		clusters.toMap(new CharsSequence)
	}

	private def List<List<GraphNode<EClass>>> calculateClusters(Graph<EClass> graphCurrentPackage) {
		graphCurrentPackage.clusters().map[x|x.sortBy[y|y.elem.name]].sortBy[z|z.head.elem.name].toList
	}

	def calculateAllTypes(EPackage ePackage, boolean global) {
		buildConcretTypes(buildAllTypes(calculateClusters(buildGraph(ePackage, null)))).mapValues [ e |
			if(global) e else e.filter[f|f.elem.EPackage.equals(ePackage)]
		].filter[p1, p2|!p2.empty]

	}

	private def String operationInterfacePath(EClass clazz, 
		AleClass aleClazz) {
			val ecoreName = clazz.EPackage.name
			val aleName = if (aleClazz != null) (aleClazz.eContainer as Root).name else "$default"
		'''«ecoreName».«aleName».algebra.operation.«ecoreName.toFirstUpper»«aleName.toFirstUpper»«clazz.name.toFirstUpper»Operation'''
		}

	def String processConcreteOperation(GraphNode<EClass> entry, EPackage epackage, List<EPackage> dependencies, AleClass behaviorClass, Boolean overloaded, List<AleClass> allAleClasses) {
		val clazz = entry.elem
		val graph = buildGraph(epackage, null)
		
		val packageName = entry.elem.EPackage.name
		val aleName = if (behaviorClass != null) (behaviorClass.eContainer as Root).name else "$default"
		
		val className= '''«packageName.toFirstUpper»«aleName.toFirstUpper»«clazz.name.toFirstUpper»Operation'''
		
		'''
		package «packageName».«aleName».algebra.impl.operation;
		public class «className» implements «clazz.operationInterfacePath(behaviorClass)» { 
					
					
			private class EListCollector<T> implements java.util.stream.Collector<T, org.eclipse.emf.common.util.EList<T>, org.eclipse.emf.common.util.EList<T>> {
		
				@Override
				public java.util.function.Supplier<org.eclipse.emf.common.util.EList<T>> supplier() {
					return org.eclipse.emf.common.util.BasicEList::new;
				}
		
				@Override
				public java.util.function.BiConsumer<org.eclipse.emf.common.util.EList<T>, T> accumulator() {
					return (a, b) -> a.add(b);
				}
		
				@Override
				public java.util.function.BinaryOperator<org.eclipse.emf.common.util.EList<T>> combiner() {
					return (a, b) -> {
						a.addAll(b);
						return a;
					};
				}
		
				@Override
				public java.util.function.Function<org.eclipse.emf.common.util.EList<T>, org.eclipse.emf.common.util.EList<T>> finisher() {
					return java.util.function.Function.identity();
				}
		
				@Override
				public java.util.Set<java.util.stream.Collector.Characteristics> characteristics() {
					java.util.HashSet<java.util.stream.Collector.Characteristics> hashSet = new java.util.HashSet<>();
					hashSet.add(java.util.stream.Collector.Characteristics.UNORDERED);
					return hashSet;
				}
		
			}
				
			private final «clazz.javaFullPath» self;
			private final «epackage.name».algebra.«epackage.name.toFirstUpper»Algebra«FOR clazzS : graph.nodes.sortBy[x|x.elem.name] BEFORE '<' SEPARATOR ', ' AFTER '>'»? extends «clazzS.elem.operationInterfacePath(clazzS.elem.findAleClass(allAleClasses))»«ENDFOR» algebra;
			«IF behaviorClass != null && behaviorClass.superClass != null»
			«FOR sc: behaviorClass.superClass.map[cl | cl.getEClass(epackage, dependencies)].filter[x | x != null]»
«««			// delegate«sc.name»
			private final «sc.EPackage.name.toFirstUpper»«sc.name.toFirstUpper»Operation(final «sc.javaFullPath» delegate«sc.name.toFirstUpper»
			«ENDFOR»
			«ENDIF»
			
			public «className»(final «clazz.javaFullPath» self, final «epackage.name».algebra.«epackage.name.toFirstUpper»Algebra«FOR clazzS : graph.nodes.sortBy[x|x.elem.name] BEFORE '<' SEPARATOR ', ' AFTER '>'»? extends «clazzS.elem.operationInterfacePath(clazzS.elem.findAleClass(allAleClasses))»«ENDFOR» algebra) {
				this.self = self;
				this.algebra = algebra;
			}
			
			
			
			
			«IF behaviorClass != null»
			«FOR field:behaviorClass.fields»
			public «field.type.solveStaticType(epackage, dependencies)» get«field.name.toFirstUpper»() {
				«IF ! overloaded»return self.get«field.name.toFirstUpper»();«ELSE»return null;«ENDIF»
			}
			public void set«field.name.toFirstUpper»(«field.type.solveStaticType(epackage, dependencies)» «field.name») {
				«IF !overloaded»self.set«field.name.toFirstUpper»(«field.name»);«ENDIF»
			}
			«ENDFOR»
			«FOR method: behaviorClass.methods»
			public «method.type.solveStaticType(epackage, dependencies)» «method.name»(«FOR p: method.params»«p.type.solveStaticType(epackage, dependencies)» «p.name»«ENDFOR») {
	 			«IF !overloaded»«method.block.printBlock(epackage, dependencies)»«ELSE» «IF method.type.solveStaticType(epackage, dependencies) != 'void'»return null;«ENDIF»«ENDIF»
			}
			«ENDFOR»
			«ENDIF»
		}
		'''

	}
	
	def EClass getEClass(AleClass aleClass, EPackage epackage, List<EPackage> dependencies) {
		val classes = this.getListAllClasses(epackage, dependencies)
		val res = classes.filter[c | c.name == aleClass.name].head
		return res;
	}
	
	def String printBlock(Block block, EPackage ePackage, List<EPackage> dependencies) '''
	«FOR stmt: block.body»
	«stmt.printStatement(ePackage, dependencies)»
	«ENDFOR»
	'''
	
	
	def dispatch String printExpression(AddOperation addOperation, EPackage epackage) {
		'''«addOperation.left.printExpression(epackage)» + «addOperation.right.printExpression(epackage)»'''
	}
	
	def dispatch String printExpression(BooleanAndOperation booleanAndOperation, EPackage epackage) 
		'''«booleanAndOperation.left.printExpression(epackage)» && «booleanAndOperation.right.printExpression(epackage)»'''
	
	def dispatch String printExpression(BooleanLiteral booleanLit, EPackage epackage) {
		return booleanLit.value
	}
	
	def dispatch String printExpression(BooleanOrOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» || «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(BooleanXorOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» ^ «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(ChainedCall exp, EPackage epackage) '''«exp.left.printExpression(epackage)».«exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(ChainedCallArrow exp, EPackage epackage) '''«exp.left.printExpression(epackage)».«exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(CompareGEOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» >= «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(CompareGOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» > «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(CompareLEOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» <= «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(CompareLOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» < «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(CompareNEOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» != «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(DivOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» / «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(EqualityOperation exp, EPackage epackage) '''java.util.Objects.equals(«exp.left.printExpression(epackage)», «exp.right.printExpression(epackage)»)'''
	def dispatch String printExpression(ImpliesOperation exp, EPackage epackage) '''!«exp.left.printExpression(epackage)» || «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(IntLiteral exp, EPackage epackage) '''«exp.value»'''
	def dispatch String printExpression(IntRange exp, EPackage epackage) '''__TODO IntRange__'''
	def dispatch String printExpression(MultOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» * «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(NegInfixOperation exp, EPackage epackage) '''-«exp.expression.printExpression(epackage)»'''
	def dispatch String printExpression(NotInfixOperation exp, EPackage epackage) '''!«exp.expression.printExpression(epackage)»'''
	def dispatch String printExpression(NullLiteral exp, EPackage epackage) '''null'''
	def dispatch String printExpression(OperationCallOperation exp, EPackage epackage) {
		if(exp.eContainer instanceof ChainedCallArrow) {
			return switch(exp.name) {
				case 'select': '''stream().filter(«exp.parameters.head.lambda» -> «exp.parameters.head.expression.printExpression(epackage)»).collect(new EListCollector<>())'''
				case  'reject': '''stream().filter(«exp.parameters.head.lambda» -> !(«exp.parameters.head.expression.printExpression(epackage)»)).collect(new EListCollector<>())'''
				case 'collect': '''stream().map(«exp.parameters.head.lambda» -> «exp.parameters.head.expression.printExpression(epackage)»).collect(new EListCollector<>())'''
				case  'any': '''stream().filter(«exp.parameters.head.lambda» -> «exp.parameters.head.expression.printExpression(epackage)»).findAny().orElse(null)''' 
				case 'exists' : '''stream().stream().findAny().map(«exp.parameters.head.lambda» -> «exp.parameters.head.expression.printExpression(epackage)»).orElse(false)'''
				case  'forAll': '''stream().stream().allMatch(«exp.parameters.head.lambda» -> «exp.parameters.head.expression.printExpression(epackage)»)'''
				case 'isUnique' : '''__TODO__'''
				case 'one' : '''__TODO__'''
				case 'sortedBy': '''__TODO__''' 
				case  'closure':'''__TODO__'''
			}
		} else {
			if(exp.name == 'println') exp.name='System.out.println';
			'''«exp.name»(«FOR param: exp.parameters SEPARATOR ',' »«IF param.lambda!= null»«param.lambda» -> «ENDIF»«param.expression.printExpression(epackage)»«ENDFOR»)''' // TODO deal with lambdas !
		}
	}
	def dispatch String printExpression(OrderedSetDecl exp, EPackage epackage) '''__TODO OrderSetDecl__'''
	def dispatch String printExpression(RealLiteral exp, EPackage epackage) '''«exp.value»'''
	def dispatch String printExpression(OADenot exp, EPackage epackage) '''algebra.$(«exp.exp.printExpression(epackage)»)'''
	def dispatch String printExpression(SelfRef exp, EPackage epackage) '''self''' // TODO: probably more smart than that!! aka delegation
	def dispatch String printExpression(SequenceDecl exp, EPackage epackage) '''__TODO SequenceDECL__'''
	def dispatch String printExpression(StringLiteral exp, EPackage epackage) '''"«exp.value»"'''
	def dispatch String printExpression(SubOperation exp, EPackage epackage) '''«exp.left.printExpression(epackage)» - «exp.right.printExpression(epackage)»'''
	def dispatch String printExpression(SuperRef exp, EPackage epackage) '''__TODO call super__''' // TODO: has to resolve where to call!!
	def dispatch String printExpression(VarRef exp, EPackage epackage) '''«exp.value»'''
	def dispatch String printExpression(ConstructorOperation exp, EPackage epackage) '''«exp.getPackageName(epackage)»Factory.eINSTANCE.create«exp.name»()'''
	
	def String getPackageName(ConstructorOperation co, EPackage epackage) {
		val graph = buildGraph(epackage, null)
		var packageName = graph.nodes.filter[e | e.elem.name == co.name].head.elem.EPackage.name
		return '''«packageName».«packageName.toFirstUpper»'''
		
	}
	
	def dispatch String printStatement(Expression expression, EPackage ePackage, List<EPackage> dependencies) '''«expression.printExpression(ePackage)»;'''
	
	def dispatch String printStatement(ForLoop forLoop, EPackage ePackage, List<EPackage> dependencies) {
		'''
		for(«forLoop.type.solveStaticType(ePackage, dependencies)» «forLoop.name»: «forLoop.collection.printExpression(ePackage)») {
			«forLoop.block.printBlock(ePackage, dependencies)»
		}
		'''
	}
	
	def dispatch String printStatement(IfStatement ifStatement, EPackage ePackage, List<EPackage> dependencies) {
		'''if(«ifStatement.condition.printExpression(ePackage)») {
			«ifStatement.thenBranch.printBlock(ePackage, dependencies)»
		} «IF ifStatement.elseBranch != null» else {
			«ifStatement.elseBranch.printBlock(ePackage, dependencies)»
		}
		«ENDIF»'''
	}
	
	def dispatch String printStatement(LetStatement letStatement, EPackage ePackage, List<EPackage> dependencies) {
		'''__TODO__'''
	}
	
	def dispatch String printStatement(ReturnStatement returnStatement, EPackage ePackage, List<EPackage> dependencies) {
		'''return «returnStatement.returned.printExpression(ePackage)»;'''
	}
	
	def dispatch String printStatement(VarAssign varAssign, EPackage ePackage, List<EPackage> dependencies) 
		'''«varAssign.type.solveStaticType(ePackage, dependencies)» «varAssign.name» = «varAssign.value.printExpression(ePackage)»;'''
	
	
	def dispatch String printStatement(WhileStatement whileStatement, EPackage ePackage, List<EPackage> dependencies) {
		'''
		while(«whileStatement.condition.printExpression(ePackage)») {
			«whileStatement.whileBlock.printBlock(ePackage, dependencies)»
		}
		'''
	}
	
	def findAleClass(EClass clazz, List<AleClass> allClasses) {
		allClasses.findFirst[ac | ac.name == clazz.name || clazz.name.endsWith("_Aspect") && ac.name == clazz.name.substring(0, clazz.name.length-"_Aspect".length) ]
	}
	
	
	def findNameOrDefault(AleClass clazz) {
		if(clazz != null) {
			(clazz.eContainer as Root).name
		} else {
			"$default"
		}
	}

	def String processConcreteAlgebra(EPackage ePackage, List<EPackage> dependencies, List<AleClass> allAleClasses) {
		/*
		 * Here we have to generate one method per class
		 */
		val graph = buildGraph(ePackage, dependencies)

		'''
			package «ePackage.name».algebra.impl;
			
			public interface «ePackage.name.toFirstUpper»AlgebraImpl extends «ePackage.name».algebra.«ePackage.name.toFirstUpper»Algebra
				«FOR clazz : graph.nodes.sortBy[x|x.elem	.name].map[elem] BEFORE '<' SEPARATOR ',' AFTER '>'»«clazz.operationInterfacePath(clazz.findAleClass(allAleClasses))»«ENDFOR» {
				«FOR clazz : graph.nodes.sortBy[elem.name].filter[c|!c.elem.abstract].map[elem]»
					@Override
					default «clazz.operationInterfacePath(clazz.findAleClass(allAleClasses))» «clazz.name.toFirstLower»(final «clazz.javaFullPath» «clazz.name.toFirstLower») {
						return new «clazz.EPackage.name».«clazz.findAleClass(allAleClasses).findNameOrDefault».algebra.impl.operation.«clazz.EPackage.name.toFirstUpper»«clazz.findAleClass(allAleClasses).findNameOrDefault.toFirstUpper»«clazz.name.toFirstUpper»Operation(«clazz.name.toFirstLower», this);
					} 
				«ENDFOR»
			}
		'''
	}

	private def Collection<EClass> ancestors(EClass clazz) {
		val ret = newHashSet()
		if (!clazz.ESuperTypes.empty) {
			clazz.ESuperTypes.forEach [ st |
				ret.add(st)
				ret.addAll(st.ancestors)
			]
		}

		ret
	}

	def allClasses(EPackage ePackage) {
		if(ePackage != null) ePackage.eAllContents.filter[e|e instanceof EClass].map[e|e as EClass].toList.sortBy[e|e.name] else newArrayList()
	}
	
	def allClassesRec(EPackage e) {
		val graph = buildGraph(e, null)
		graph.nodes.map[elem].toList.sortBy[name]
	}

	def String genericType(EClass clazz, boolean extend) '''«clazz.EPackage.name.replaceAll("\\.","").toFirstUpper»__«clazz.name»T «IF clazz.ESuperTypes.size == 1 && extend» extends «clazz.ESuperTypes.head.genericType(false)»«ENDIF»'''

	def String generateOperation(EClass clazz, AleClass openClass, EPackage ePackage, List<EPackage> dependencies, List<AleClass> allAleClasses) {

		val packageName = clazz.EPackage.name
		val aleName = if (openClass != null) (openClass.eContainer as Root).name else "$default"

		val clazzName =  '''«packageName.toFirstUpper»«aleName.toFirstUpper»«clazz.name»Operation'''
		 '''
		package «packageName».«aleName».algebra.operation;
		
		public interface «clazzName» «FOR ext : clazz.ESuperTypes BEFORE 'extends ' SEPARATOR ', '»«ext.operationInterfacePath(ext.findAleClass(allAleClasses))»«ENDFOR» {
			«IF openClass != null»
				«FOR field:openClass.fields»
				«field.type.solveStaticType(ePackage, dependencies)» get«field.name.toFirstUpper»();
				void set«field.name.toFirstUpper»(«field.type.solveStaticType(ePackage, dependencies)» «field.name»);
				«ENDFOR»
				«FOR method: openClass.methods»
					«method.type.solveStaticType(ePackage, dependencies)» «method.name»(«FOR p: method.params»«p.type.solveStaticType(ePackage, dependencies)» «p.name»«ENDFOR»);
				«ENDFOR»
			«ENDIF»
		}'''
	}

	private def String solveStaticType(Type type, EPackage ePackage, List<EPackage> dependencies) {
		if(type == null) return 'void'
		if (type instanceof LiteralType) return type.lit
		if(type instanceof OrderedSetType) return '''org.eclipse.emf.common.util.EList<«type.subType.solveStaticType(ePackage, dependencies)»>'''
		if(type instanceof SequenceType) return '''org.eclipse.emf.common.util.EList<«type.subType.solveStaticType(ePackage, dependencies)»>'''
		if(type instanceof OutOfScopeType) {
			val  allClasses = buildGraph(ePackage, dependencies).nodes.map[elem];
			val foundClazz = allClasses.filter[c | c.name == type.externalClass].head
			return foundClazz?.javaFullPath.toString // TODO: resolve the type by scanning classes of the syntax
		}
	}

	def static String toJavaType(ETypedElement opp) {
		if (opp.EGenericType != null) {
			val type = opp.
				EType
			return '''«type.instanceClassName»«FOR t : opp.EGenericType.ETypeArguments BEFORE '<' SEPARATOR ', ' AFTER '>'»«t.EClassifier.instanceClassName»«ENDFOR»'''
		} else {
			return '''«opp.EType.instanceClassName»'''
		}
	}

	def static String toJavaType(AleClass clazz) {
		val behavior = clazz.eContainer as Root
		'''«behavior.name».algebra.operation.«behavior.name.toFirstUpper»«clazz.name.toFirstUpper»Operation'''
	}

	def String generateAlgebraInterface(EPackage ePackage, List<EPackage> otherPackages) {

//		val allEClasses = ePackage.allClasses
		val graph = buildGraph(ePackage, otherPackages)
		val allMethods = graph.nodes.sortBy[e|e.elem.name].filter[e|e.elem.EPackage.equals(ePackage)].filter [ e |
			!e.elem.abstract
		]
		val allDirectPackages = allMethods.allDirectPackages(ePackage)
		if(otherPackages != null) {
			for(op: otherPackages) {
				if(!allDirectPackages.contains(op)) allDirectPackages.add(op)
			}
//			allDirectPackages.addAll(otherPackages)
		}

		'''
			package «ePackage.name».algebra;
			
			public interface «ePackage.toPackageName»«FOR clazz : graph.nodes.sortBy[x|x.elem.name] BEFORE '<' SEPARATOR ',' AFTER '>'»«clazz.elem.genericType(true)»«ENDFOR»
				«FOR ePp : allDirectPackages.sortBy[name] BEFORE ' extends ' SEPARATOR ', '»«ePp.name».algebra.«ePp.toPackageName»«FOR x : ePp.allClassesRec BEFORE '<' SEPARATOR ', ' AFTER '>'»«x.genericType(false)»«ENDFOR»«ENDFOR» {
				«FOR clazzNode : allMethods»
				«clazzNode.elem.genericType(false)» «clazzNode.elem.name.toFirstLower»(final «clazzNode.elem.javaFullPath» «clazzNode.elem.name.toFirstLower»);
				«FOR parent: clazzNode.elem.ancestors»
					«parent.genericType(false)» «parent.name.toFirstLower»_«clazzNode.elem.name.toFirstLower»(final «clazzNode.elem.javaFullPath» «clazzNode.elem.name.toFirstLower»);
				«ENDFOR»
				
				«ENDFOR»
				
				«FOR clazz : graph.nodes»
				default «clazz.elem.genericType(false)» $(final «clazz.elem.javaFullPath» «clazz.elem.name.toFirstLower») {
					«FOR subClazz:clazz.incomings.filter[sc|!sc.elem.abstract]»
					«IF clazz.elem.ESuperTypes.size == 1»
						if(«clazz.elem.name.toFirstLower» instanceof «subClazz.elem.javaFullPath») return «subClazz.elem.name.toFirstLower»((«subClazz.elem.javaFullPath») «clazz.elem.name.toFirstLower»);
					«ELSE»
						if(«clazz.elem.name.toFirstLower» instanceof «subClazz.elem.javaFullPath») return «clazz.elem.name.toFirstLower»_«subClazz.elem.name.toFirstLower»((«subClazz.elem.javaFullPath») «clazz.elem.name.toFirstLower»);
					«ENDIF»
					«ENDFOR»
					«IF clazz.elem.abstract»
						return null;
					«ELSE»
						return «clazz.elem.name.toFirstLower»(«clazz.elem.name.toFirstLower»);
					«ENDIF»
				}
				«ENDFOR»
			}
		'''
	}

	private def buildConcretTypes(Map<String, List<GraphNode<EClass>>> allTypes) {
		allTypes.mapValues[x|x.filter[y|!y.elem.abstract]].filter[p1, p2|!p2.empty]
	}

	private def List<EPackage> allDirectPackages(Iterable<GraphNode<EClass>> nodes, EPackage ePackage) {
		val allDirectPackagesByInheritance = nodes.getDirectPackageByInheritance(ePackage)

		val allDirectPackageByReference = nodes.getAllDirectPackagesByReference(ePackage)
		
		allDirectPackagesByInheritance.addAll(allDirectPackageByReference)
		allDirectPackagesByInheritance.sortBy[name]
	}

	private def Set<EPackage> getAllDirectPackagesByReference(Iterable<GraphNode<EClass>> nodes, EPackage ePackage) {
		nodes.map[e|e.elem.EReferences].map[e|e.directlyRelatedTypes].flatten.map[e|e.EPackage].filter [ e |
			!e.equals(ePackage)
		].toSet
	}

	private def Set<EPackage> getDirectPackageByInheritance(Iterable<GraphNode<EClass>> nodes, EPackage ePackage) {
		nodes.map[e|e.outgoing].flatten.map[e|e.elem.EPackage].filter [ e |
			!e.equals(ePackage)
		].toSet
	}

	private def String toTryCatch(Iterable<EPackage> packages, String typeVarName) {
		'''
			«IF packages.size == 1»
				ret = «packages.head.name».algebra.«packages.head.toPackageName».super.$(«typeVarName»);
			«ELSE»
				try {
					ret = «packages.head.toPackageName».super.$(«typeVarName»);
				} catch(RuntimeException e) {
					«toTryCatch(packages.tail, typeVarName)»
				}
			«ENDIF»
		'''
	}

	public def static EClass getFindRootType(Iterable<GraphNode<EClass>> nodes) {
		val roots = nodes.map[roots].flatten.toSet
		if (roots.size >
			1) {
			throw new RuntimeException('''A classes cluster can't have more than one roots. We find a cluster composed of those roots: «FOR node : roots SEPARATOR ', '»«node.elem.EPackage.name».«node.elem.name»«ENDFOR»''')
		} else {
			roots.head.elem
		}
	}

	private def Iterable<GraphNode<EClass>> getListTypesRec(HashSet<EPackage> visited, EPackage ePackage,
		Graph<EClass> graph, Map<String, List<GraphNode<EClass>>> allTypes) {
		if (!visited.contains(ePackage)) {
			visited.add(ePackage)
			val List<GraphNode<EClass>> relatedToCurrentPackage = graph.nodes.sortBy[e|e.elem.name].filter [ e |
				e.elem.EPackage.equals(ePackage) || e.children.exists[f|f.elem.EPackage.equals(ePackage)] ||
					e.elem.EReferences.directlyRelatedTypes.exists[v|v.EPackage.equals(ePackage)]
			].toList

			val List<EPackage> letgo = relatedToCurrentPackage.allDirectPackages(ePackage)
			letgo.forEach [ n |
				relatedToCurrentPackage.addAll(getListTypesRec(visited, n, graph, allTypes))
			]

			relatedToCurrentPackage

		} else {
			newArrayList()
		}
	}

	private def void visitPackages(HashSet<EPackage> visitedpackage, EPackage ePackage, Graph<EClass> graph1) {
		if(ePackage != null) visitedpackage.add(ePackage)
		val allEClasses = if(ePackage !=null) ePackage.eAllContents.filter[e|e instanceof EClass].map[e|e as EClass].toList.sortBy [ e |
			e.name
		] else newArrayList()
		allEClasses.forEach[e|addParents(graph1, e)]
		allEClasses.forEach[e|e.EReferences.directlyRelatedTypes.forEach[f|addParents(graph1, f)]]

		val notYetVisited = graph1.nodes.sortBy[e|e.elem.name].map[e|e.elem.EPackage].toSet.filter [ e |
			!visitedpackage.contains(e)
		]
		notYetVisited.forEach [ e |
			visitPackages(visitedpackage, e, graph1)
		]
	}

	private def List<EClass> getDirectlyRelatedTypes(EList<EReference> list) {
		list.map[f|f.EType].filter[z|z instanceof EClass].map[q|q as EClass].filter [ x |
			!x.EPackage.name.equals("ecore")
		].toList
	}

	private def void addParents(Graph<EClass> graph1, EClass e) {
		// println('''# Add class «e.name»''')
		val node = graph1.addNode(e)
		e.ESuperTypes.forEach [ f |
			val node2 = graph1.addNode(f)
			if (!e.root) {
				graph1.addEdge(node, node2)
			}
			addParents(graph1, f)
		]
	}

	/**
	 * A root element is an element with no super type or explicitly defined with @OARoot.
	 */
	private def static boolean isRoot(EClass eClass) {
		eClass.ESuperTypes.empty // || eClass.hasOARootAnnotation
	}

	private def static EClass findRootParent(EClass eClass) {
		if(eClass.isRoot) eClass else findRootParent(eClass.ESuperTypes.head)
	}

	private def static String toClassName(String name) {
		name.split("\\.").map[e|e.toFirstUpper].join
	}

	private def static toPackageName(EPackage ePackage) '''«ePackage.name.toClassName»Algebra'''

	private def static javaFullPath(EClass eClass) {
		'''«eClass.EPackage.name».«eClass.name»'''
	}

//		private def static operationFullPath(EClass eClass,
//			EPackage rootPackage) '''«rootPackage.name».algebra.operation.«rootPackage.name.toFirstUpper»«eClass.name»Operation'''
}
