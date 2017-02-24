package html2pdfserver.sampleapp;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.ProtocolException;
import java.net.URL;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import org.apache.log4j.Logger;

import com.webobjects.appserver.WOApplication;
import com.webobjects.appserver.WOComponent;
import com.webobjects.appserver.WOContext;
import com.webobjects.appserver.WOCookie;
import com.webobjects.appserver.WORequest;
import com.webobjects.appserver.WORequestHandler;
import com.webobjects.appserver.WOResponse;
import com.webobjects.foundation.NSArray;
import com.webobjects.foundation.NSMutableArray;

import er.extensions.appserver.ERXApplication;
import er.extensions.appserver.ERXResponse;
import er.extensions.appserver.ERXSession;
import er.extensions.appserver.ERXWOContext;
import er.extensions.appserver.ajax.ERXAjaxApplication;
import er.extensions.appserver.ajax.ERXAjaxSession;
import er.extensions.foundation.ERXProperties;
import er.extensions.foundation.ERXThreadStorage;
import er.extensions.foundation.ERXValueUtilities;

public class Html2PDFService {
	public static final Logger log = Logger.getLogger(Html2PDFService.class);
	private static final String isPrintingStorageKey = "HTML2PDFService_isPrinting";

	static public Request createRequest() {
		return new Request();
	}

