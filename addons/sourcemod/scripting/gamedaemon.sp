#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <system2>
#include <json>
bool g_cvGated = false;
ConVar g_TollCvar
 
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

	g_TollCvar = CreateConVar("sm_toll", "1", "Allow unauthorized steamids to join the server.");

	RegAdminCmd("sm_gated", Command_ToggleGate, ADMFLAG_CHANGEMAP, "Launches practice mode");
} 

public Action Command_ToggleGate(int client, int args) {
	char full[256];

	GetCmdArgString(full, sizeof(full))

	g_TollCvar.BoolValue = StringToInt(full);

	return Plugin_Handled;
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
		/**
		 *	Send request and parse request metadata
		 **/
        char lastURL[128];
		response.GetLastURL(lastURL, sizeof(lastURL));
		
        int statusCode = response.StatusCode;
        float totalTime = response.TotalTime;


		/**
		 * Check if user exists in database.
		 **/
		if (statusCode != 200) {
			// If sm_gated is true, you must exist in the database.
			if(g_cvGated) {
				KickClient(request.Any, "Members only, clani90.com");
			}
			return;
		}

		/**
		 * Parse json payload and load into memory
		 **/
		char[] content = new char[response.ContentLength + 1];
		response.GetContent(content, response.ContentLength + 1);

		JSON_Object payload = json_decode(content);

		char username[32];		
		payload.GetString("username", username, sizeof(username));

		bool is_admin = false;
		is_admin = payload.GetBool("is_admin");
		

		/**
		 * Give client admin privileges
		 **/
		if (is_admin == true) {
			AdminId admin = CreateAdmin();

			SetAdminFlag(admin, Admin_Root, true);

			SetUserAdmin(request.Any, admin, true);
		}

		/** 
		 * Enforce client name
		 **/
		SetClientInfo(request.Any, "name", username);
		
        PrintToServer("Request to %s finished with status code %d in %.2f seconds", lastURL, statusCode, totalTime);

    } else {
        PrintToServer("Error on request: %s", error);
    }
}  