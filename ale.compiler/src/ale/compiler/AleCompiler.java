package ale.compiler;

import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.eclipse.core.resources.IProject;
import org.eclipse.core.runtime.IPath;
import org.eclipse.emf.codegen.ecore.generator.Generator;
import org.eclipse.emf.codegen.ecore.generator.GeneratorAdapterFactory;
import org.eclipse.emf.codegen.ecore.genmodel.GenJDKLevel;
import org.eclipse.emf.codegen.ecore.genmodel.GenModel;
import org.eclipse.emf.codegen.ecore.genmodel.GenModelFactory;
import org.eclipse.emf.codegen.ecore.genmodel.generator.GenBaseGeneratorAdapter;
import org.eclipse.emf.common.util.EList;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EAttribute;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EClassifier;
import org.eclipse.emf.ecore.EDataType;
import org.eclipse.emf.ecore.EGenericType;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.ETypedElement;
import org.eclipse.emf.ecore.EcoreFactory;
import org.eclipse.emf.ecore.EcorePackage;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;

import com.google.inject.Injector;

import ale.xtext.AleStandaloneSetup;
import ale.xtext.ale.AleClass;
import ale.xtext.ale.Field;
import ale.xtext.ale.LiteralType;
import ale.xtext.ale.OpenClass;
import ale.xtext.ale.OrderedSetType;
import ale.xtext.ale.OutOfScopeType;
import ale.xtext.ale.Root;
import ale.xtext.ale.SequenceType;
import ale.xtext.ale.Type;
import dsl.xtext.DslStandaloneSetup;
import dsl.xtext.dsl.Behavior;
import dsl.xtext.dsl.DSL;
import dsl.xtext.dsl.Syntax;
import fr.inria.diverse.objectalgebragenerator.GenerateAlgebra;
import fr.inria.diverse.objectalgebragenerator.Graph;
import fr.inria.diverse.objectalgebragenerator.Graph.GraphNode;

/**
 * 
 * This compiler compiles a given semantic, which conform itself to a bunch of
 * syntaxes, to a bunch of (conforming) target syntaxes.
 * 
 * @author mleduc
 *
 */
public class AleCompiler {

	private final java.net.URI dslURI;
	private List<EPackage> syntaxes;
	private List<EPackage> models;
	private final String filenamedsl;

	public AleCompiler(final java.net.URI uri, final String filenamedsl) {
		this.dslURI = uri;
		this.filenamedsl = filenamedsl;
	}

	private GenModel saveGenModel(final ResourceSetImpl resSet, final String languageName, final EPackage rootPackage,
			final String projectName) {
		/*
		 * Final step: Generating the emf code from the ecore generated
		 */

		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("genmodel", new XMIResourceFactoryImpl());

		final GenModel genModel = GenModelFactory.eINSTANCE.createGenModel();
		genModel.setComplianceLevel(GenJDKLevel.JDK80_LITERAL);
		genModel.getForeignModel().add("http://" + languageName);
		genModel.setModelName("MODELNAMETEST");
		genModel.setModelPluginID("ModelPluginIDTest");
		genModel.getForeignModel().add(rootPackage.getNsURI());
		genModel.initialize(Collections.singleton(rootPackage));
		genModel.setModelDirectory("/" + projectName + "/src");

		// TODO: Update genmodel in order to avoid the regeneration of
		// cross-references

		final URI createURI = URI
				.createPlatformResourceURI("/" + projectName + "/src-gen/" + languageName + ".genmodel", true);
		final Resource res = resSet.createResource(createURI);

		res.getContents().add(genModel);

		try {
			res.save(null);

		} catch (final IOException e) {
			e.printStackTrace();
		}

		return genModel;
	}

	private void proceedToGeneration(final GenModel genModel) {
		genModel.reconcile();
		genModel.setCanGenerate(true);
		genModel.setValidateModel(true);
		genModel.setUpdateClasspath(true);

		final org.eclipse.emf.codegen.ecore.generator.GeneratorAdapterFactory.Descriptor.Registry reg = GeneratorAdapterFactory.Descriptor.Registry.INSTANCE;
		final Generator generator = new Generator(reg);
		generator.setInput(genModel);

		generator.generate(genModel, GenBaseGeneratorAdapter.MODEL_PROJECT_TYPE, new NullMonitorImplementation(this));

	}

