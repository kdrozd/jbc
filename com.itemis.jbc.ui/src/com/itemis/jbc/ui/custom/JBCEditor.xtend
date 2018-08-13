package com.itemis.jbc.ui.custom

import java.io.InputStreamReader
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Method
import java.lang.reflect.Proxy
import javax.inject.Inject
import org.eclipse.core.resources.IEncodedStorage
import org.eclipse.core.resources.IStorage
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.ui.IEditorInput
import org.eclipse.ui.IFileEditorInput
import org.eclipse.xtext.builder.MonitorBasedCancelIndicator
import org.eclipse.xtext.ui.editor.XtextEditor
import org.eclipse.xtext.util.StringInputStream
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.IResourceValidator
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.jface.dialogs.ErrorDialog
import org.eclipse.core.runtime.Status

class JBCEditor extends XtextEditor {

	@Inject IResourceValidator validator

	override protected doSetInput(IEditorInput input) throws CoreException {
		// The class LastSaveReferenceProvider uses the method IStorage.getContents to access the original content
		// to compare it to the actual content. But we use a binary file to create text from it. To make the comparison
		// work we wrap the "getStorage" method with a dynamic proxy. The proxy converts the binary representation to its
		// textual form to enable the comparison to work.
		if (input instanceof IFileEditorInput) {
			if (input.file.name.endsWith(".class")) {
				super.doSetInput(input.proxy)
				return
			}
		}
		super.doSetInput(input)
	}

	def private IFileEditorInput proxy(IFileEditorInput editorInput) {
		Proxy.newProxyInstance(this.class.classLoader, #[IFileEditorInput],
			new IFileEditorInputHandler(editorInput)) as IFileEditorInput
	}

	override doSave(IProgressMonitor progressMonitor) {
		if (editorInput instanceof IFileEditorInput) {
			if ((editorInput as IFileEditorInput).file.name.endsWith(".class")) {
				val validationResult = document.readOnly(resource | validator.validate(resource, CheckMode.ALL, new MonitorBasedCancelIndicator(progressMonitor)))
				for (issue : validationResult) {
					if (issue.severity == Severity.ERROR) {
						ErrorDialog.openError(shell, "Errors in code", "The byte code contains errors. As the result is not saved as text but directly in code the editor has to be error free if you like to save it.", new Status(Status.ERROR, "JBCEditor", issue.message))
						return;
					}
				}
			}
		}
		super.doSave(progressMonitor)
	}

}

package class IFileEditorInputHandler implements InvocationHandler {

	private final IFileEditorInput original

	new(IFileEditorInput original) {
		this.original = original
	}

	override invoke(Object proxy, Method method, Object[] args) throws Throwable {
		if (method.name.equals("getStorage")) {
			return (method.invoke(original, args) as IStorage).proxy
		} else {
			return method.invoke(original, args)
		}
	}

	def private IStorage proxy(IStorage storage) {
		Proxy.newProxyInstance(this.class.classLoader, #[IStorage], new IStorageHandler(storage)) as IStorage
	}

}

package class IStorageHandler implements InvocationHandler {

	private final IStorage original

	new(IStorage original) {
		this.original = original
	}

	override invoke(Object proxy, Method method, Object[] args) throws Throwable {
		if (method.name.equals("getContents") && method.parameterCount === 0) {
			val reader = new InputStreamReader(original.contents)
			try {
				val content = new JBCInputStreamContentReader().readContent(original.contents,
					(original as IEncodedStorage).charset)
				return new StringInputStream(content)
			} finally {
				reader.close()
			}
		} else {
			return method.invoke(original, args)
		}
	}

}