	static public boolean isPrinting() { 
		return ERXValueUtilities.booleanValue(ERXThreadStorage.valueForKey(isPrintingStorageKey));
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
		private static final String AddRenderedInfosCommand = "addRendererInfos";
		private boolean addRendererInfos = false;
		private boolean pdfFetchedFromServer = false;
		NSMutableArray<ResponseCacheRequest>responseCacheRequests = new NSMutableArray<ResponseCacheRequest>();
		NSMutableArray<String>commands = new NSMutableArray<String>();
		private byte[] pdfData;

		public Request setCurrentPageNumber(int pageNumber) {
			commands.add("setCurrentPageNumber:"+pageNumber);
			return this;
		}

		public Request ensureEvenPageCount() {
			commands.add("ensureEvenPageCount");
			return this;
		}

		public Request addBlankPage() {
			commands.add("insertBlankPage");
			return this;
		}

		public Request addRendererInfos() {
			addRendererInfos  = true;
			return this;
		}

		public Request addComponent(WOComponent component) {
			ResponseCacheRequest responseCacheRequest = ResponseCacheRequest.requestForComponent(component);
			responseCacheRequests.add(responseCacheRequest);

			commands.add("renderPdfAtUrl:"+responseCacheRequest.completeUrl());
			return this;
		}

		public Request addPdfFromResource(String filename) {
			addPdfFromResource(filename, "app");
			return this;
		}

		public Request addPdfFromResource(String filename, String framework) {
			WOContext context = ERXWOContext.currentContext();
			context = (WOContext) context.clone();
			context.generateCompleteURLs();
			String url = context._urlForResourceNamed(filename, framework, true);
			if (context.request().isUsingWebServer()) {
				StringBuffer urlBuilder = new StringBuffer(256);
				context.request()._completeURLPrefix(urlBuilder, false, 0);
				urlBuilder.append(url);
				url = urlBuilder.toString();
			}
			commands.add("appendPdfAtUrl:"+url);
			return this;
		}

		private byte[] readBytesFromUrl(String urlString, NSMutableArray<String> commands) throws IOException {
			URL url = new URL(urlString);

			HttpURLConnection urlConn = (HttpURLConnection) url.openConnection();
			urlConn.setDoInput(true);
			urlConn.setConnectTimeout(1000);
			int timeout = ERXProperties.intForKeyWithDefault("html2pdfReadTimeout", 15000);
			urlConn.setReadTimeout(timeout);

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

		public Request fetchPdfFromServer() {
			if (pdfFetchedFromServer) {
				return this;
			}
			long startTime = System.currentTimeMillis();
			log.info("Trying PDF serveurs for commands: \n"+commands.componentsJoinedByString("\n"));
			NSArray<String> serverUrls = ERXProperties.arrayForKeyWithDefault("html2pdfServers", new NSArray<String>("http://localhost:1453/"));
			for (String serverUrl : serverUrls) {
				try {
					pdfData = readBytesFromUrl(serverUrl, commands);
					if (pdfData != null) {
						long fetchTime = System.currentTimeMillis() - startTime;
						log.info("Got PDF from serveur "+serverUrl+" in "+fetchTime/1000.0+" seconds  size: "+pdfData.length+".");
						break;
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

		private void addCommandsToRequest(NSMutableArray<String> commands, HttpURLConnection urlConn) 
				throws UnsupportedEncodingException, ProtocolException, IOException {
			if (commands != null) {
				if (addRendererInfos) {
					commands.addObject(AddRenderedInfosCommand);
				}
				
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

		public byte[] getPdfData() {
			fetchPdfFromServer();
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
			for (ResponseCacheRequest request : responseCacheRequests) {
				request.forgetResponse();
			}
		}

		private ERXResponse createResponse() {
			fetchPdfFromServer();
			ERXAjaxApplication.enableShouldNotStorePage();
			ERXResponse response = new ERXResponse();
			response.setHeader("private", "cache-control");
			response.setHeader("application/pdf", "content-type");
			response.setHeader(String.valueOf(pdfData.length), "Content-Length");
			response.setContent(pdfData);
			return response;
		}

		@Override
		protected void finalize() throws Throwable {
			if (pdfFetchedFromServer == false) {
				removeComponentHtmlCaches();
			}
			super.finalize();
		}
	}

	// Auto register the RequestHandler when the class is first used. 
	static {
	    WOApplication.application().registerRequestHandler(new ResponseCacheRequestHandler(), ResponseCacheRequestHandler.REQUEST_HANDLER_KEY);
	}

	// We need a custom request handler that will work when the app refuses new session with no session in cookies and URL.
	// We cannot use the current session because it is currently locked by the current request and the renderer process will not be able to get the html.
	public static class ResponseCacheRequestHandler extends WORequestHandler {
		public static final String REQUEST_HANDLER_KEY = "html2pdf";
		
		@Override
		public WOResponse handleRequest(WORequest request) {
			WOApplication application = WOApplication.application();
			application.awake();
			try {		      
				final String key = request._uriDecomposed().requestHandlerPath();
				WOResponse response = ResponseCacheRequest.htmlResponseWithKey(key);
				return response;
			}
			finally {
				application.sleep();
			}
		}
	}
	
	public static class ResponseCacheRequest {
		static int documentNumber = 0;
		static Map<String, WOResponse> htmlResponses = Collections.synchronizedMap(new HashMap<String, WOResponse>());

		static private void registerHtmlResponseWithKey(WOResponse html, String key) {
			log.info("Register response with code: "+key);
			cleanResponseCookies(html);
			htmlResponses.put(key, html);
		}
		
		static private void cleanResponseCookies(WOResponse html) {
			for (WOCookie cookie : html.cookies().immutableClone()) {
				html.removeCookie(cookie);
			}
		}

		static private void forgetHtmlResponseWithKey(String key) {
			log.info("Forget response with code: "+key);
			if ( !ERXApplication.isDevelopmentModeSafe() ) {
				htmlResponses.remove(key);
			}
		}

		static public WOResponse htmlResponseWithKey(String key) {
			log.info("Return response with code: "+key);
			return htmlResponses.get(key);
		}

		// We make sure the component is not using the current context to keep it clean. We need the request to generate valid URLs.
		// By setting DONT_STORE_PAGE, we do not use a page cache entry in the current session. 
		static public ResponseCacheRequest requestForComponent(WOComponent component) {
			HashMap<String,Object> threadStorageMap = new HashMap<>(ERXThreadStorage.map());
			
			ERXWOContext newContext = (ERXWOContext) component.context().clone();
			component._setContext(newContext);
			ERXThreadStorage.map().keySet();   ERXSession.currentSessionID();
			WOResponse html;
			
			ERXThreadStorage.takeValueForKey(true, isPrintingStorageKey);
			ERXWOContext.contextDictionary().takeValueForKey(ERXAjaxSession.DONT_STORE_PAGE, ERXAjaxSession.DONT_STORE_PAGE);
			html = component.generateResponse();
			ERXWOContext.contextDictionary().removeObjectForKey(ERXAjaxSession.DONT_STORE_PAGE);
			ERXThreadStorage.removeValueForKey(isPrintingStorageKey);
			ERXThreadStorage.reset();
			ERXThreadStorage.map().putAll(threadStorageMap);
			return requestWithResponse(html);
		}

		static public ResponseCacheRequest requestWithHtml(String html) {
			ResponseCacheRequest request = new ResponseCacheRequest(new ERXResponse(html));
			return request;
		}

		static public ResponseCacheRequest requestWithResponse(WOResponse response) {
			ResponseCacheRequest request = new ResponseCacheRequest(response);
			return request;
		}

		// Instance variables and methods
		String key;

		private ResponseCacheRequest(WOResponse response) {
			key = "d"+documentNumber++;
			registerHtmlResponseWithKey(response, key);
		}

		public String completeUrl() {			
			ERXWOContext sessionLessContext = new ERXWOContext(ERXWOContext.currentContext().request());
			sessionLessContext._setSession(ERXWOContext.currentContext().session());
			sessionLessContext.generateCompleteURLs();
			sessionLessContext._url().setApplicationNumber(String.valueOf(sessionLessContext.request().applicationNumber()));
			String url = sessionLessContext.urlWithRequestHandlerKey(ResponseCacheRequestHandler.REQUEST_HANDLER_KEY, key, null);
			return url;
		}

		public void forgetResponse() {
			forgetHtmlResponseWithKey(key);
		}

		@Override
		protected void finalize() throws Throwable {
			forgetHtmlResponseWithKey(key);
			super.finalize();
		}
	}
}