	private EPackage load(final Syntax stx, final ResourceSet rs) {
		if (!EPackage.Registry.INSTANCE.containsKey(EcorePackage.eNS_URI))
			EPackage.Registry.INSTANCE.put(EcorePackage.eNS_URI, EcorePackage.eINSTANCE);

		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("ecore", new XMIResourceFactoryImpl());

		return rs.getPackageRegistry().getEPackage(stx.getValue().replaceAll("\"", ""));
	}

	public void compile(final IProject project) throws IOException {

		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("dsl", new XMIResourceFactoryImpl());
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("ale", new XMIResourceFactoryImpl());
		final ResourceSetImpl resSet = new ResourceSetImpl();

		final com.google.inject.Injector injector = new DslStandaloneSetup().createInjectorAndDoEMFRegistration();

		final XtextResourceSet resourceSet = injector.getInstance(XtextResourceSet.class);
		resourceSet.addLoadOption(XtextResource.OPTION_RESOLVE_ALL, Boolean.TRUE);

		final Resource resource = resourceSet.getResource(URI.createURI(this.dslURI.toString()), true);
		final DSL model = (DSL) resource.getContents().get(0);

		final EList<Behavior> behaviors = model.getBehaviours();
		initModels(resSet, model);

		final EPackage rootPackage = initRootPackage();

		final List<EPackage> tmp = model.getSyntaxes().stream().map((final Syntax stx) -> load(stx, resSet))
				.collect(Collectors.toList());

		this.syntaxes = new ArrayList<>(new GenerateAlgebra().getListAllClasses(rootPackage, tmp).stream()
				.map(e -> e.getEPackage()).collect(Collectors.toSet()));

		final List<Root> roots = behaviors.stream().map(b -> convertBehviorToRoot(resourceSet, b))
				.collect(Collectors.toList());

		final List<AleClass> allAleClasses = roots.stream().flatMap(r -> r.getClasses().stream())
				.collect(Collectors.toList());

		generateRequiredAlgebraInterfaces(project, resSet, resourceSet, behaviors, rootPackage, roots, this.syntaxes);

		this.generateAlgebraInterface(rootPackage, this.syntaxes, project);
		for (EPackage ePackage : this.syntaxes) {
			this.generateAlgebraInterface(ePackage, new ArrayList<>(), project);
		}

		final List<EClass> listAllClasses = new GenerateAlgebra().getListAllClasses(rootPackage, this.syntaxes);
		listAllClasses.forEach(clazz -> {
			final ale.xtext.ale.AleClass openClass = lookupClass(resourceSet, behaviors, clazz.getName());
			new GenerateOperationInterface().generate(clazz, project, openClass, rootPackage, this.syntaxes,
					allAleClasses);
		});

		this.generateConcreteAlgebra(rootPackage, this.syntaxes, project, allAleClasses);

		this.generateConcreteOperations(rootPackage, this.syntaxes, behaviors, project, resourceSet, allAleClasses);

	}

	private void initModels(final ResourceSetImpl resSet, final DSL model) {
		this.models = model.getSyntaxes().stream().map(syntax -> {
			if (!EPackage.Registry.INSTANCE.containsKey(EcorePackage.eNS_URI))
				EPackage.Registry.INSTANCE.put(EcorePackage.eNS_URI, EcorePackage.eINSTANCE);
			Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("ecore", new XMIResourceFactoryImpl());
			return resSet.getPackageRegistry().getEPackage(syntax.getValue());
		}).filter(x -> x != null).collect(Collectors.toList());
	}

	private EPackage initRootPackage() {
		final String fileNameDsl = this.filenamedsl.substring(0, this.filenamedsl.length() - 4);
		final EPackage rootPackage = EcoreFactory.eINSTANCE.createEPackage();
		rootPackage.setName(fileNameDsl.replaceAll("\\.", ""));
		rootPackage.setNsPrefix(fileNameDsl);
		rootPackage.setNsURI("http://" + fileNameDsl);
		return rootPackage;
	}

	private void generateRequiredAlgebraInterfaces(final IProject project, final ResourceSetImpl resSet,
			final XtextResourceSet resourceSet, final EList<Behavior> behaviors, final EPackage rootPackage,
			final List<Root> roots, final List<EPackage> dependencies) throws IOException {
		for (final Root root : roots) {
			final String projectName = "test";
			this.generateDynamicModel(projectName, resSet, root, rootPackage, resourceSet, behaviors, dependencies);
			final GenModel genModel = this.saveGenModel(resSet, root.getName(), rootPackage, projectName);
			this.proceedToGeneration(genModel);

			for (final EPackage ePackage : dependencies) {
				final GenModel genModel2 = this.saveGenModel(resSet, ePackage.getName(), ePackage, projectName);
				this.proceedToGeneration(genModel2);
			}

			this.syntaxes.forEach(ePackage -> {
				this.generateAlgebraInterface(ePackage, null, project);
			});
		}
	}

