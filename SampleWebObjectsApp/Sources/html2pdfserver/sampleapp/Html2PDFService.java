package html2pdfserver.sampleapp;


import java.io.*;
import java.net.*;
import java.util.*;

import org.apache.log4j.Logger;

import com.webobjects.appserver.*;
import com.webobjects.foundation.*;

import er.extensions.appserver.*;
import er.extensions.foundation.*;

public class Html2PDFService {
	public static final Logger log = Logger.getLogger(Html2PDFService.class);
	private static final String isPrintingStorageKey = "HTML2PDFService_isPrinting";

	static public Request createRequest() {
		return new Request();
	}
	
	static Html2PDFService instance;
	static public synchronized Html2PDFService getInstance() {
		if (instance == null) {
			instance = new Html2PDFService();
		}
		return instance;
	}
	
	static public boolean isPrinting() { 
		return ERXValueUtilities.booleanValue(ERXThreadStorage.valueForKey(isPrintingStorageKey));
	}

	static int documentNumber = 0;	
	
	// We make sure the component is not using the current context to keep it clean. We need the request to generate valid URLs.
	private String componentHtmlKeyWithComponent(WOComponent component) {
		ERXWOContext newContext = new ERXWOContext(component.context().request());
		component._setContext(newContext);
		ERXThreadStorage.takeValueForKey(true, isPrintingStorageKey);
		WOResponse html = component.generateResponse();
		ERXThreadStorage.removeValueForKey(isPrintingStorageKey);
		
		String key = "d"+documentNumber++;
		registerHtmlResponseWithKey(html, key);
		return key;
	}
		
	private Html2PDFService() {
	}
		
	private static byte[] readBytesFromUrl(String urlString, NSArray<String> commands) throws IOException {
		URL url = new URL(urlString);

		HttpURLConnection urlConn = (HttpURLConnection) url.openConnection();
		urlConn.setDoInput(true);
		urlConn.setConnectTimeout(1000);
		urlConn.setReadTimeout(ERXProperties.intForKeyWithDefault("html2pdfReadTimeout", 15000));
		
		addCommandsToRequest(commands, urlConn);
		urlConn.connect();
		
		InputStream urlStream = urlConn.getInputStream();
		int contentLength = urlConn.getContentLength();
		log.debug("Got data size: "+contentLength+".");
		
		byte[] readBytes = readBytesFromStream(urlStream);
		urlStream.close();
		urlConn.disconnect();
		return readBytes;
	}

	private static void addCommandsToRequest(NSArray<String> commands, HttpURLConnection urlConn) 
			throws UnsupportedEncodingException, ProtocolException, IOException {
		if (commands != null) {
			String postString = commands.componentsJoinedByString("\n");
			byte[] postData = postString.getBytes("UTF-8");
			urlConn.addRequestProperty("Content-Length", String.valueOf(postData.length));

			urlConn.setRequestMethod("POST");
			urlConn.setDoOutput(true);
			OutputStream postStream = urlConn.getOutputStream();
			postStream.write(postData);
			postStream.flush();
			postStream.close();
		}
	}

	private static byte[] readBytesFromStream(InputStream in) throws java.io.IOException {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		byte[] buffer = new byte[1024]; //you can configure the buffer size
		int nbRead;
		while ( (nbRead = in.read(buffer)) != -1) {
			out.write(buffer, 0, nbRead); //copy streams
		}
		return out.toByteArray();
	}
	
	public static class Request {
		private boolean pdfFetchedFromServer = false;;
		NSMutableArray<String>componentHtmlKeys = new NSMutableArray<String>();
		NSMutableArray<String>commands = new NSMutableArray<String>();
		private byte[] pdfData;

		public Request setCurrentPageNumber(int pageNumber) {
			commands.add("setCurrentPageNumber:"+pageNumber);
			return this;
		}

		public Request addBlankPage() {
			commands.add("insertBlankPage");
			return this;
		}

		public Request addRendererInfos() {
			commands.add("addRendererInfos");
			return this;
		}

