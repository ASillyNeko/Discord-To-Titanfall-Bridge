[Discord Server](https://ds.asillyneko.dev)

# Random Things

Prints show unix timestamp

`discordbridge_printsshowunixtimestamp`

Prints show in game time

`discordbridge_printsshowingametime`

Shows The Script Of Prints

`discordbridge_printsshowscript`

# Titanfall To Discord

Make a webhook by hovering over the channel and clicking on (Edit Channel) and going to (Integrations) then click on (Webhooks)

Copy the webhook url by clicking on (Copy Webhook URL)

Required to send messages to discord

`discordbridge_webhook`

Sends messages that `discordbridge_webhook` didn't send

`discordbridge_blockedmessagewebhook`

Logs **SOME** server script prints and server script errors

`discordbridge_consolelogwebhook`

Sends ```Server Has Crashed And Or Restarted``` to `discordbridge_webhook` on startup

`discordbridge_shouldsendmessageifservercrashandorrestart` set to 0 to disable


# Discord To Titanfall

Activate developer mode at (User Settings/Advanced)

Get `discordbridge_bottoken` by making a bot [Here](https://discord.com/developers/applications)

Get channel id by right clicking on the channel and clicking on (Copy Channel ID) needs developer mode

Get server id by right clicking on the server's icon and clicking on (Copy Channel ID) needs developer mode

Bot needs "Add Reactions", "Read Message History", and "View Channel" permissions to `discordbridge_channelid` and `discordbridge_rconchannelid` if set

Required to connect to discord

`discordbridge_bottoken`

Required to get messages

`discordbridge_channelid`

Required to get discord names

`discordbridge_serverid`

Rcon requires `discordbridge_bottoken` 🟠 means not allowed, 🔴 Means allowed and failed to run, and 🟢 means allowed and successfully run

Example value "402550402140340224" or "402550402140340224,1415868227170336808" leaving it empty will allow everyone with access to `discordbridge_rconchannelid` to run rcon commands

`discordbridge_rconusers`

Channel with ability to run `?rcon` and `?rconscript`

`discordbridge_rconchannelid`

Allows discord bots to run rcon commands

`discordbridge_allowbotsrcon`