	private ale.xtext.ale.AleClass lookupClass(final XtextResourceSet resourceSet, final EList<Behavior> behaviors,
			final String className) {
		final ale.xtext.ale.AleClass clazz = behaviors.stream().map(b -> convertBehviorToRoot(resourceSet, b))
				.flatMap(b -> b.getClasses().stream()).filter(b -> {
					final String name2 = b.getName();
					return name2.equals(className) || className.endsWith("_Aspect")
							&& name2.equals(className.substring(0, className.length() - "_Aspect".length()));
				}).findFirst().orElse(null);
		return clazz;
	}

	private Root convertBehviorToRoot(final XtextResourceSet resourceSet, final Behavior behavior) {
		final Injector injector2 = new AleStandaloneSetup().createInjectorAndDoEMFRegistration();
		final XtextResourceSet resourceSet2 = injector2.getInstance(XtextResourceSet.class);
		resourceSet2.addLoadOption(XtextResource.OPTION_RESOLVE_ALL, Boolean.TRUE);

		final URI createURI = URI.createURI(behavior.getValue());
		final Resource resource2 = resourceSet.getResource(createURI, true);
		return (Root) resource2.getContents().get(0);
	}

	private void generateConcreteOperations(final EPackage rootPackage, final List<EPackage> dependencies,
			final EList<Behavior> behaviors, final IProject project, final XtextResourceSet resourceSet,
			final List<AleClass> allAleClasses) {
		final Graph<EClass> res = new GenerateAlgebra().buildGraph(rootPackage, dependencies);
		res.nodes.forEach(entry -> {
			final ale.xtext.ale.AleClass openClass = lookupClass(resourceSet, behaviors, entry.elem.getName());
			generateConceteOperation(entry, project, rootPackage, openClass, dependencies, allAleClasses);
		});

	}

	private void generateConceteOperation(final GraphNode<EClass> entry, final IProject project,
			final EPackage ePackage, final ale.xtext.ale.AleClass openClass, final List<EPackage> deppendencies,
			final List<AleClass> allAleClasses) {
		final boolean overloaded = openClass != null && openClass.getFields().size() > 0
				&& !((EPackage) entry.elem.eContainer()).getName().equals(((Root) openClass.eContainer()).getName());
		final String fileContent = new GenerateAlgebra().processConcreteOperation(entry, ePackage, deppendencies,
				openClass, overloaded, allAleClasses);

		final String packageName = entry.elem.getEPackage().getName();
		final String aleName;
		if (openClass != null) {
			aleName = ((Root) openClass.eContainer()).getName();
		} else {
			aleName = "$default";
		}

		final IPath directoryAlgebra = project.getLocation().append("src").append(packageName).append(aleName)
				.append("algebra").append("impl").append("operation");
		directoryAlgebra.toFile().mkdirs();

		final IPath fileJavaAlgebra = directoryAlgebra
				.append(toFirstUpper(packageName) + toFirstUpper(aleName) + entry.elem.getName() + "Operation")
				.addFileExtension("java");

		try {
			final FileWriter fileWriter = new FileWriter(fileJavaAlgebra.toFile());
			fileWriter.write(fileContent);
			fileWriter.close();
		} catch (final IOException e) {
			e.printStackTrace();
		}
	}

	private void generateConcreteAlgebra(final EPackage ePackage, final List<EPackage> dependencies,
			final IProject project, final List<AleClass> allAleClasses) {
		final String fileContent = new GenerateAlgebra().processConcreteAlgebra(ePackage, dependencies, allAleClasses);
		final IPath directoryAlgebra = project.getLocation().append("src").append(ePackage.getName()).append("algebra")
				.append("impl");
		directoryAlgebra.toFile().mkdirs();
		final IPath fileJavaAlgebra = directoryAlgebra.append(
				ePackage.getName().substring(0, 1).toUpperCase() + ePackage.getName().substring(1) + "AlgebraImpl")
				.addFileExtension("java");

		try {
			final FileWriter fileWriter = new FileWriter(fileJavaAlgebra.toFile());
			fileWriter.write(fileContent);
			fileWriter.close();
		} catch (final IOException e) {
			e.printStackTrace();
		}

	}

