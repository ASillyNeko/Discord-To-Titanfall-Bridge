[Discord Server](https://ds.asillyneko.dev)

# Titanfall To Discord

Remove (https://) From Webhook Url Otherwise It'll Just Be (https://)

Make A Webhook By Hovering Over The Channel And Clicking On (Edit Channel) And Going To (Integrations) Then Click On (Webhooks)

Copy The Webhook Url By Clicking On (Copy Webhook URL)

Required To Send Messages To Discord

`discordbridge_webhook`

Sends Messages That `discordbridge_webhook` Didn't Send

`discordbridge_commandlogwebhook`

Sends ```Server Has Crashed And Or Restarted``` To `discordbridge_webhook` On Startup

`discordbridge_shouldsendmessageifservercrashandorrestart` Set To 0 To Disable


# Discord To Titanfall

Activate Developer Mode At (User Settings/Advanced)

Get `discordbridge_bottoken` By Making A Bot [Here](https://discord.com/developers/applications)

Get Channel Ids By Right Clicking On The Channel And Clicking On (Copy Channel ID) Need Developer Mode

Get Server Id By Right Clicking On The Server's Icon And Clicking On (Copy Channel ID) Need Developer Mode

Bot Needs "Send Messages", "Add Reactions", "Read Message History", and "View Channel" Permissions To `discordbridge_channelid` And `discordbridge_rconchannelid` If Set

Required To Connect To Discord

`discordbridge_bottoken`

Required To Get Messages

`discordbridge_channelid`

Required To Get Discord Names

`discordbridge_serverid`

Rcon Requires `discordbridge_bottoken` 🟠 Means Not Allowed, 🔴 Means Allowed And Failed To Run, And 🟢 Means Allowed And Ran

Example Value "402550402140340224" Or "402550402140340224,1415868227170336808" Leaving Empty Will Allow Everyone To Run Rcon Commands

`discordbridge_rconusers`

Adds `?rcon` And `?rconscript` Commands

`discordbridge_rconchannelid`

Allows Discord Bots To Run Rcon Commands

`discordbridge_allowbotsrcon`