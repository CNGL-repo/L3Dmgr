package l3dmgr.com.webservices;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.ProtocolException;
import java.net.URL;
import java.net.URLConnection;

import javax.ws.rs.FormParam;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import org.joox.Match;
import org.w3c.dom.DOMException;
import org.xml.sax.SAXException;

import static org.joox.JOOX.$;

@Path("/")
public class L3DmgrServices {
	
/* Comment or discomment the lines below depending on the environment, and update the username ("calvodea") */
	String basePath = "/var/www/webservices/l3dmgr/"; // [PRODUCTION] Path to default input files 
	String resultsBaseURL = "http://l3dmgr.peep.ie/output/"; // [PRODUCTION] URL to results file
//	String basePath = "/home/calvodea/workspace/L3Dmgr/"; // [DEVELOPMENT] Path to default input files
//	String resultsBaseURL = basePath + "output/"; // [DEVELOPMENT] URL to results file
	
	@POST
	@Path("/generateOptimalPath")
	@Produces(MediaType.APPLICATION_JSON)
	/* Returns the processing id to generate the optimal path for the input XLIFF file and the engine Id
	 * (source and target languages) applying the reordering algorithm */
	public Response generateOptimalPathService(
			@FormParam("xliffurl") String xliffFileURL, // e.g. "http://falcon.xtm-intl.com/generatedfiles/1/file.xlf"
			@FormParam("engineID") String engineId, // e.g. "falcon_2345_pl_en"
			@FormParam("projectID") String projectId, // e.g. "12341234"
			@FormParam("customerID") String customerId) // e.g. "4346454"
					throws IOException, InterruptedException, DOMException, SAXException { 
		
		// If URL is not accessible, return code "404"
		if (isURLAccessible(xliffFileURL) == false) {
			return Response.status(404).build();
		}
		
		// Generate a new processingId for the optimal path generation
		String processingId = getNextProcessingId();
		
		// Transform input Xliff file into plain text
		String plainTextInputFile = parseXliffToPlainText(xliffFileURL, processingId);
		
		// Get the lang (last 2 letters of the engineID) and pass them on to the process
		String outputLanguage = engineId.substring(engineId.length() - 2, engineId.length());
		
		Process p = Runtime.getRuntime().exec("perl " + basePath + "RankSegMatch.pl --termfile " + basePath 
				+ "eurovoc_flat.txt --lang " + outputLanguage + " --outprefix " + processingId + " --outputpath "
				+ basePath + "output/ " + plainTextInputFile);
		
		String jsonResponse = "{\"id\": \"" + processingId + "\"}";
		
		return Response.ok(jsonResponse, MediaType.APPLICATION_JSON).build();
	}


	/* Checks that the provided URL is accessible */
	private boolean isURLAccessible(String xliffFileURL)
			throws MalformedURLException, IOException, ProtocolException {

		URL xliffURL = new URL(xliffFileURL);
		HttpURLConnection testConnection = (HttpURLConnection)xliffURL.openConnection();
		testConnection.setRequestMethod("HEAD"); 
		int code = testConnection.getResponseCode();
		
		if (code == HttpURLConnection.HTTP_OK) // OK, accessible
			return true;
		else // Not accessible
			return false;
	}
	
	
	/* Transform the input Xliff file into a new plain-text file hosted in the server, and returns its path */
	private String parseXliffToPlainText(String xliffFileURL, String processingId) throws DOMException, SAXException, IOException {

		String plainTextFileURL = basePath + "output/plainTextInputFile" + processingId + ".txt";
		File plainTextFile = new File(plainTextFileURL);
    	BufferedWriter writer = new BufferedWriter(new FileWriter(plainTextFile));
		
    	String localXliffFilePath = copyFileToLocalhost(xliffFileURL, processingId);
		Match document = $(new File(localXliffFilePath));
		Match sources = document.find("source");

		for (Match source : sources.each()) {
			writer.write(source.content() + "\n");
		}
		writer.close(); // Close write file
		
		return plainTextFileURL;
	}
	
	// Read from sequence.txt the number, increment it + 1, overwrite the file and return it
	private String getNextProcessingId() {
		
		// Read original number
		File file = new File(basePath + "sequence.txt");
		BufferedReader reader = null;
		String currentProcessingId = null;
		
		try {
		    reader = new BufferedReader(new FileReader(file));
		    currentProcessingId = reader.readLine(); // Read number from file
		} catch (FileNotFoundException e) {
		    e.printStackTrace();
		} catch (IOException e) {
		    e.printStackTrace();
		} finally {
		    try {
		        if (reader != null) {
		        	int nextProcessingId = Integer.parseInt(currentProcessingId) + 1;
		            reader.close(); // Close read file
		        	BufferedWriter writer = new BufferedWriter(new FileWriter(file));
		        	writer.write(Integer.toString(nextProcessingId));
		        	writer.close(); // Close write file
		        }
		    } catch (IOException e) {
		    }
		}
		
		return currentProcessingId;
	}
	
	/* Make an exact copy of the remote Xliff file and paste it in the localhost, returning the path */
	private String copyFileToLocalhost(String xliffFileURL, String processingId) throws IOException {
		
		String localXliffFilePath = basePath + "temp/sourceXliff" + processingId + ".txt";
		URL inputURL = new URL(xliffFileURL);
		InputStream inputXliffFile = inputURL.openStream();
		
		FileOutputStream outputXliffFile = new FileOutputStream(localXliffFilePath);
		final int BUF_SIZE = 1 << 8;
		byte[] buffer = new byte[BUF_SIZE];
		int bytesRead = -1;
		while((bytesRead = inputXliffFile.read(buffer)) > -1) {
			outputXliffFile.write(buffer, 0, bytesRead);
		}
		
		inputXliffFile.close();
		outputXliffFile.close();
		
		return localXliffFilePath;
	}
	
	
	@GET
	@Path("/checkOptimalPathStatus")
	@Produces(MediaType.APPLICATION_JSON)
	/* Returns the URL of the file that contains the optimal path for the specified processing id */
	public Response checkOptimalPathStatus(
			@QueryParam("id") String processId) // Id of the optimal path process
					throws IOException, InterruptedException {
	
		String optimalPathFileName = "results" + processId + ".txt";
		// Absolute path where the Optimal Path result files are hosted
		String resultsBasePath = basePath + "output/";
		
		File f = new File(resultsBasePath + optimalPathFileName);
		if(f.exists()) { // The file is ready and available
			String jsonResponse = "{\"optimalPathFileUrl\": \"" + resultsBaseURL + optimalPathFileName + "\"}";
			return Response.ok(jsonResponse, MediaType.APPLICATION_JSON).build();
		}
		else { // The file does not exist or it is not ready yet
			return Response.status(404).build();			
		}
	}
}