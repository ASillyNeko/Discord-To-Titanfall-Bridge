untyped

global function DiscordBridge_Init
global function DiscordBridgeConsoleLog_Init

table<string, string> MAP_NAME_TABLE = {
	mp_lobby = "Lobby",
	mp_angel_city = "Angel City",
	mp_black_water_canal = "Black Water Canal",
	mp_coliseum = "Coliseum",
	mp_coliseum_column = "Pillars",
	mp_colony02 = "Colony",
	mp_complex3 = "Complex",
	mp_crashsite3 = "Crash Site",
	mp_drydock = "Drydock",
	mp_eden = "Eden",
	mp_forwardbase_kodai = "Forwardbase Kodai",
	mp_glitch = "Glitch",
	mp_grave = "Boomtown",
	mp_homestead = "Homestead",
	mp_lf_deck = "Deck",
	mp_lf_meadow = "Meadow",
	mp_lf_stacks = "Stacks",
	mp_lf_township = "Township",
	mp_lf_traffic = "Traffic",
	mp_lf_uma = "UMA",
	mp_relic02 = "Relic",
	mp_rise = "Rise",
	mp_thaw = "Exoplanet",
	mp_wargames = "Wargames",
}

struct
{
	string webhook = ""
	string commandlogwebhook = ""
	string consolelogwebhook = ""
	bool crashmessage = false

	string bottoken = ""
	string serverid = ""
	string channelid = ""
	string rconchannelid = ""
	string rconusers = ""
	bool allowbotsrcon = false

	int queue = 0
	int realqueue = 0
	float queuetime = 0

	table<entity, int> anotherqueue
	table<entity, int> anotherrealqueue
	table<entity, bool> haseverbeenalive
	table<string, string> namelist

	string logprints = ""
} file

void function DiscordBridge_Init()
{
	AddCallback_OnReceivedSayTextMessage( LogMessage )
	AddCallback_OnClientConnected( LogJoin )
	AddCallback_OnClientDisconnected( LogDisconnect )
	thread MapChange()

	AddCallback_OnPlayerRespawned( HasEverBeenAlive )
	thread DiscordMessagePoller()
}

void function DiscordBridgeConsoleLog_Init()
{
	file.webhook = GetConVarString( "discordbridge_webhook" )
	file.commandlogwebhook = GetConVarString( "discordbridge_commandlogwebhook" )
	file.consolelogwebhook = GetConVarString( "discordbridge_consolelogwebhook" )
	file.crashmessage = GetConVarBool( "discordbridge_shouldsendmessageifservercrashandorrestart" )

	file.bottoken = GetConVarString( "discordbridge_bottoken" )
	file.serverid = GetConVarString( "discordbridge_serverid" )
	file.channelid = GetConVarString( "discordbridge_channelid" )
	file.rconchannelid = GetConVarString( "discordbridge_rconchannelid" )
	file.rconusers = GetConVarString( "discordbridge_rconusers" )
	file.allowbotsrcon = GetConVarBool( "discordbridge_allowbotsrcon" )

	PrintsShowScriptLocation( GetConVarBool( "discordbridge_printsshowscriptlocation" ) )
	AddPrintHookWithScriptLocation( LogPrints )
	thread LogHandle()
}

ClServer_MessageStruct function LogMessage( ClServer_MessageStruct message )
{
	if ( !IsNewThread() )
	{
		thread LogMessage( message )
		return message
	}

	string msg = message.message

	if ( !msg.len() )
		return message

	string playername = message.player.GetPlayerName()
	int playerteam = message.player.GetTeam()
	string prefix = ""
	string teamstr = ""
	string communitytag = message.player.GetCommunityClanTag().len() ? "[" + message.player.GetCommunityClanTag() + "] " : ""

	if ( playerteam == TEAM_IMC )
		teamstr = "IMC"
	else if ( playerteam == TEAM_MILITIA )
		teamstr = "Militia"

	if ( message.isTeam && !IsFFAGame() && GetCurrentPlaylistVarInt( "max_teams", 2 ) == 2 )
		prefix = "[TEAM (" + teamstr + ")] " + ( message.shouldBlock ? "(HIDDEN) " : "" ) + communitytag + playername
	else
		prefix = "(" + teamstr + ") " + ( message.shouldBlock ? "(HIDDEN) " : "" ) + communitytag + playername

	MessageQueue()

	SendMessageToDiscord( "**" + prefix + ":** " + msg, ( message.shouldBlock ? file.commandlogwebhook : file.webhook ) )

	return message
}

