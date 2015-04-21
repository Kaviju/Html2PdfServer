package html2pdfserver.sampleapp.components;

import com.webobjects.appserver.WOContext;
import com.webobjects.appserver.WOResponse;

import er.extensions.components.ERXStatelessComponent;

@SuppressWarnings("serial")
public class SvgImage extends ERXStatelessComponent {
    private String svgSrc;

	public SvgImage(WOContext context) {
        super(context);
    }
	
	@Override
	public void appendToResponse(WOResponse response, WOContext context) {
		String framework = stringValueForBinding("framework", frameworkName());
		String filename = stringValueForBinding("filename");
		svgSrc = context._urlForResourceNamed(filename, framework, true);
		super.appendToResponse(response, context);
	}

	public String svgSrc() {
		return svgSrc;
	}
}