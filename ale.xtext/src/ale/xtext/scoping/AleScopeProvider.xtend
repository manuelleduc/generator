/*
 * generated by Xtext 2.10.0
 */
package ale.xtext.scoping

import ale.xtext.ale.AlePackage
import ale.xtext.ale.AleClass
import ale.xtext.ale.OpenClass
import ale.xtext.ale.Root
import com.google.common.base.Function
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.Scopes
import ale.xtext.ale.NewClass

/**
 * This class contains custom scoping description.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#scoping
 * on how and when to use it.
 */
class AleScopeProvider extends AbstractAleScopeProvider {

	override IScope getScope(EObject context, EReference reference) {
		if (context instanceof OpenClass) {
			if (reference == AlePackage::eINSTANCE.aleClass_SuperClass) {
				val tmp = super.getScope(context, reference)
				val currentRoot = context.eContainer as Root
				val imports = currentRoot.imports.map[i|i.ref.classes].flatten.filter[c|c instanceof OpenClass]
				return Scopes::scopeFor(imports, new Function<AleClass, QualifiedName>() {

					override apply(AleClass t) {
						val n = currentRoot.imports.filter[i|i.ref.classes.contains(t)].head.name
						QualifiedName.create(n, t.name)
					}

				}, tmp)
			}
		}

		if (context instanceof NewClass) {
			if (reference == AlePackage::eINSTANCE.aleClass_SuperClass) {
				val tmp = super.getScope(context, reference)
				val currentRoot = context.eContainer as Root
				val imports = currentRoot.imports.map[i|i.ref.classes].flatten.filter[c|c instanceof OpenClass]
				return Scopes::scopeFor(imports, new Function<AleClass, QualifiedName>() {

					override apply(AleClass t) {
						val n = currentRoot.imports.filter[i|i.ref.classes.contains(t)].head.name
						QualifiedName.create(n, t.name)
					}

				}, tmp)
			}
		}
		
//		if (context instanceof VarRef) {
//			println(context)
//			return super.getScope(context, reference)
//		}

		return super.getScope(context, reference)
	}
}
