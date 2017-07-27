/*
 * generated by Xtext 2.11.0
 */
package com.itemis.jbc.ide

import com.google.inject.Guice
import com.itemis.jbc.JBCRuntimeModule
import com.itemis.jbc.JBCStandaloneSetup
import org.eclipse.xtext.util.Modules2

/**
 * Initialization support for running Xtext languages as language servers.
 */
class JBCIdeSetup extends JBCStandaloneSetup {

	override createInjector() {
		Guice.createInjector(Modules2.mixin(new JBCRuntimeModule, new JBCIdeModule))
	}
	
}