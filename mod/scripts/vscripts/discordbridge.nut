untyped

global function DiscordBridge_Init

void function DiscordBridge_Init()
{
	AddCallback_OnReceivedSayTextMessage( LogMessage )
	AddCallback_OnClientConnected( LogJoin )
	AddCallback_OnClientDisconnected( LogDisconnect )
	thread MapChange()

	AddCallback_OnPlayerRespawned( HasEverBeenAlive )
	thread DiscordMessagePoller()
}

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
	int queue = 0
	int realqueue = 0
	float queuetime = 0

	table<entity, int> anotherqueue
	table<entity, int> anotherrealqueue
	table<entity, bool> haseverbeenalive
	table<string, string> namelist
} file

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

	string console_message = prefix + ": " + msg

	SendMessageToDiscord( console_message, false )

	string discord_message = "**" + prefix + ":** " + msg

	SendMessageToDiscord( discord_message, true, false, message.shouldBlock )

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

	SendMessageToDiscord( message, false )

	message = "```" + message + "```"

	SendMessageToDiscord( message, true, false )
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

	SendMessageToDiscord( message, false )

	message = "```" + message + "```"

	SendMessageToDiscord( message, true, false )
}

void function SendMessageToDiscord( string message, bool sendmessage = true, bool printmessage = true, bool blockedmessage = false )
{
	if ( !GetConVarString( "discordbridge_webhook" ).len() )
		return

	if ( printmessage )
		print( "[DiscordBridge] Messaging Discord Users: " + message )

	if ( !sendmessage )
		return

	table payload = {
		content = message
		allowed_mentions = {
			parse = []
		}
	}

	HttpRequest request

	request.method = HttpRequestMethod.POST
	request.url = GetConVarString( "discordbridge_webhook" )

	if ( blockedmessage && GetConVarString( "discordbridge_commandlogwebhook" ).len() )
		request.url = GetConVarString( "discordbridge_commandlogwebhook" )

	if ( !( request.url.len() >= "https://".len() && request.url.slice( 0, "https://".len() ).tolower() == "https://" ) )
		request.url = "https://" + request.url

	request.body = EncodeJSON( payload )
	request.headers = {
		[ "Content-Type" ] = [ "application/json" ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	NSHttpRequest( request )
}

void function MapChange()
{
	MessageQueue()

	string crashmessage = GetConVarInt( "discordbridge_shouldsendmessageifservercrashandorrestart" ) ? "Server Has Crashed/Restarted\n\n" : ""

	if ( crashmessage.len() )
		SetConVarInt( "discordbridge_shouldsendmessageifservercrashandorrestart", 0 )

	string message = crashmessage + "Map Has Changed To" + ( GetMapName() in MAP_NAME_TABLE ? ( " " + MAP_NAME_TABLE[ GetMapName() ] ) : "" ) + " [" + GetMapName() + "]"

	SendMessageToDiscord( message, false )

	message = "```" + message + "```"

	SendMessageToDiscord( message, true, false )
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

string last_discord_timestamp = ";"
string rconlast_discord_timestamp = ";"

void function DiscordMessagePoller()
{
	WaitFrame()

	while ( true )
	{
		if ( GetPlayerArray().len() )
		{
			if ( GetConVarString( "discordbridge_bottoken" ).len() && GetConVarString( "discordbridge_serverid" ).len() )
			{
				if ( GetConVarString( "discordbridge_channelid" ).len() )
					PollDiscordMessages()

				if ( GetConVarString( "discordbridge_rconchannelid" ).len() )
					RconPollDiscordMessages()
			}
		}
		else
		{
			last_discord_timestamp = ";"

			if ( GetConVarString( "discordbridge_bottoken" ).len() && GetConVarString( "discordbridge_serverid" ).len() && GetConVarString( "discordbridge_rconchannelid" ).len() )
				RconPollDiscordMessages()
		}

		wait RandomFloatRange( 1.25, 1.5 )
	}
}

void function PollDiscordMessages()
{
	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url = "https://discord.com/api/v9/channels/" + GetConVarString( "discordbridge_channelid" ) + "/messages?limit=5"
	request.headers = {
		[ "Authorization" ] = [ "Bot " + GetConVarString( "discordbridge_bottoken" ) ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		thread ThreadDiscordToTitanfallBridge( response )
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		print( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function RconPollDiscordMessages()
{
	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url = "https://discord.com/api/v9/channels/" + GetConVarString( "discordbridge_rconchannelid" ) + "/messages?limit=5"
	request.headers = {
		[ "Authorization" ] = [ "Bot " + GetConVarString( "discordbridge_bottoken" ) ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		thread RconThreadDiscordToTitanfallBridge( response )
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		print( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function ThreadDiscordToTitanfallBridge( HttpRequestResponse response )
{
	if ( response.statusCode == 200 )
	{
		string responsebody = response.body

		responsebody = StringReplace( responsebody, "\"message_reference\"", "\"message_reference\"", true )
		responsebody = StringReplace( responsebody, "\"mention_roles\"", "\"mention_roles\"", true )
		responsebody = StringReplace( responsebody, "\"timestamp\":\"", "\"timestamp\":\"", true )

		array<string> arrayresponse = split( responsebody, "" )
		array<string> fixedresponse = []

		for ( int i = 0; i < arrayresponse.len(); i++ )
			if ( arrayresponse[i].find( "\"message_reference\"" ) == null && arrayresponse[i].find( "\"attachments\"" ) == null && arrayresponse[i].find( "\"embeds\"" ) == null )
				fixedresponse.append( arrayresponse[i] )

		responsebody = ""

		for ( int i = 0; i < fixedresponse.len(); i++ )
			responsebody += fixedresponse[i]

		responsebody = StringReplace( responsebody, "},{\"type\"", "[{", true )

		array<string> newresponse = split( responsebody, "" )

		if ( !newresponse.len() || !newresponse[0].len() )
			return

		string timestamp = last_discord_timestamp
		string newesttimestamp = ""

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
			responsebody = StringReplace( responsebody, "timestamp\":\"", "timestamp\":", true )
			responsebody = StringReplace( responsebody, "\",\"edited_timestamp\"", ",\"edited_timestamp\"", true )

			array<string> arrayresponse = split( responsebody, "" )

			if ( arrayresponse.len() != 7 && i == newresponse.len() && GetPlayerArray().len() )
			{
				if ( !newesttimestamp.len() )
					last_discord_timestamp = "/"
				else
					last_discord_timestamp = newesttimestamp
				
				continue
			}

			string meow = arrayresponse[0]

			meow = meow.slice( 0, -2 )

			while ( meow.find( ":\"" ) )
				meow = meow.slice( 1 )

			meow = meow.slice( 2 )
			meow = StringReplace( meow, "\\\"", "\"", true )
			meow = StringReplace( meow, "\\\\", "\\", true )

			string meower = arrayresponse[5]

			meower = meower.slice( 15 )

			while ( meower.find( "\"" ) )
				meower = meower.slice( 0, -1 )

			string meowest = arrayresponse[3]

			meowest = meowest.slice( 0, -2 )

			while ( meowest.find( "id" ) )
				meowest = meowest.slice( 1 )

			meowest = meowest.slice( 5 )
			newesttimestamp = arrayresponse[2]

			if ( i == newresponse.len() && GetPlayerArray().len() )
				last_discord_timestamp = newesttimestamp

			if ( timestamp < arrayresponse[2] && arrayresponse[5].find( "\"bot\"" ) == null )
			{
				if ( meow.len() > 200 || meow.len() <= 0 )
					RedCircleDiscordToTitanfallBridge( meowest, GetConVarString( "discordbridge_channelid" ) )
				else
					thread EndThreadDiscordToTitanfallBridge( meow, meower, meowest )

				wait 0.25
			}
		}
	}
	else
	{
		print( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
		print( "[DiscordBridge] Response Body: " + response.body )
	}
}

void function RconThreadDiscordToTitanfallBridge( HttpRequestResponse response )
{
	if ( response.statusCode == 200 )
	{
		string responsebody = response.body

		responsebody = StringReplace( responsebody, "\"message_reference\"", "\"message_reference\"", true )
		responsebody = StringReplace( responsebody, "\"mention_roles\"", "\"mention_roles\"", true )
		responsebody = StringReplace( responsebody, "\"timestamp\":\"", "\"timestamp\":\"", true )

		array<string> arrayresponse = split( responsebody, "" )
		array<string> fixedresponse = []

		for ( int i = 0; i < arrayresponse.len(); i++ )
			if ( arrayresponse[i].find( "\"message_reference\"" ) == null && arrayresponse[i].find( "\"attachments\"" ) == null && arrayresponse[i].find( "\"embeds\"" ) == null )
				fixedresponse.append( arrayresponse[i] )

		responsebody = ""

		for ( int i = 0; i < fixedresponse.len(); i++ )
			responsebody += fixedresponse[i]

		responsebody = StringReplace( responsebody, "},{\"type\"", "[{", true )

		array<string> newresponse = split( responsebody, "" )

		if ( !newresponse.len() || !newresponse[0].len() )
			return

		string timestamp = rconlast_discord_timestamp
		string newesttimestamp = ""

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
			responsebody = StringReplace( responsebody, "timestamp\":\"", "timestamp\":", true )
			responsebody = StringReplace( responsebody, "\",\"edited_timestamp\"", ",\"edited_timestamp\"", true )

			array<string> arrayresponse = split( responsebody, "" )

			if ( arrayresponse.len() != 7 && i == newresponse.len() )
			{
				if ( !newesttimestamp.len() )
					rconlast_discord_timestamp = "/"
				else
					rconlast_discord_timestamp = newesttimestamp
				
				continue
			}

				string meow = arrayresponse[0]

				meow = meow.slice( 0, -2 )

				while ( meow.find( ":\"" ) )
					meow = meow.slice( 1 )

				meow = meow.slice( 2 )
				meow = StringReplace( meow, "\\\"", "\"", true )
				meow = StringReplace( meow, "\\\\", "\\", true )

				string meower = arrayresponse[5]

				meower = meower.slice( 15 )

				while ( meower.find( "\"" ) )
					meower = meower.slice( 0, -1 )

				string meowest = arrayresponse[3]

				meowest = meowest.slice( 0, -2 )

				while ( meowest.find( "id" ) )
					meowest = meowest.slice( 1 )

				meowest = meowest.slice( 5 )

				newesttimestamp = arrayresponse[2]

				if ( i == newresponse.len() )
					rconlast_discord_timestamp = newesttimestamp

				if ( timestamp < arrayresponse[2] && ( arrayresponse[5].find( "\"bot\"" ) == null || GetConVarInt( "discordbridge_allowbotsrcon" ) ) )
				{
					if ( meow.len() >= "?rconscript".len() && meow.slice( 0, "?rconscript".len() ).tolower() == "?rconscript" )
					{
						array<string> rconusers = split( GetConVarString( "discordbridge_rconusers" ), "," )

						bool shouldruncommand = false

						for ( int i = 0; i < rconusers.len(); i++ )
							if ( rconusers[i] == meower )
								shouldruncommand = true

						if ( shouldruncommand || !rconusers.len() )
						{
							print( "[DiscordBridge] Running Rcon Script Sent By: " + meower + ": " + meow )

							try
							{
								thread compilestring( meow.slice( 11 ) )()
								GreenCircleDiscordToTitanfallBridge( meowest, GetConVarString( "discordbridge_rconchannelid" ) )
							}
							catch ( error )
								RedCircleDiscordToTitanfallBridge( meowest, GetConVarString( "discordbridge_rconchannelid" ) )
						}
						else
							OrangeCircleDiscordToTitanfallBridge( meowest, GetConVarString( "discordbridge_rconchannelid" ) )
					}
					else if ( meow.len() >= "?rcon".len() && meow.slice( 0, "?rcon".len() ).tolower() == "?rcon" )
					{
						array<string> rconusers = split( GetConVarString( "discordbridge_rconusers" ), "," )

						bool shouldruncommand = false

						for ( int i = 0; i < rconusers.len(); i++ )
							if ( rconusers[i] == meower )
								shouldruncommand = true

						if ( shouldruncommand || !rconusers.len() )
						{
							GreenCircleDiscordToTitanfallBridge( meowest, GetConVarString( "discordbridge_rconchannelid" ) )
							print( "[DiscordBridge] Running Rcon Command Sent By: " + meower + ": " + meow )
							ServerCommand( meow.slice( 5 ) )
						}
						else
							OrangeCircleDiscordToTitanfallBridge( meowest, GetConVarString( "discordbridge_rconchannelid" ) )
					}

					wait 0.25
				}
		}
	}
	else
	{
		print( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
		print( "[DiscordBridge] Response Body: " + response.body )
	}
}

void function GetUserNickname( string userid )
{
	HttpRequest request

	request.method = HttpRequestMethod.GET
	request.url = "https://discord.com/api/v9/guilds/" + GetConVarString( "discordbridge_serverid" ) + "/members/" + userid
	request.headers = {
		[ "Authorization" ] = [ "Bot " + GetConVarString( "discordbridge_bottoken" ) ],
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

			string meow = newresponse[1]

			meow = StringReplace( meow, "nick\":", "" )

			if ( meow.find( "\"," ) )
				file.namelist[ userid ] <- meow.slice( 1, -2 )
			else if ( newresponse[3].find( "name" ) )
				file.namelist[ userid ] <- newresponse[3].slice( 14, -2 )
		}
		else
		{
			print( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			print( "[DiscordBridge] Response Body: " + response.body )
		}
	}
	
	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		print( "[DiscordBridge] Request Failed: " + failure.errorMessage )
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
	for ( int i = 0; i < GetPlayerArray().len(); i++ )
		thread ActuallySendMessageToPlayers( GetPlayerArray()[i], message )
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

void function EndThreadDiscordToTitanfallBridge( string meow, string meower, string meowest )
{
	GetUserNickname( meower )
	meower = GetUserTrueNickname( meower )

	print( "[DiscordBridge] Messaging Players: [Discord] " + meower + ": " + meow )
	SendMessageToPlayers( "[38;2;88;101;242m" + "[Discord] " + meower + ": \x1b[0m" + meow )
	GreenCircleDiscordToTitanfallBridge( meowest, GetConVarString( "discordbridge_channelid" ) )
}

void function RedCircleDiscordToTitanfallBridge( string meowest, string channelid )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelid + "/messages/" + meowest + "/reactions/%F0%9F%94%B4/@me"
	request.headers = {
		[ "Authorization" ] = [ "Bot " + GetConVarString( "discordbridge_bottoken" ) ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			print( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			print( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		print( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function OrangeCircleDiscordToTitanfallBridge( string meowest, string channelid )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelid + "/messages/" + meowest + "/reactions/%F0%9F%9F%A0/@me"
	request.headers = {
		[ "Authorization" ] = [ "Bot " + GetConVarString( "discordbridge_bottoken" ) ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			print( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			print( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		print( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function GreenCircleDiscordToTitanfallBridge( string meowest, string channelid )
{
	HttpRequest request

	request.method = HttpRequestMethod.PUT
	request.url = "https://discord.com/api/v9/channels/" + channelid + "/messages/" + meowest + "/reactions/%F0%9F%9F%A2/@me"
	request.headers = {
		[ "Authorization" ] = [ "Bot " + GetConVarString( "discordbridge_bottoken" ) ],
		[ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
	}

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
	{
		if ( response.statusCode != 204 )
		{
			print( "[DiscordBridge] Request Failed With Status: " + response.statusCode.tostring() )
			print( "[DiscordBridge] Response Body: " + response.body )
		}
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
	{
		print( "[DiscordBridge] Request Failed: " + failure.errorMessage )
	}

	NSHttpRequest( request, onSuccess, onFailure )
}

void function HasEverBeenAlive( entity player )
{
	file.haseverbeenalive[ player ] <- true
}