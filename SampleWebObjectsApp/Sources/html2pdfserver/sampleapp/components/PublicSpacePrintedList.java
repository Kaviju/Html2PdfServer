package html2pdfserver.sampleapp.components;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.util.Map;

import com.webobjects.appserver.WOContext;
import com.webobjects.foundation.NSArray;

@SuppressWarnings("serial")
public class PublicSpacePrintedList extends BaseComponent {
    private String featureType;
	private NSArray<Map<String,Object>> features;
	private Map<String,Object> feature;

	public PublicSpacePrintedList(WOContext context) {
        super(context);
    }

	public String featureType() {
		return featureType;
	}

	public void setFeatureType(String featureType) {
		this.featureType = featureType;
	}

	public NSArray<Map<String,Object>> features() {
		return features;
	}

	public void setFeatures(NSArray<Map<String,Object>> features) {
		this.features = features;
	}

	public Map<String,Object> feature() {
		return feature;
	}

	public void setFeature(Map<String,Object> feature) {
		this.feature = feature;
	}

	public float featureArea() {
		return Float.parseFloat((String) feature().get("SUPERFICIE"));
	}

	public String featureAddress() {
		StringBuilder addressString = new StringBuilder();
		String part = (String)feature.get("NO_CIVIQUE");
		if (part != null) {
			addressString.append(part);
			if (part.endsWith("'") == false) {
				addressString.append(" ");
			}
		}
		 part = (String)feature.get("GENERIQUE");
		if (part != null) {
			addressString.append(part);
			if (part.endsWith("'") == false) {
				addressString.append(" ");
			}
		}
		 part = (String)feature.get("LIAISON");
		if (part != null) {
			addressString.append(part);
			if (part.endsWith("'") == false) {
				addressString.append(" ");
			}
		}
		part = (String)feature.get("SPECIFIQUE");
		if (part != null) {
			addressString.append(part);
			if (part.endsWith("'") == false) {
				addressString.append(" ");
			}
		}
		part = (String)feature.get("DIRECTION");
		if (part != null) {
			addressString.append(part);
			if (part.endsWith("'") == false) {
				addressString.append(" ");
			}
		}
		return addressString.toString();
	}

	public String googleMapUrl() throws UnsupportedEncodingException {
		String address = URLEncoder.encode(featureAddress() + ",Québec,Québec", "utf-8");
		return "https://www.google.com/maps/place/"+address;
	}	
}