# L3Dmg Instructions and Methods

## Description
Core of L3 Data management in the FALCON project (http://falcon-project.eu/). 

## Methods

### generateOptimalPath
Returns the optimal path file id for the input XLIFF and language, while its being generated
Method: POST generateOptimalPath
Input: xliffurl, engineID, projectID, customerID
Response: id

### checkOptimalPathStatus
Returns the optimal path file for the input fileId, or error 404 if it is does not exist or has not been generated yet.
Method: GET checkOptimalPathStatus
Input: id
Response: optimalFilePathUrl or error 404 if still processing or doesn't exist


## How to run locally
1. Import the project in Eclipse JEE Mars from https://github.com/CNGL-repo/L3Dmgr.git
2. On L3DmgrServices.java, comment the [PRODUCTION] lines and discomment the [DEVELOPMENT] ones
3. Update the username, replacing "calvodea" by the correct one
4. Run As -> Run on Server. Choose server Tomcat v8.0
5. From a terminal session, type the following example
   curl -X POST --data "xliffurl=http://files.xtm-intl.com/argo/allan_poe_raven.doc.xlf&engineID=falcon_2345_pl_en&projectID=64423&customerID=123412" http://localhost:8080/L3Dmgr/api/generateOptimalPath
6. It will return something like {"id": "3201"}
7. Type http://localhost:8080/L3Dmgr/api/checkOptimalPathStatus?id=3201 (or the number returned)
8. It will return something like {"optimalPathFileUrl": "/home/calvodea/workspace/L3Dmgr/output/results3201.txt"} 
9. If you open /home/calvodea/workspace/L3Dmgr/output/results3201.txt you will see the optimal path file

## How to run in production
1. From a terminal session, type the following example
   curl -X POST --data "xliffurl=http://files.xtm-intl.com/argo/allan_poe_raven.doc.xlf&engineID=falcon_2345_pl_en&projectID=64423&customerID=123412" http://l3dmgr.peep.ie/api/generateOptimalPath
2. It will return something like {"id": "3201"}
3. Type http://l3dmgr.peep.ie/api/checkOptimalPathStatus?id=3201 (or the number returned)
4. It will return something like {"optimalPathFileUrl": "http://l3dmgr.peep.ie/output/results3201.txt"} 
5. If you open http://l3dmgr.peep.ie/output/results3201.txt you will see the optimal path file

## How to deploy to a production server
1. Install Tomcat 8 in the production server (path /opt/tomcat8)
2. On L3DmgrServices.java, comment the [PRODUCTION] lines and discomment the [DEVELOPMENT] ones
3. Update the productions URLS if this is not l3dmgr.peep.ie server. Update the basePath if necessary.
4. From Eclipse, select the project and right-click Export -> Web -> WAR file
5. Upload the new L3Dmgr.war file to the server /opt/tomcat8/webapps. It will automatically extract its content into a L3Dmgr folder
6. Restart the Tomcat server: sudo sh /opt/tomcat8/bin/start.sh
7. Follow the instructions in "How to run in production" to test if it is working properly