	/**
	 * Generates a ecore file from the dynamic data declared in the implemented
	 * behavior
	 * 
	 * @param projectName
	 * @param resSet
	 * @param resourceSet
	 * @param behaviors
	 * @param rootPackage
	 * @param rootPackage
	 * @param dependencies
	 * @return
	 * 
	 * @throws IOException
	 */
	private void generateDynamicModel(final String projectName, final ResourceSet resSet, final Root modelBehavior,
			final EPackage rootPackage, final XtextResourceSet resourceSet, final EList<Behavior> behaviors,
			final List<EPackage> dependencies) throws IOException {
		final String behaviourName = modelBehavior.getName();
		final Map<ale.xtext.ale.AleClass, List<Field>> clazzList = new HashMap<>();

		final List<ale.xtext.ale.AleClass> classExtensions = modelBehavior.getClasses();
		classExtensions.forEach(extendedClass -> {
			if (!extendedClass.getFields().isEmpty()) {
				final List<Field> attributes = extendedClass.getFields();
				clazzList.put(extendedClass, attributes);
			}
		});

		final Map<ale.xtext.ale.AleClass, EClass> mapClassEClass = new HashMap<>();

		// in a first step we reference all classes
		clazzList.entrySet().stream().forEach(entry -> {
			final ale.xtext.ale.AleClass fromClazz = entry.getKey();
			final EClass clazz = EcoreFactory.eINSTANCE.createEClass();
			if (fromClazz instanceof OpenClass) {
				clazz.setName(fromClazz.getName() + "_Aspect");
			} else {
				clazz.setName(fromClazz.getName());
			}
			final EClass superClazz = this.getClassFromName(fromClazz.getName());

			if (superClazz != null) {
				clazz.getESuperTypes().add(superClazz);
			}

			mapClassEClass.put(fromClazz, clazz);
			rootPackage.getEClassifiers().add(clazz);
		});

		// then we complet them with the fields
		clazzList.entrySet().stream().forEach(entry -> {
			final EClass clazz = mapClassEClass.get(entry.getKey());
			entry.getValue().stream().forEach(variableDecl -> {
				final ETypedElement typedElem = resolveType(variableDecl.getType(), resourceSet, behaviors, rootPackage,
						dependencies);

				final EClassifier resolveType = typedElem.getEType();
				if (resolveType instanceof EDataType) {
					final EAttribute createEAttribute = EcoreFactory.eINSTANCE.createEAttribute();
					createEAttribute.setName(variableDecl.getName());
					if (variableDecl.getType() instanceof SequenceType) {
						// createEAttribute.setTransient(true);
						// createEAttribute.setUpperBound(-1);
						createEAttribute.setEGenericType(typedElem.getEGenericType());
					} else {
						createEAttribute.setEType(resolveType);
					}
					// if (typedElem.getEGenericType() != null) {
					// createEAttribute.setEGenericType(typedElem.getEGenericType());
					// }
					clazz.getEAttributes().add(createEAttribute);
				} else {
					final EReference ref = EcoreFactory.eINSTANCE.createEReference();
					ref.setName(variableDecl.getName());
					ref.setEType(resolveType);
					// if (typedElem.getEGenericType() != null) {
					// ref.setEGenericType(typedElem.getEGenericType());
					// }
					// ref.setEGenericType(variableDecl.getType().getEGenericType());
					// // attr.setE
					//
					// // TODO : solve why currentState has an error in
					// modeling
					// // workbench
					//
					clazz.getEReferences().add(ref);

				}

			});

		});

		final URI createUri = URI.createPlatformResourceURI("/" + projectName + "/src-gen/" + behaviourName + ".ecore",
				true);

		final Resource resource = resSet.createResource(createUri);

		resource.getContents().add(rootPackage);

		resource.save(null);

	}

