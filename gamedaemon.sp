#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <system2>
#include <json>
 
public Plugin myinfo =
{
	name = "Game Daemon",
	author = "Reefiki <reefiki@clani90.com",
	description = "Syncs authorization with clani90.com",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
    PrintToServer("GameDaemon loaded");
}

public OnClientPostAdminCheck(client)
{
	if(!IsFakeClient(client))
	{
	    decl String:name[32];
	    
	    GetClientName(client, name, sizeof(name));
	
	    decl String:authid[32];
	    
	    GetClientAuthId(client, AuthId_SteamID64, authid, sizeof(authid));
	
	    decl String:url[512];
	
	    Format(url, sizeof(url), "%s%s", "http://clani90.com/wp-json/ramp/v1/player/", authid);
	
		
	    System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, url);
	    
	    httpRequest.Any = client;
	    
	    httpRequest.Timeout = 10;
	
	    httpRequest.GET();
	
	    // Requests have to be deleted, until then they can be used more then once
	    delete httpRequest;
	}

}

public void HttpResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
    if (success) {
        char lastURL[128];
        response.GetLastURL(lastURL, sizeof(lastURL));

        int statusCode = response.StatusCode;
        float totalTime = response.TotalTime;
        char username[32];
        bool is_admin = false;

        if (statusCode != 200) {
            KickClient(request.Any, "You are not authorized.");
        }
        
		char[] content = new char[response.ContentLength + 1];
        response.GetContent(content, response.ContentLength + 1);
        
        JSON_Object payload = json_decode(content);

		payload.GetString("username", username, sizeof(username)
		is_admin = payload.GetBool("is_admin");

		if (is_admin == true) {
			AdminId admin = CreateAdmin();
			SetAdminFlag(admin, Admin_Root, true);
			SetUserAdmin(request.Any, admin, true);
		}
        
        SetClientInfo(request.Any, "name", username);
		
        PrintToServer("Request to %s finished with status code %d in %.2f seconds", lastURL, statusCode, totalTime);
    } else {
        PrintToServer("Error on request: %s", error);
    }
}  