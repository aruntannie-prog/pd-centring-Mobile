function doPost(e) {
    try {
        // Parse the incoming JSON payload
        var data = JSON.parse(e.postData.contents);
        var action = data.action || 'upload'; // Default to upload for backward compatibility

        if (action === 'delete') {
            var fileId = data.fileId;
            if (!fileId) throw new Error("Missing fileId for delete action");

            var fileToDelete = DriveApp.getFileById(fileId);
            fileToDelete.setTrashed(true); // Moves the file to Google Drive trash

            return ContentService.createTextOutput(JSON.stringify({
                success: true,
                message: "File deleted successfully",
                fileId: fileId
            })).setMimeType(ContentService.MimeType.JSON);

        } else {
            // Standard Upload Flow
            var base64String = data.base64;
            var filename = data.filename;
            var mimeType = data.mimeType;
            var folderId = data.folderId; // e.g., '152zUFTuiWd1AFrwFT-PUM3CGYs_YAm_W'

            // Decode the base64 string safely
            var base64Data = base64String;
            if (base64String.indexOf("base64,") !== -1) {
                base64Data = base64String.split("base64,")[1];
            }

            // Convert to a blob
            var blob = Utilities.newBlob(Utilities.base64Decode(base64Data), mimeType, filename);

            // Get the destination folder
            var folder = DriveApp.getFolderById(folderId);

            // Create the file in the folder
            var file = folder.createFile(blob);

            // Make the file publicly accessible so the Flutter app can display it via URL
            file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);

            // Return the download/view URL
            return ContentService.createTextOutput(JSON.stringify({
                success: true,
                fileId: file.getId(),
                url: file.getUrl(),
                downloadUrl: file.getDownloadUrl()
            })).setMimeType(ContentService.MimeType.JSON);
        }

    } catch (error) {
        return ContentService.createTextOutput(JSON.stringify({
            success: false,
            error: error.toString()
        })).setMimeType(ContentService.MimeType.JSON);
    }
}

// A simple GET request handler to verify the script is deployed correctly
// OR to perform a safe GET-based deletion avoiding POST body traps.
function doGet(e) {
    try {
        if (!e || !e.parameter) {
            return ContentService.createTextOutput("Google Drive Upload Web App is active (No parameters received)!");
        }

        var paramAction = e.parameter.action || e.parameter['action'];

        if (paramAction === 'delete') {
            var fileId = e.parameter.fileId || e.parameter['fileId'];
            if (!fileId) throw new Error("Missing fileId parameter");

            var fileToDelete = DriveApp.getFileById(fileId);
            fileToDelete.setTrashed(true);

            return ContentService.createTextOutput(JSON.stringify({
                success: true,
                message: "File deleted successfully via GET",
                fileId: fileId
            })).setMimeType(ContentService.MimeType.JSON);
        }

        // If it was a GET request but no action was passed (or it was an unknown action),
        // print out the received parameters for debugging.
        var debugString = JSON.stringify(e.parameter);
        return ContentService.createTextOutput("Google Drive Upload Web App is active! Received GET params: " + debugString);

    } catch (error) {
        return ContentService.createTextOutput(JSON.stringify({
            success: false,
            error: error.toString(),
            receivedParams: e ? e.parameter : "none"
        })).setMimeType(ContentService.MimeType.JSON);
    }
}
