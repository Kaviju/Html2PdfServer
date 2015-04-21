package html2pdfserver.sampleapp.components;

import html2pdfserver.sampleapp.Html2PDFService;
import html2pdfserver.sampleapp.Html2PDFService.Request;

import com.webobjects.appserver.WOContext;
import com.webobjects.appserver.WOActionResults;

@SuppressWarnings("serial")
public class Main extends BaseComponent {
	public Main(WOContext context) {
		super(context);
	}

	public WOActionResults downloadMultipleOrientation() {
		Request pdfRequest = createMultipleOrientationRequest();
		return pdfRequest.createDownloadResponse("MultiplePaperOrientation.pdf");
	}
	public WOActionResults viewMultipleOrientation() {
		Request pdfRequest = createMultipleOrientationRequest();
		return pdfRequest.createInlineViewResponse("MultiplePaperOrientation.pdf");
	}

	private Request createMultipleOrientationRequest() {
		Request pdfRequest = Html2PDFService.createRequest();
		pdfRequest.addComponent(pageWithName(FontSamplePage.class));
		pdfRequest.addComponent(pageWithName(SampleLandscapePage.class));
		pdfRequest.fetchPdfFromServer();
		return pdfRequest;
	}

}
