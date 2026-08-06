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
	string blockedMessageWebhook = ""
	string consoleLogWebhook = ""
	bool crashMessage = false

	string botToken = ""
	string serverId = ""
	string channelId = ""
	string rconChannelId = ""
	string rconUsers = ""
	string lastDiscordMessageId = ";"
	string rconLastDiscordMessageId = ";"
	bool allowBotsRcon = false

	int queue = 0
	int realQueue = 0
	float queueTime = 0

	table<entity, int> anotherQueue
	table<entity, int> anotherRealQueue
	table<string, string> nameList
	table<string, bool> uniqueStringRequestDone

	string logPrints = ""
} file

void function DiscordBridge_Init()
{
	AddCallback_OnReceivedSayTextMessage( LogMessage )
	AddCallback_OnClientConnected( LogJoin )
	AddCallback_OnClientDisconnected( LogDisconnect )
	thread MapChange()

	thread DiscordMessagePoller()
}

void function DiscordBridgeConsoleLog_Init()
{
	file.webhook = GetConVarString( "discordbridge_webhook" )
	file.blockedMessageWebhook = GetConVarString( "discordbridge_blockedmessagewebhook" )
	file.consoleLogWebhook = GetConVarString( "discordbridge_consolelogwebhook" )
	file.crashMessage = GetConVarBool( "discordbridge_shouldsendmessageifservercrashandorrestart" )

	file.botToken = GetConVarString( "discordbridge_bottoken" )
	file.serverId = GetConVarString( "discordbridge_serverid" )
	file.channelId = GetConVarString( "discordbridge_channelid" )
	file.rconChannelId = GetConVarString( "discordbridge_rconchannelid" )
	file.rconUsers = GetConVarString( "discordbridge_rconusers" )
	file.allowBotsRcon = GetConVarBool( "discordbridge_allowbotsrcon" )

	PrintsShowUnixTimestamp( GetConVarBool( "discordbridge_printsshowunixtimestamp" ) )
	PrintsShowInGameTime( GetConVarBool( "discordbridge_printsshowingametime" ) )
	PrintsShowScript( GetConVarBool( "discordbridge_printsshowscript" ) )
	AddPrintHookWithExtraInfo( LogPrints )
	thread LogHandle()
	seterrorhandler( LogServerScriptError )
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

	string playerName = message.player.GetPlayerName()
	int playerTeam = message.player.GetTeam()
	string prefix = ""
	string teamStr = ""
	string communityTag = message.player.GetCommunityClanTag().len() ? "[" + message.player.GetCommunityClanTag() + "] " : ""

	if ( playerTeam == TEAM_IMC )
		teamStr = "IMC"
	else if ( playerTeam == TEAM_MILITIA )
		teamStr = "Militia"
	else
		teamStr = string( playerTeam )

	if ( message.isTeam && GetCurrentPlaylistVarInt( "max_teams", 2 ) == 2 )
		prefix = "[TEAM (" + teamStr + ")] " + ( message.shouldBlock ? "(HIDDEN) " : "" ) + communityTag + playerName
	else
		prefix = "(" + teamStr + ") " + ( message.shouldBlock ? "(HIDDEN) " : "" ) + communityTag + playerName

	MessageQueue()

	SendMessageToDiscord( "**" + prefix + ":** " + msg, ( message.shouldBlock ? file.blockedMessageWebhook : file.webhook ) )

	return message
}

void function LogJoin( entity player )
{
	if ( !IsNewThread() )
	{
		thread LogJoin( player )
		return
	}

	string message = player.GetPlayerName() + "[" + player.GetUID() + "] Has (Re)Connected [Currently Connected Players " + GetPlayerArray().len() + "/" +
		GetCurrentPlaylistVarInt( "max_players", 16 ) + "]"

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

	string playerName = "Unknown"
	string uid = "-1"

	if ( IsValidPlayer( player ) )
	{
		playerName = player.GetPlayerName()
		uid = player.GetUID()
	}

	string message = playerName + "[" + uid + "] Has Disconnected [Currently Connected Players " + ( GetPlayerArray().len() - 1 ) + "/" +
		GetCurrentPlaylistVarInt( "max_players", 16 ) + "]"

	MessageQueue()

	SendMessageToDiscord( "```" + message + "```", file.webhook )
}

