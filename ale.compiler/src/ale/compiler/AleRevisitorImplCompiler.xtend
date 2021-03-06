package ale.compiler

import ale.compiler.generator.AleGenerator
import ale.compiler.generator.TypeUtil
import ale.utils.EcoreUtils
import ale.xtext.AleRuntimeModule
import ale.xtext.ale.Root
import com.google.inject.Guice
import com.google.inject.Inject
import org.eclipse.core.resources.IFile
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import ale.xtext.ale.AleFactory

class AleRevisitorImplCompiler {
	IFile file

	@Inject XtextResourceSet rs
	extension EcoreUtils = new EcoreUtils()
	extension TypeUtil = new TypeUtil()

	new(IFile file) {
		this.file = file
	}

	def void compile() {
		val injector = Guice::createInjector(new AleRuntimeModule())
		injector.injectMembers(this)

		rs.addLoadOption(XtextResource::OPTION_RESOLVE_ALL, Boolean::TRUE)

		val resource = rs.getResource(
			URI::createPlatformResourceURI(file.fullPath.toString(), true), true)
		val root = resource.contents.head as Root
		
		// FIXME: jaja, ugly af
		val ecoreFile = root.importEcore.ref
		val pkg = rs.loadEPackage(ecoreFile)
		val gm = rs.loadCorrespondingGenmodel(ecoreFile)

		// Preprocess: for every concept in the language that doesn't have a
		// corresponding AleClass, generate it
		pkg.allClasses.forEach[cls |
			if (cls.getMatchingAleClass(root) === null) {
				root.classes += AleFactory.eINSTANCE.createAleClass => [
					name = cls.name
				]
			}
		]

		val generator = new AleGenerator(file.project)

		// generation of the concrete visitor from the syntactic scope defined
		// in the ale file
		generator.saveRevisitorImpl(root, pkg, gm)

		// generation of the abstract operations
		pkg
			.allClasses
			.map[c | c -> c.name.getAleClass(root)]
			.filter[value === null || value.eContainer == root]
			.forEach[pair |
				generator.saveOperationInterface(pair.key, pair.value, pkg, gm)
				generator.saveOperationImpl(pair.key, pair.value, pkg, gm)
			]
	}
}
