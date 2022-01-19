#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <system2>
#include <json>
ConVar g_hTollConVar
 
public Plugin myinfo =
{
	name = "Game Daemon",
	author = "Sh3nl0ng <shen@mousespaz.com>",
	description = "Syncs authorization with spaz.gg",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	PrintToServer("GameDaemon loaded");

	g_hTollConVar = CreateConVar("spaz_toll", "1", "Allow unauthorized steamids to join the server.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);	
	HookConVarChange(g_hTollConVar, ConVar_TollChange)
}

public ConVar_TollChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new enabled = GetConVarBool(g_hTollConVar);

	for(new i = 1; i <= MaxClients; i++){
		if(IsClientInGame(i)){
			if(enabled){
			    PrintToChat(i, "server is now admitting members only.");
			} else {
				PrintToChat(i, "server is now open to the public.");
			}
		}
	}	
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
	
	    Format(url, sizeof(url), "%s%s", "http://spaz.gg/api/steamid/", authid);
	
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
			if(GetConVarBool(g_hTollConVar)) {
				KickClient(request.Any, "Members only, join at spaz.gg");
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
		
        json_cleanup(payload);
		

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