void function LogPrints( var text, bool hasNewLine )
{
	string clonedText = expect string( text )

	if ( hasNewLine )
		clonedText = clonedText.slice( 0, clonedText.len() - "\n".len() )

	file.logPrints += file.logPrints.len() ? "\n" + clonedText : clonedText
}

void function LogHandle()
{
	WaitFrame()

	while ( true )
	{
		while ( !file.logPrints.len() )
			WaitFrame()

		wait 0.75

		string logPrints = file.logPrints

		if ( logPrints.len() )
		{
			if ( logPrints.len() >= 1950 )
				logPrints = logPrints.slice( 0, 1950 )

			SendMessageToDiscord( "```" + logPrints + "```", file.consoleLogWebhook )

			file.logPrints = file.logPrints.slice( logPrints.len() )
		}
	}
}

void function LogServerScriptError( string scriptErrorMessage )
{
	string scriptErrorMessageWithScripts = scriptErrorMessage + "\nCALLSTACK"

	int i = 2

	while ( IsValid( getstackinfos( i ) ) )
	{
		table stack = expect table( getstackinfos( i ) )
		scriptErrorMessageWithScripts +=
			"\n*FUNCTION [" + ( "func" in stack ? stack[ "func" ] : "unknown" ) + "()] " + ( "src" in stack ? stack[ "src" ] : "unknown" ) + " line [" +
				( "line" in stack ? stack[ "line" ] : -1 ) + "]"

		i++
	}

	scriptErrorMessageWithScripts += "\n\nLOCALS\n"

	i = 2

	while ( IsValid( getstackinfos( i ) ) )
	{
		table stack = expect table( getstackinfos( i ) )

		foreach ( var key, var value in stack[ "locals" ] )
			scriptErrorMessageWithScripts += "[" + key + "] " + value + "\n"

		i++
	}

	scriptErrorMessageWithScripts += "\nDIAGPRINTS\n\n"

	print( scriptErrorMessageWithScripts )

	bool serverWillExit = GetConVarInt( "fatal_script_errors_server" ) == 1 ||
		( GetConVarBool( "fatal_script_errors" ) && !GetConVarBool( "fatal_script_errors_server" ) )

	SendMessageToDiscord(
		"```SCRIPT ERROR AT UNIX TIME: [" + GetUnixTimestamp() + "] IN GAME TIME: [" + Time() + "] SERVER WILL EXIT = " + serverWillExit + "\n\n" +
			scriptErrorMessageWithScripts + "```",
		file.consoleLogWebhook
	)

	if ( serverWillExit )
	{
		if ( NSIsDedicated() )
			ServerCommand( "exit" )
		else
			NSDisconnectPlayer( GetPlayerArray()[ 0 ], "There was a problem processing game logic.\nPlease try again.\n\nView console for details" )
	}
}

void function SendMessageToDiscord( string message, string webhook )
{
	if ( !webhook.len() )
		return

	table payload = { content = message, allowed_mentions = { parse = [] } }

	HttpRequest request

	request.method = HttpRequestMethod.POST
	request.url = webhook

	if ( !( request.url.len() >= "https://".len() && request.url.slice( 0, "https://".len() ).tolower() == "https://" ) )
		request.url = "https://" + request.url

	request.body = EncodeJSON( payload )
	request.headers = { ["Content-Type"] = [ "application/json" ], ["User-Agent"] = [ "DiscordToTitanfallBridge" ] }

	void functionref( HttpRequestFailure ) onFailure = void function( HttpRequestFailure response )
	{
		printt( "[DiscordBridge] Request Failed: " + response.errorMessage )
	}

	NSHttpRequest( request, null, onFailure )
}