		public Request addComponent(WOComponent component) {
			String htmlKey = getInstance().componentHtmlKeyWithComponent(component);
			componentHtmlKeys.add(htmlKey);
			
			String className = Html2Pdf.class.getName();
			if (className.lastIndexOf('.') > 0) {
				className = className.substring(className.lastIndexOf('.')+1);
			}
			addDirectAction(className+"/getHtml", new NSDictionary<String, Object>(htmlKey, "key"));
			return this;
		}

		public Request addDirectAction(String actionName, NSDictionary<String, Object> params) {
			WOContext context = ERXWOContext.currentContext();
			context = (WOContext) context.clone();
			context.generateCompleteURLs();
			String url = context.directActionURLForActionNamed(actionName, params, false, false);
			commands.add("renderPdfAtUrl:"+url);
			return this;
		}
		
		public Request fetchPdfFromServer() {
			if (pdfFetchedFromServer ) {
				return this;
			}
			long startTime = System.currentTimeMillis();
			log.info("Trying PDF serveurs for commands: \n"+commands.componentsJoinedByString("\n"));
			@SuppressWarnings("unchecked")
			NSArray<String> serverUrls = ERXProperties.arrayForKey("html2pdfServers");
			for (String serverUrl : serverUrls) {
				try {
					pdfData = readBytesFromUrl(serverUrl, commands);
					if (pdfData != null) {
						long fetchTime = System.currentTimeMillis() - startTime;
						log.info("Got PDF from serveur "+serverUrl+" in "+fetchTime/1000.0+" seconds  size: "+pdfData.length+".");
					}
				}
				catch (Exception e) {
					log.error("PDF serveur "+serverUrl+" does not respond.");
				}
			}
			removeComponentHtmlCaches();
			pdfFetchedFromServer = true;
			return this;
		}
		
		public byte[] getPdfData() {
			return pdfData;
		}
		
		public ERXResponse createInlineViewResponse(String fileName) {
			ERXResponse response = createResponse();
			response.setHeader("inline; filename=\"" + fileName + "\"", "content-disposition");
			return response;
		}

		public ERXResponse createDownloadResponse(String fileName) {
			ERXResponse response = createResponse();
			response.setHeader("attachment; filename=\"" + fileName + "\"", "content-disposition");
			return response;
		}

		// Private methods 
		
		private void removeComponentHtmlCaches() {
			Html2PDFService htmlService = Html2PDFService.getInstance();
			for (String key : componentHtmlKeys) {
				htmlService.forgetHtmlResponseWithKey(key);
			}
		}

		private ERXResponse createResponse() {
			fetchPdfFromServer();
			ERXResponse response = new ERXResponse();
			response.setHeader("private", "cache-control");
			response.setHeader("application/pdf", "content-type");
		    response.setHeader(String.valueOf(pdfData.length), "Content-Length");
			response.setContent(pdfData);
			return response;
		}
	}
	
	Map<String, WOResponse> htmlResponses = Collections.synchronizedMap(new HashMap<String, WOResponse>()); 
	private void registerHtmlResponseWithKey(WOResponse html, String key) {
		cleanResponseCookies(html);
		htmlResponses.put(key, html);
	}
	private void cleanResponseCookies(WOResponse html) {
		for (WOCookie cookie : html.cookies().immutableClone()) {
			html.removeCookie(cookie);
		}
	}

	private void forgetHtmlResponseWithKey(String key) {
		if ( !ERXApplication.isDevelopmentModeSafe() ) {
			htmlResponses.remove(key);
		}
	}


	public WOResponse htmlResponseWithKey(String key) {
		return htmlResponses.get(key);
	}

	public static class Html2Pdf extends ERXDirectAction {

		public Html2Pdf(WORequest r) {
			super(r);
		}
		
		public WOActionResults getHtmlAction() {
			String key = request().stringFormValueForKey("key");
			WOResponse response = Html2PDFService.getInstance().htmlResponseWithKey(key);
			if (response == null) {
				response = new ERXResponse("Unable to find html response with code "+key+".");
			}
			return response;
		}
	}
}
