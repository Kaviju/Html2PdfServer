package html2pdfserver.sampleapp.components;

import com.webobjects.appserver.WOActionResults;
import com.webobjects.appserver.WOComponent;
import com.webobjects.appserver.WOContext;

import er.extensions.components.ERXComponent;
import html2pdfserver.sampleapp.Application;
import html2pdfserver.sampleapp.Html2PDFService;
import html2pdfserver.sampleapp.Session;

@SuppressWarnings("serial")
public class BaseComponent extends ERXComponent {
	public BaseComponent(WOContext context) {
		super(context);
	}
	
	@Override
	public Application application() {
		return (Application)super.application();
	}
	
	@Override
	public Session session() {
		return (Session)super.session();
	}

	public boolean isPrinting() {
		return Html2PDFService.isPrinting();
	}

	public WOActionResults pdfVersionOfCurrentPage() {
		WOComponent currentPage = context().page();
		return Html2PDFService.createRequest().addComponent(currentPage).createInlineViewResponse(currentPage.name()+".pdf");
	}
}