void function MapChange()
{
	MessageQueue()

	string crashMessage = file.crashMessage ? "Server Has Crashed/Restarted\n\n" : ""

	if ( crashMessage.len() )
		SetConVarInt( "discordbridge_shouldsendmessageifservercrashandorrestart", 0 )

	string message = crashMessage + "Map Has Changed To" + ( GetMapName() in MAP_NAME_TABLE ? ( " " + MAP_NAME_TABLE[ GetMapName() ] ) : "" ) + " [" + GetMapName()
		+ "]"

	SendMessageToDiscord( "```" + message + "```", file.webhook )
}

void function MessageQueue()
{
	int queue = file.queue

	file.queue += 1

	while ( file.realQueue < queue || file.queueTime > Time() )
		WaitFrame()

	file.queueTime = Time() + 0.5
	file.realQueue += 1
}

void function DiscordMessagePoller()
{
	WaitFrame()

	if ( !file.botToken.len() || !file.serverId.len() )
		return

	while ( true )
	{
		if ( GetPlayerArray().len() )
		{
			if ( file.channelId.len() )
				PollDiscordMessages()

			if ( file.rconChannelId.len() )
				RconPollDiscordMessages()
		}
		else
		{
			file.lastDiscordMessageId = ";"

			if ( file.rconChannelId.len() )
				RconPollDiscordMessages()
		}

		wait RandomFloatRange( 1.25, 1.5 )
	}
}