	private ETypedElement resolveType(final Type type, final XtextResourceSet resourceSet,
			final EList<Behavior> behaviors, final EPackage ePackage, final List<EPackage> depepdencies) {
		if (type == null)
			return null;
		if (type instanceof LiteralType) {
			final LiteralType lt = (LiteralType) type;
			EClassifier primitiveType;
			switch (lt.getLit().toLowerCase()) {
			case "string":
				primitiveType = EcorePackage.eINSTANCE.getEString();
				break;
			case "boolean":
				primitiveType = EcorePackage.eINSTANCE.getEBoolean();
				break;
			// case "byte":
			// primitiveType = EcorePackage.eINSTANCE.getEByte();
			// break;
			// case "char":
			// primitiveType = EcorePackage.eINSTANCE.getEChar();
			// break;
			// case "short":
			// primitiveType = EcorePackage.eINSTANCE.getEShort();
			// break;
			case "int":
				primitiveType = EcorePackage.eINSTANCE.getEInt();
				break;
			// case "long":
			// primitiveType = EcorePackage.eINSTANCE.getELong();
			// break;
			case "real":
				primitiveType = EcorePackage.eINSTANCE.getEFloat();
				break;
			// case "double":
			// primitiveType = EcorePackage.eINSTANCE.getEDouble();
			// break;
			case "void":
				primitiveType = null;
				break;
			default:
				primitiveType = null;
				break;
			}
			final EAttribute ret = EcoreFactory.eINSTANCE.createEAttribute();
			ret.setEType(primitiveType);
			return ret;
		}

		if (type instanceof OrderedSetType)
			return null;
		if (type instanceof SequenceType) {
			final EAttribute ret = EcoreFactory.eINSTANCE.createEAttribute();
			ret.setName("tmp");
			// EDataType eeList = EcorePackage.eINSTANCE.getEEList();
			// ret.setEType(eeList);

			final SequenceType seqType = (SequenceType) type;

			final List<EGenericType> collect = new ArrayList<>();
			final EGenericType etypeArgument = EcoreFactory.eINSTANCE.createEGenericType();
			final EClassifier eType = this
					.resolveType(seqType.getSubType(), resourceSet, behaviors, ePackage, depepdencies).getEType();
			etypeArgument.setEClassifier(eType);
			collect.add(etypeArgument);
			final EDataType eeList = EcorePackage.eINSTANCE.getEEList();
			ret.setEType(eeList);
			ret.getEGenericType().setEClassifier(eeList);
			ret.getEGenericType().getETypeArguments().addAll(collect);
			// ret.setTransient(true);
			// ret.setUpperBound(-1);
			return ret;
		}
		if (type instanceof OutOfScopeType) {
			final String externalClass = ((OutOfScopeType) type).getExternalClass();
			// final ale.xtext.ale.Class res = lookupClass(resourceSet,
			// behaviors, externalClass);
			// if (res != null) {
			// final EAttribute ret = EcoreFactory.eINSTANCE.createEAttribute();
			// ret.setEType(res.eClass());
			// return ret;
			//
			// } else {
			final GenerateAlgebra generateAlgebra = new GenerateAlgebra();
			final List<EClass> allClasses = generateAlgebra.getListAllClasses(ePackage, depepdencies);
			final EClass tmp = allClasses.stream().filter(c -> c.getName().equals(externalClass)).findFirst()
					.orElseGet(() -> this.syntaxes.stream().flatMap(s -> generateAlgebra.allClasses(s).stream())
							.filter(c -> c.getName().equals(externalClass)).findFirst().orElse(null));
			final EAttribute ret = EcoreFactory.eINSTANCE.createEAttribute();
			ret.setEType(tmp);
			return ret;
			// }
		}
		/*
		 * 
		 * '''org.eclipse.emf.common.util.EList<«type.subType.solveStaticType»>'
		 * '' if(type instanceof SequenceType) return
		 * '''org.eclipse.emf.common.util.EList<«type.subType.solveStaticType»>'
		 * '' if(type instanceof OutOfScopeType) return type.externalClass //
		 * TODO: resolve the type by scanning classes of the syntax
		 */
		return null;
	}

	private EClass getClassFromName(final String name) {
		for (final EPackage packagz : this.models) {

			final EClassifier pack = packagz.getEClassifier(name);
			if (pack != null && pack instanceof EClass) {
				return (EClass) pack;
			}
		}
		return null;

	}

	private void generateAlgebraInterface(final EPackage ePackage, final List<EPackage> otherPackages,
			final IProject project) {
		final String fileContent = new GenerateAlgebra().generateAlgebraInterface(ePackage, otherPackages);
		final String name = ePackage.getName();
		final IPath directoryAlgebra = project.getLocation().append("src").append(name).append("algebra");
		directoryAlgebra.toFile().mkdirs();
		final IPath fileJavaAlgebra = directoryAlgebra.append(toFirstUpper(name) + "Algebra").addFileExtension("java");

		try {
			final FileWriter fileWriter = new FileWriter(fileJavaAlgebra.toFile());
			fileWriter.write(fileContent);
			fileWriter.close();
		} catch (final IOException e) {
			e.printStackTrace();
		}
	}

	private String toFirstUpper(final String string) {
		return string.substring(0, 1).toUpperCase() + string.substring(1);
	}

}
