package html2pdfserver.sampleapp.components;

import html2pdfserver.sampleapp.Html2PDFService;
import html2pdfserver.sampleapp.Html2PDFService.Request;

import java.util.List;
import java.util.Map;

import org.json.simple.parser.JSONParser;

import com.webobjects.appserver.WOActionResults;
import com.webobjects.appserver.WOContext;
import com.webobjects.appserver.WOResourceManager;
import com.webobjects.foundation.NSArray;
import com.webobjects.foundation.NSComparator;
import com.webobjects.foundation.NSComparator.ComparisonException;
import com.webobjects.foundation.NSMutableDictionary;

import er.extensions.foundation.ERXArrayUtilities;

@SuppressWarnings("serial")
public class PublicSpaceList extends BaseComponent {
	private NSMutableDictionary<String, NSArray<Map<String, Object>>> featuresByTypes;
	private String featureType;
	private boolean addRendererInfos;

	public PublicSpaceList(WOContext context) {
        super(context);
        loadData();
    }
    
    @SuppressWarnings({ "unchecked", "rawtypes" })
	private void loadData() {
    	WOResourceManager resourceManager = application().resourceManager();
    	byte[] fileContent = resourceManager.bytesForResourceNamed("LIEU_PUBLIC.GEOJSON", null, null);
    	String json;
    	try {
    		json = new String(fileContent, "utf-8");

    		JSONParser parser = new JSONParser();

			Map<String, Object> fileDictionnary = (Map<String, Object>)parser.parse(json);
			NSArray features = new NSArray((List)fileDictionnary.get("features"));
    		features = (NSArray<NSMutableDictionary<String, Object>>) features.valueForKey("properties");
    		featuresByTypes = ERXArrayUtilities.arrayGroupedByKeyPath(features, "TYPE").mutableClone();
    		for (String key : featuresByTypes.allKeys()) {
				if (featuresByTypes.objectForKey(key).count() < 6) {
					featuresByTypes.removeObjectForKey(key);
				}
			}
    	} catch (Exception e) {
    		e.printStackTrace();
    	}

    }

	public NSArray<String> featureTypes() throws ComparisonException {
		return featuresByTypes.allKeys().sortedArrayUsingComparator(NSComparator.AscendingCaseInsensitiveStringComparator);
	}

	public String featureType() {
		return featureType;
	}

	public void setFeatureType(String featureType) {
		this.featureType = featureType;
	}

	public int featureTypeCount() {
		return featuresByTypes.objectForKey(featureType).count();
	}

	public WOActionResults printList() {
		PublicSpacePrintedList componentToPrint = createPrintComponentForFeatureType(featureType());
		
		Request pdfRequest = Html2PDFService.createRequest().addComponent(componentToPrint);
		if (addRendererInfos) {
			pdfRequest.addRendererInfos();
		}

		return pdfRequest.createInlineViewResponse(featureType+".pdf");
	}

	public WOActionResults printListPreview() {
		PublicSpacePrintedList componentToPrint = createPrintComponentForFeatureType(featureType());
		
		return componentToPrint;
	}

	private PublicSpacePrintedList createPrintComponentForFeatureType(String featureType) {
		PublicSpacePrintedList componentToPrint = pageWithName(PublicSpacePrintedList.class);
		componentToPrint.setFeatureType(featureType);
		NSArray<Map<String, Object>> features = featuresByTypes.objectForKey(featureType);
		features = ERXArrayUtilities.sortedArraySortedWithKey(features, "NOM_TOPOGR");
		componentToPrint.setFeatures(features);
		return componentToPrint;
	}

	public WOActionResults printAllLists() throws ComparisonException {
		Request pdfRequest = Html2PDFService.createRequest();
		
		for (String type : featureTypes()) {
			PublicSpacePrintedList componentToPrint = createPrintComponentForFeatureType(type);
			pdfRequest.addComponent(componentToPrint);
		}
		if (addRendererInfos) {
			pdfRequest.addRendererInfos();
		}
		return pdfRequest.createInlineViewResponse("AllFeatures.pdf");
	}

	public boolean addRendererInfos() {
		return addRendererInfos;
	}

	public void setAddRendererInfos(boolean addRendererInfos) {
		this.addRendererInfos = addRendererInfos;
	}
}