void function LogJoin( entity player )
{
	if ( !IsNewThread() )
	{
		thread LogJoin( player )
		return
	}

	string playername = "Someone"
	string uid = "0"

	if ( IsValid( player ) && player.IsPlayer() )
	{
		playername = player.GetPlayerName()
		uid = player.GetUID()
	}

	string message = playername + "[" + uid + "] Has (Re)Connected [Currently Connected Players " + GetPlayerArray().len() + "/" + GetCurrentPlaylistVarInt( "max_players", 16 ) + "]"

	MessageQueue()

	SendMessageToDiscord( "```" + message + "```", file.webhook )
}

void function LogDisconnect( entity player )
{
	if ( !IsNewThread() )
	{
		thread LogDisconnect( player )
		return
	}

	string playername = "Someone"
	string uid = "0"

	if ( IsValid( player ) && player.IsPlayer() )
	{
		playername = player.GetPlayerName()
		uid = player.GetUID()
	}

	int playercount = GetPlayerArray().len() - 1
	string message = playername + "[" + uid + "] Has Disconnected [Currently Connected Players " + playercount + "/" + GetCurrentPlaylistVarInt( "max_players", 16 ) + "]"

	MessageQueue()

	SendMessageToDiscord( "```" + message + "```", file.webhook )
}

void function LogPrints( var text, bool hasnewline )
{
	string clonedtext = expect string( text )

	if ( hasnewline )
		clonedtext = clonedtext.slice( 0, clonedtext.len() - "\n".len() )

	file.logprints += file.logprints.len() ? "\n" + clonedtext : clonedtext
}

void function LogHandle()
{
	WaitFrame()

	while ( true )
	{
		while ( !file.logprints.len() )
			WaitFrame()

		wait 0.75

		string logprints = file.logprints

		if ( logprints.len() )
		{
			if ( logprints.len() >= 1950 )
				logprints = logprints.slice( 0, 1950 )

			SendMessageToDiscord( "```" + logprints + "```", file.consolelogwebhook )

			file.logprints = file.logprints.slice( logprints.len() )
		}
	}
}