void function PollDiscordMessages()
{
	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url =
		"https://discord.com/api/v9/channels/" + file.channelId + "/messages?limit=5" +
			( file.lastDiscordMessageId != ";" ? "&after=" + file.lastDiscordMessageId : "" )
	request.headers = { ["Authorization"] = [ "Bot " + file.botToken ], ["User-Agent"] = [ "DiscordToTitanfallBridge" ] }

	void functionref( HttpRequestResponse ) onSuccess = void function( HttpRequestResponse response )
	{
		thread ThreadDiscordToTitanfallBridge( response )
	}

	void functionref( HttpRequestFailure ) onFailure = void function( HttpRequestFailure response )
	{
		printt( "[DiscordBridge] Request Failed: " + response.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function RconPollDiscordMessages()
{
	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url =
		"https://discord.com/api/v9/channels/" + file.rconChannelId + "/messages?limit=5" +
			( file.rconLastDiscordMessageId != ";" ? "&after=" + file.rconLastDiscordMessageId : "" )
	request.headers = { ["Authorization"] = [ "Bot " + file.botToken ], ["User-Agent"] = [ "DiscordToTitanfallBridge" ] }

	void functionref( HttpRequestResponse ) onSuccess = void function( HttpRequestResponse response )
	{
		thread RconThreadDiscordToTitanfallBridge( response )
	}

	void functionref( HttpRequestFailure ) onFailure = void function( HttpRequestFailure response )
	{
		printt( "[DiscordBridge] Request Failed: " + response.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function ThreadDiscordToTitanfallBridge( HttpRequestResponse response )
{
	if ( response.statusCode == 200 )
	{
		string responseBody = response.body

		responseBody = StringReplace( responseBody, "\"message_reference\"", "\"message_reference\"", true )
		responseBody = StringReplace( responseBody, "},{\"type\"", "},{\"type\"", true )

		array<string> arrayResponse = split( responseBody, "" )
		array<string> fixedResponse = []

		foreach ( string fixResponse in arrayResponse )
			if ( fixResponse.find( "\"message_reference\"" ) == null )
				fixedResponse.append( fixResponse )

		responseBody = ""

		foreach ( string fixResponse in fixedResponse )
			responseBody += fixResponse

		responseBody = StringReplace( responseBody, "\"mention_roles\"", "\"mention_roles\"", true )
		responseBody = StringReplace( responseBody, "\"timestamp\":\"", "\"timestamp\":\"", true )

		arrayResponse = split( responseBody, "" )
		fixedResponse = []

		foreach ( string fixResponse in arrayResponse )
			if ( fixResponse.find( "\"attachments\"" ) == null && fixResponse.find( "\"embeds\"" ) == null )
				fixedResponse.append( fixResponse )

		responseBody = ""

		foreach ( string fixResponse in fixedResponse )
			responseBody += fixResponse

		responseBody = StringReplace( responseBody, "},{\"type\"", "[{", true )

		array<string> newResponse = split( responseBody, "" )

		if ( !newResponse.len() || newResponse[ 0 ].len() <= 3 )
		{
			if ( file.lastDiscordMessageId == ";" )
				file.lastDiscordMessageId = "0"

			return
		}

		string lastMessageId = file.lastDiscordMessageId
		string newestMessageId = ""

		newResponse.reverse()

		int i = 0

		foreach ( string newResponseStr in newResponse )
		{
			if ( !GetPlayerArray().len() )
				return

			i += 1

			responseBody = newResponseStr
			responseBody = StringReplace( responseBody, "\"author\"", "author\"", true )
			responseBody = StringReplace( responseBody, "\"pinned\"", "pinned\"", true )
			responseBody = StringReplace( responseBody, "\"mentions\"", "mentions\"", true )
			responseBody = StringReplace( responseBody, "\"channel_id\"", "channel_id\"", true )

			arrayResponse = split( responseBody, "" )

			if ( arrayResponse.len() != 5 )
			{
				if ( i == newResponse.len() )
				{
					if ( !newestMessageId.len() )
						file.lastDiscordMessageId = "0"
					else
						file.lastDiscordMessageId = newestMessageId
				}

				continue
			}

			string message = arrayResponse[ 0 ]

			message = message.slice( 0, 0 - "\",".len() )

			while ( message.find( ":\"" ) != null )
				message = message.slice( 1 )

			message = message.slice( "\"".len() )
			message = StringReplace( message, "\\\"", "\"", true )
			message = StringReplace( message, "\\\\", "\\", true )

			while ( message.find( "\\u" ) != null )
			{
				var idx = message.find( "\\u" )

				message = message.slice( 0, idx ) + message.slice( idx + 6 )
			}

			while ( message.len() && message.slice( message.len() - 1 ) == " " )
				message = message.slice( 0, message.len() - 1 )

			while ( message.len() && message.slice( 0, 1 - message.len() ) == " " )
				message = message.slice( 1 )

			string userId = arrayResponse[ 3 ]

			while ( userId.find( "\"id\":\"" ) != null )
				userId = userId.slice( 1 )

			userId = userId.slice( "id\":\"".len() )

			while ( userId.find( "\"" ) != null )
				userId = userId.slice( 0, 0 - "\"".len() )

			string messageId = arrayResponse[ 1 ]

			messageId = messageId.slice( 0, 0 - "\",".len() )

			while ( messageId.find( "\"" ) != null )
				messageId = messageId.slice( 1 )

			newestMessageId = messageId

			if ( i == newResponse.len() )
				file.lastDiscordMessageId = newestMessageId

			if ( lastMessageId < newestMessageId && lastMessageId != newestMessageId && arrayResponse[ 3 ].find( "\"bot\"" ) == null )
			{
				if ( message.len() > 200 || !message.len() )
					RedCircleDiscordToTitanfallBridge( messageId, file.channelId )
				else
					thread EndThreadDiscordToTitanfallBridge( message, userId, messageId )

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
		string responseBody = response.body

		responseBody = StringReplace( responseBody, "\"message_reference\"", "\"message_reference\"", true )
		responseBody = StringReplace( responseBody, "},{\"type\"", "},{\"type\"", true )

		array<string> arrayResponse = split( responseBody, "" )
		array<string> fixedResponse = []

		foreach ( string fixResponse in arrayResponse )
			if ( fixResponse.find( "\"message_reference\"" ) == null )
				fixedResponse.append( fixResponse )

		responseBody = ""

		foreach ( string fixResponse in fixedResponse )
			responseBody += fixResponse

		responseBody = StringReplace( responseBody, "\"mention_roles\"", "\"mention_roles\"", true )
		responseBody = StringReplace( responseBody, "\"timestamp\":\"", "\"timestamp\":\"", true )

		arrayResponse = split( responseBody, "" )
		fixedResponse = []

		foreach ( string fixResponse in arrayResponse )
			if ( fixResponse.find( "\"attachments\"" ) == null && fixResponse.find( "\"embeds\"" ) == null )
				fixedResponse.append( fixResponse )

		responseBody = ""

		foreach ( string fixResponse in fixedResponse )
			responseBody += fixResponse

		responseBody = StringReplace( responseBody, "},{\"type\"", "[{", true )

		array<string> newResponse = split( responseBody, "" )

		if ( !newResponse.len() || newResponse[ 0 ].len() <= 3 )
		{
			if ( file.rconLastDiscordMessageId == ";" )
				file.rconLastDiscordMessageId = "0"

			return
		}

		string lastMessageId = file.rconLastDiscordMessageId
		string newestMessageId = ""

		newResponse.reverse()

		int i = 0

		foreach ( string newResponseStr in newResponse )
		{
			i += 1

			responseBody = newResponseStr
			responseBody = StringReplace( responseBody, "\"author\"", "author\"", true )
			responseBody = StringReplace( responseBody, "\"pinned\"", "pinned\"", true )
			responseBody = StringReplace( responseBody, "\"mentions\"", "mentions\"", true )
			responseBody = StringReplace( responseBody, "\"channel_id\"", "channel_id\"", true )

			arrayResponse = split( responseBody, "" )

			if ( arrayResponse.len() != 5 )
			{
				if ( i == newResponse.len() )
				{
					if ( !newestMessageId.len() )
						file.rconLastDiscordMessageId = "0"
					else
						file.rconLastDiscordMessageId = newestMessageId
				}

				continue
			}

			string message = arrayResponse[ 0 ]

			message = message.slice( 0, 0 - "\",".len() )

			while ( message.find( ":\"" ) != null )
				message = message.slice( 1 )

			message = message.slice( "\"".len() )
			message = StringReplace( message, "\\\"", "\"", true )
			message = StringReplace( message, "\\\\", "\\", true )

			while ( message.find( "\\u" ) != null )
			{
				var idx = message.find( "\\u" )

				message = message.slice( 0, idx ) + message.slice( idx + 6 )
			}

			while ( message.len() && message.slice( message.len() - 1 ) == " " )
				message = message.slice( 0, message.len() - 1 )

			while ( message.len() && message.slice( 0, 1 - message.len() ) == " " )
				message = message.slice( 1 )

			string userId = arrayResponse[ 3 ]

			while ( userId.find( "\"id\":\"" ) != null )
				userId = userId.slice( 1 )

			userId = userId.slice( "id\":\"".len() )

			while ( userId.find( "\"" ) != null )
				userId = userId.slice( 0, 0 - "\"".len() )

			string messageId = arrayResponse[ 1 ]

			messageId = messageId.slice( 0, 0 - "\",".len() )

			while ( messageId.find( "\"" ) != null )
				messageId = messageId.slice( 1 )

			newestMessageId = messageId

			if ( i == newResponse.len() )
				file.rconLastDiscordMessageId = newestMessageId

			if ( lastMessageId < newestMessageId && ( arrayResponse[ 3 ].find( "\"bot\"" ) == null || file.allowBotsRcon ) )
			{
				if ( message.len() >= "?rconscript".len() && message.slice( 0, "?rconscript".len() ).tolower() == "?rconscript" )
				{
					array<string> rconUsers = split( file.rconUsers, "," )
					bool shouldRunCommand = false

					for ( int i = 0; i < rconUsers.len(); i++ )
						if ( rconUsers[ i ] == userId )
							shouldRunCommand = true

					if ( shouldRunCommand || !rconUsers.len() )
					{
						printt( "[DiscordBridge] Running Rcon Script Sent By: " + userId + ": " + message )

						try
						{
							thread compilestring( message.slice( "?rconscript ".len() ) )()
							GreenCircleDiscordToTitanfallBridge( messageId, file.rconChannelId )
						}
						catch ( error )
							RedCircleDiscordToTitanfallBridge( messageId, file.rconChannelId )
					}
					else
						OrangeCircleDiscordToTitanfallBridge( messageId, file.rconChannelId )
				}
				else if ( message.len() >= "?rcon".len() && message.slice( 0, "?rcon".len() ).tolower() == "?rcon" )
				{
					array<string> rconUsers = split( file.rconUsers, "," )
					bool shouldRunCommand = false

					for ( int i = 0; i < rconUsers.len(); i++ )
						if ( rconUsers[ i ] == userId )
							shouldRunCommand = true

					if ( shouldRunCommand || !rconUsers.len() )
					{
						GreenCircleDiscordToTitanfallBridge( messageId, file.rconChannelId )
						printt( "[DiscordBridge] Running Rcon Command Sent By: " + userId + ": " + message )
						ServerCommand( message.slice( "?rcon ".len() ) )
					}
					else
						OrangeCircleDiscordToTitanfallBridge( messageId, file.rconChannelId )
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

string function GetUserNicknameRequest( string userId )
{
	string uniquestring = UniqueString()

	file.uniqueStringRequestDone[ uniquestring ] <- false

	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url = "https://discord.com/api/v9/guilds/" + file.serverId + "/members/" + userId
	request.headers = { ["Authorization"] = [ "Bot " + file.botToken ], ["User-Agent"] = [ "DiscordToTitanfallBridge" ] }

	void functionref( HttpRequestResponse ) onSuccess = void function( HttpRequestResponse response ) : ( userId, uniquestring )
	{
		if ( response.statusCode == 200 )
		{
			string responseBody = response.body

			responseBody = StringReplace( responseBody, "\"nick\"", "nick\"", true )
			responseBody = StringReplace( responseBody, "\"pending\"", "pending\"", true )
			responseBody = StringReplace( responseBody, "\"global_name\"", "global_name\"", true )
			responseBody = StringReplace( responseBody, "\"avatar_decoration_data\"", "avatar_decoration_data\"", true )

			array<string> newResponse = split( responseBody, "" )

			string name = newResponse[ 1 ].find( "\"," ) != null ? newResponse[ 1 ].slice( "nick\":\"".len(), 0 - "\",".len() ) : ""

			if ( name.len() )
			{
				while ( name.find( "\\u" ) != null )
				{
					var idx = name.find( "\\u" )

					name = name.slice( 0, idx ) + name.slice( idx + 6 )
				}

				while ( name.len() && name.slice( name.len() - 1 ) == " " )
					name = name.slice( 0, name.len() - 1 )

				while ( name.len() && name.slice( 0, 1 - name.len() ) == " " )
					name = name.slice( 1 )

				name = StringReplace( name, "\\\"", "\"", true )
				name = StringReplace( name, "\\\\", "\\", true )
			}

			if ( !name.len() && newResponse[ 3 ].find( "global_name" ) != null )
			{
				name = newResponse[ 3 ].slice( "global_name\":\"".len(), 0 - "\",".len() )

				while ( name.find( "\\u" ) != null )
				{
					var idx = name.find( "\\u" )

					name = name.slice( 0, idx ) + name.slice( idx + 6 )
				}

				while ( name.len() && name.slice( name.len() - 1 ) == " " )
					name = name.slice( 0, name.len() - 1 )

				while ( name.len() && name.slice( 0, 1 - name.len() ) == " " )
					name = name.slice( 1 )

				name = StringReplace( name, "\\\"", "\"", true )
				name = StringReplace( name, "\\\\", "\\", true )
			}

			if ( !name.len() )
			{
				name = newResponse[ 2 ]

				while ( name.find( "\",\"avatar\"" ) != null )
					name = name.slice( 0, -1 )

				name = name.slice( 0, 0 - "\",\"avatar".len() )

				while ( name.find( "\"" ) != null )
					name = name.slice( "\"".len() )
			}

			file.nameList[ userId ] <- name

			if ( uniquestring in file.uniqueStringRequestDone )
				file.uniqueStringRequestDone[ uniquestring ] <- true
		}
		else
		{
			printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			printt( "[DiscordBridge] Response Body: " + response.body )

			if ( uniquestring in file.uniqueStringRequestDone )
				file.uniqueStringRequestDone[ uniquestring ] <- true
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function( HttpRequestFailure response ) : ( uniquestring )
	{
		printt( "[DiscordBridge] Request Failed: " + response.errorMessage )

		if ( uniquestring in file.uniqueStringRequestDone )
			file.uniqueStringRequestDone[ uniquestring ] <- true
	}

	NSHttpRequest( request, onSuccess, onFailure )

	return uniquestring
}

string function GetUserNickname( string userId )
{
	string uniquestring = GetUserNicknameRequest( userId )
	float timeOut = Time() + 0.75

	while ( !file.uniqueStringRequestDone[ uniquestring ] && Time() < timeOut )
		WaitFrame()

	delete file.uniqueStringRequestDone[ uniquestring ]

	if ( userId in file.nameList )
		return file.nameList[ userId ]

	return "Unknown"
}

void function SendMessageToPlayers( string message )
{
	foreach ( entity player in GetPlayerArray() )
		thread SendMessageToPlayer( player, message )
}

void function SendMessageToPlayer( entity player, string message )
{
	if ( !IsValid( player ) )
		return

	player.EndSignal( "OnDestroy" )

	if ( !( player in file.anotherQueue ) )
		file.anotherQueue[ player ] <- 0

	int queue = file.anotherQueue[ player ]

	if ( !( player in file.anotherRealQueue ) )
		file.anotherRealQueue[ player ] <- 0

	if ( file.anotherRealQueue[ player ] < queue )
		WaitFrame()

	while ( player.IsWatchingKillReplay() )
		WaitFrame()

	WaitFrame()

	file.anotherRealQueue[ player ] += 1

	Chat_ServerPrivateMessage( player, message, false, false )
}

void function EndThreadDiscordToTitanfallBridge( string message, string userId, string messageId )
{
	string name = GetUserNickname( userId )

	if ( !GetPlayerArray().len() )
		return

	string noNewLineMessage = StringReplace( message, "\\n", " ", true )

	printt( "[DiscordBridge] Messaging Players: [Discord] " + name + ": " + noNewLineMessage )
	SendMessageToPlayers( "[38;2;88;101;242m" + "[Discord] " + name + ": \x1b[0m" + noNewLineMessage )
	GreenCircleDiscordToTitanfallBridge( messageId, file.channelId )
}

void function RedCircleDiscordToTitanfallBridge( string messageId, string channelId )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelId + "/messages/" + messageId + "/reactions/%F0%9F%94%B4/@me"
	request.headers = { ["Authorization"] = [ "Bot " + file.botToken ], ["User-Agent"] = [ "DiscordToTitanfallBridge" ] }

	void functionref( HttpRequestResponse ) onSuccess = void function( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			printt( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function( HttpRequestFailure response )
	{
		printt( "[DiscordBridge] Request Failed: " + response.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function OrangeCircleDiscordToTitanfallBridge( string messageId, string channelId )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelId + "/messages/" + messageId + "/reactions/%F0%9F%9F%A0/@me"
	request.headers = { ["Authorization"] = [ "Bot " + file.botToken ], ["User-Agent"] = [ "DiscordToTitanfallBridge" ] }

	void functionref( HttpRequestResponse ) onSuccess = void function( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			printt( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function( HttpRequestFailure response )
	{
		printt( "[DiscordBridge] Request Failed: " + response.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function GreenCircleDiscordToTitanfallBridge( string messageId, string channelId )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelId + "/messages/" + messageId + "/reactions/%F0%9F%9F%A2/@me"
	request.headers = { ["Authorization"] = [ "Bot " + file.botToken ], ["User-Agent"] = [ "DiscordToTitanfallBridge" ] }

	void functionref( HttpRequestResponse ) onSuccess = void function( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			printt( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			printt( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function( HttpRequestFailure response )
	{
		printt( "[DiscordBridge] Request Failed: " + response.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}