void function SendMessageToDiscord( string message, string webhook )
{
	if ( !webhook.len() )
		return

	table payload = {
		content = message
		allowed_mentions = {
			parse = []
		}
	}

	HttpRequest request

	request.method = HttpRequestMethod.POST
	request.url = webhook

	if ( !( request.url.len() >= "https://".len() && request.url.slice( 0, "https://".len() ).tolower() == "https://" ) )
		request.url = "https://" + request.url

	request.body = EncodeJSON( payload )
	request.headers = {
		[ "Content-Type" ] = [ "application/json" ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		printt( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, null, onFailure )
}

void function MapChange()
{
	MessageQueue()

	string crashmessage = file.crashmessage ? "Server Has Crashed/Restarted\n\n" : ""

	if ( crashmessage.len() )
		SetConVarInt( "discordbridge_shouldsendmessageifservercrashandorrestart", 0 )

	string message = crashmessage + "Map Has Changed To" + ( GetMapName() in MAP_NAME_TABLE ? ( " " + MAP_NAME_TABLE[ GetMapName() ] ) : "" ) + " [" + GetMapName() + "]"

	SendMessageToDiscord( "```" + message + "```", file.webhook )
}

void function MessageQueue()
{
	int queue = file.queue

	file.queue += 1

	while ( file.realqueue < queue || file.queuetime > Time() )
		WaitFrame()

	file.queuetime = Time() + 0.50
	file.realqueue += 1
}

string last_discord_messageid = ";"
string rconlast_discord_messageid = ";"

void function DiscordMessagePoller()
{
	WaitFrame()

	if ( !file.bottoken.len() || !file.serverid.len() )
		return

	while ( true )
	{
		if ( GetPlayerArray().len() )
		{
			if ( file.channelid.len() )
				PollDiscordMessages()

			if ( file.rconchannelid.len() )
				RconPollDiscordMessages()
		}
		else
		{
			last_discord_messageid = ";"

			if ( file.rconchannelid.len() )
				RconPollDiscordMessages()
		}

		wait RandomFloatRange( 1.25, 1.5 )
	}
}

void function PollDiscordMessages()
{
	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url = "https://discord.com/api/v9/channels/" + file.channelid + "/messages?limit=5" + ( last_discord_messageid != ";" ? "&after=" + last_discord_messageid : "" )
	request.headers = {
		[ "Authorization" ] = [ "Bot " + file.bottoken ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		thread ThreadDiscordToTitanfallBridge( response )
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		printt( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function RconPollDiscordMessages()
{
	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url = "https://discord.com/api/v9/channels/" + file.rconchannelid + "/messages?limit=5" + ( rconlast_discord_messageid != ";" ? "&after=" + rconlast_discord_messageid : "" )
	request.headers = {
		[ "Authorization" ] = [ "Bot " + file.bottoken ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		thread RconThreadDiscordToTitanfallBridge( response )
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		printt( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function ThreadDiscordToTitanfallBridge( HttpRequestResponse response )
{
	if ( response.statusCode == 200 )
	{
		string responsebody = response.body

		responsebody = StringReplace( responsebody, "\"message_reference\"", "\"message_reference\"", true )
		responsebody = StringReplace( responsebody, "},{\"type\"", "},{\"type\"", true )

		array<string> arrayresponse = split( responsebody, "" )
		array<string> fixedresponse = []

		foreach ( string fixresponse in arrayresponse )
			if ( fixresponse.find( "\"message_reference\"" ) == null )
				fixedresponse.append( fixresponse )

		responsebody = ""

		foreach ( string fixresponse in fixedresponse )
			responsebody += fixresponse

		responsebody = StringReplace( responsebody, "\"mention_roles\"", "\"mention_roles\"", true )
		responsebody = StringReplace( responsebody, "\"timestamp\":\"", "\"timestamp\":\"", true )

		arrayresponse = split( responsebody, "" )
		fixedresponse = []

		foreach ( string fixresponse in arrayresponse )
			if ( fixresponse.find( "\"attachments\"" ) == null && fixresponse.find( "\"embeds\"" ) == null )
				fixedresponse.append( fixresponse )

		responsebody = ""

		foreach ( string fixresponse in fixedresponse )
			responsebody += fixresponse

		responsebody = StringReplace( responsebody, "},{\"type\"", "[{", true )

		array<string> newresponse = split( responsebody, "" )

		if ( !newresponse.len() || newresponse[0].len() <= 3 )
			return

		string lastmessageid = last_discord_messageid
		string newestmessageid = ""

		newresponse.reverse()

		int i = 0

		foreach ( string newresponsestr in newresponse )
		{
			i += 1

			responsebody = newresponsestr
			responsebody = StringReplace( responsebody, "\"author\"", "author\"", true )
			responsebody = StringReplace( responsebody, "\"pinned\"", "pinned\"", true )
			responsebody = StringReplace( responsebody, "\"mentions\"", "mentions\"", true )
			responsebody = StringReplace( responsebody, "\"channel_id\"", "channel_id\"", true )

			arrayresponse = split( responsebody, "" )

			if ( arrayresponse.len() != 5 )
			{
				if ( i == newresponse.len() )
				{
					if ( !newestmessageid.len() )
						last_discord_messageid = "0"
					else
						last_discord_messageid = newestmessageid
				}

				continue
			}

			string message = arrayresponse[0]

			message = message.slice( 0, -2 )

			while ( message.find( ":\"" ) )
				message = message.slice( 1 )

			message = message.slice( 2 )
			message = StringReplace( message, "\\\"", "\"", true )
			message = StringReplace( message, "\\\\", "\\", true )

			string userid = arrayresponse[3]

			userid = userid.slice( 15 )

			while ( userid.find( "\"" ) )
				userid = userid.slice( 0, -1 )

			string messageid = arrayresponse[1]

			messageid = messageid.slice( 0, -2 )

			while ( messageid.find( "id" ) )
				messageid = messageid.slice( 1 )

			messageid = messageid.slice( 5 )
			newestmessageid = messageid

			if ( i == newresponse.len() )
				last_discord_messageid = newestmessageid

			if ( lastmessageid < newestmessageid && lastmessageid != newestmessageid && arrayresponse[3].find( "\"bot\"" ) == null && GetPlayerArray().len() )
			{
				if ( message.len() > 200 || message.len() <= 0 )
					RedCircleDiscordToTitanfallBridge( messageid, file.channelid )
				else
					thread EndThreadDiscordToTitanfallBridge( message, userid, messageid )

				wait 0.25
			}
		}
	}
	else
	{
		printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
		printt( "[DiscordBridge] Response Body: " + response.body )
	}
}

void function RconThreadDiscordToTitanfallBridge( HttpRequestResponse response )
{
	if ( response.statusCode == 200 )
	{
		string responsebody = response.body

		responsebody = StringReplace( responsebody, "\"message_reference\"", "\"message_reference\"", true )
		responsebody = StringReplace( responsebody, "},{\"type\"", "},{\"type\"", true )

		array<string> arrayresponse = split( responsebody, "" )
		array<string> fixedresponse = []

		foreach ( string fixresponse in arrayresponse )
			if ( fixresponse.find( "\"message_reference\"" ) == null )
				fixedresponse.append( fixresponse )

		responsebody = ""

		foreach ( string fixresponse in fixedresponse )
			responsebody += fixresponse

		responsebody = StringReplace( responsebody, "\"mention_roles\"", "\"mention_roles\"", true )
		responsebody = StringReplace( responsebody, "\"timestamp\":\"", "\"timestamp\":\"", true )

		arrayresponse = split( responsebody, "" )
		fixedresponse = []

		foreach ( string fixresponse in arrayresponse )
			if ( fixresponse.find( "\"attachments\"" ) == null && fixresponse.find( "\"embeds\"" ) == null )
				fixedresponse.append( fixresponse )

		responsebody = ""

		foreach ( string fixresponse in fixedresponse )
			responsebody += fixresponse

		responsebody = StringReplace( responsebody, "},{\"type\"", "[{", true )

		array<string> newresponse = split( responsebody, "" )

		if ( !newresponse.len() || newresponse[0].len() <= 3 )
			return

		string lastmessageid = rconlast_discord_messageid
		string newestmessageid = ""

		newresponse.reverse()

		int i = 0

		foreach ( string newresponsestr in newresponse )
		{
			i += 1

			responsebody = newresponsestr
			responsebody = StringReplace( responsebody, "\"author\"", "author\"", true )
			responsebody = StringReplace( responsebody, "\"pinned\"", "pinned\"", true )
			responsebody = StringReplace( responsebody, "\"mentions\"", "mentions\"", true )
			responsebody = StringReplace( responsebody, "\"channel_id\"", "channel_id\"", true )

			arrayresponse = split( responsebody, "" )

			if ( arrayresponse.len() != 5 )
			{
				if ( i == newresponse.len() )
				{
					if ( !newestmessageid.len() )
						rconlast_discord_messageid = "0"
					else
						rconlast_discord_messageid = newestmessageid
				}

				continue
			}

			string message = arrayresponse[0]

			message = message.slice( 0, -2 )

			while ( message.find( ":\"" ) )
				message = message.slice( 1 )

			message = message.slice( 2 )
			message = StringReplace( message, "\\\"", "\"", true )
			message = StringReplace( message, "\\\\", "\\", true )

			string userid = arrayresponse[3]

			userid = userid.slice( 15 )

			while ( userid.find( "\"" ) )
				userid = userid.slice( 0, -1 )

			string messageid = arrayresponse[1]

			messageid = messageid.slice( 0, -2 )

			while ( messageid.find( "id" ) )
				messageid = messageid.slice( 1 )

			messageid = messageid.slice( 5 )
			newestmessageid = messageid

			if ( i == newresponse.len() )
				rconlast_discord_messageid = newestmessageid

			if ( lastmessageid < newestmessageid && ( arrayresponse[3].find( "\"bot\"" ) == null || file.allowbotsrcon ) )
			{
				if ( message.len() >= "?rconscript".len() && message.slice( 0, "?rconscript".len() ).tolower() == "?rconscript" )
				{
					array<string> rconusers = split( file.rconusers, "," )

					bool shouldruncommand = false

					for ( int i = 0; i < rconusers.len(); i++ )
						if ( rconusers[i] == userid )
							shouldruncommand = true

					if ( shouldruncommand || !rconusers.len() )
					{
						printt( "[DiscordBridge] Running Rcon Script Sent By: " + userid + ": " + message )

						try
						{
							thread compilestring( message.slice( 11 ) )()
							GreenCircleDiscordToTitanfallBridge( messageid, file.rconchannelid )
						}
						catch ( error )
							RedCircleDiscordToTitanfallBridge( messageid, file.rconchannelid )
					}
					else
						OrangeCircleDiscordToTitanfallBridge( messageid, file.rconchannelid )
				}
				else if ( message.len() >= "?rcon".len() && message.slice( 0, "?rcon".len() ).tolower() == "?rcon" )
				{
					array<string> rconusers = split( file.rconusers, "," )

					bool shouldruncommand = false

					for ( int i = 0; i < rconusers.len(); i++ )
						if ( rconusers[i] == userid )
							shouldruncommand = true

					if ( shouldruncommand || !rconusers.len() )
					{
						GreenCircleDiscordToTitanfallBridge( messageid, file.rconchannelid )
						printt( "[DiscordBridge] Running Rcon Command Sent By: " + userid + ": " + message )
						ServerCommand( message.slice( 5 ) )
					}
					else
						OrangeCircleDiscordToTitanfallBridge( messageid, file.rconchannelid )
				}

				wait 0.25
			}
		}
	}
	else
	{
		printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
		printt( "[DiscordBridge] Response Body: " + response.body )
	}
}

void function GetUserNickname( string userid )
{
	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url = "https://discord.com/api/v9/guilds/" + file.serverid + "/members/" + userid
	request.headers = {
		[ "Authorization" ] = [ "Bot " + file.bottoken ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response ) : ( userid )
	{
		if ( response.statusCode == 200 )
		{
			string responsebody = response.body

			responsebody = StringReplace( responsebody, "\"nick\"", "nick\"", true )
			responsebody = StringReplace( responsebody, "\"pending\"", "pending\"", true )
			responsebody = StringReplace( responsebody, "\"global_name\"", "global_name\"", true )
			responsebody = StringReplace( responsebody, "\"avatar_decoration_data\"", "avatar_decoration_data\"", true )

			array<string> newresponse = split( responsebody, "" )

			string message = newresponse[1]

			message = StringReplace( message, "nick\":", "" )

			if ( message.find( "\"," ) )
				file.namelist[ userid ] <- message.slice( 1, -2 )
			else if ( newresponse[3].find( "name" ) )
				file.namelist[ userid ] <- newresponse[3].slice( 14, -2 )
		}
		else
		{
			printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			printt( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		printt( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

string function GetUserTrueNickname( string userid )
{
	wait 0.75

	if ( userid in file.namelist )
		return file.namelist[ userid ]

	return "Unknown"
}


void function SendMessageToPlayers( string message )
{
	foreach ( entity player in GetPlayerArray() )
		thread ActuallySendMessageToPlayers( player, message )
}

void function ActuallySendMessageToPlayers( entity player, string message )
{
	if ( !IsValid( player ) )
		return

	player.EndSignal( "OnDestroy" )

	if ( !( player in file.anotherqueue ) )
		file.anotherqueue[ player ] <- 0

	int queue = file.anotherqueue[ player ]

	if ( !( player in file.anotherrealqueue ) )
		file.anotherrealqueue[ player ] <- 0

	if ( file.anotherrealqueue[ player ] < queue )
		WaitFrame()

	while ( !IsAlive( player ) && player in file.haseverbeenalive && file.haseverbeenalive[ player ] )
		WaitFrame()

	wait 0.1

	file.anotherrealqueue[ player ] += 1

	Chat_ServerPrivateMessage( player, message, false, false )
}

void function EndThreadDiscordToTitanfallBridge( string message, string userid, string messageid )
{
	GetUserNickname( userid )
	userid = GetUserTrueNickname( userid )

	if ( !GetPlayerArray().len() )
		return

	printt( "[DiscordBridge] Messaging Players: [Discord] " + userid + ": " + message )
	SendMessageToPlayers( "[38;2;88;101;242m" + "[Discord] " + userid + ": \x1b[0m" + message )
	GreenCircleDiscordToTitanfallBridge( messageid, file.channelid )
}

void function RedCircleDiscordToTitanfallBridge( string messageid, string channelid )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelid + "/messages/" + messageid + "/reactions/%F0%9F%94%B4/@me"
	request.headers = {
		[ "Authorization" ] = [ "Bot " + file.bottoken ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			printt( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		printt( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function OrangeCircleDiscordToTitanfallBridge( string messageid, string channelid )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelid + "/messages/" + messageid + "/reactions/%F0%9F%9F%A0/@me"
	request.headers = {
		[ "Authorization" ] = [ "Bot " + file.bottoken ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			printt( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		printt( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function GreenCircleDiscordToTitanfallBridge( string messageid, string channelid )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelid + "/messages/" + messageid + "/reactions/%F0%9F%9F%A2/@me"
	request.headers = {
		[ "Authorization" ] = [ "Bot " + file.bottoken ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			printt( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		printt( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function HasEverBeenAlive( entity player )
{
	file.haseverbeenalive[ player ] <- true
}