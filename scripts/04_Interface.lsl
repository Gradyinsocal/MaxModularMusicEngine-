///////////////////////////////////////////////////////////////
//
// Max Modular Music Engine
//
// File:
// 04_Interface.lsl
//
// Version:
// 1.01
//
// Build:
// 3B Developer Preview 2
//
///////////////////////////////////////////////////////////////


//==============================================================
// API
//==============================================================

// Playback Engine

integer API_ENGINE_PLAY      = 2100;
integer API_ENGINE_STOP      = 2101;


// Library

integer API_DB_REQUEST       = 2000;
integer API_DB_REPLY         = 2001;


// Interface

integer API_IF_STATE         = 3000;
integer API_IF_NOWPLAYING    = 3001;


//==============================================================
// Library Commands
//==============================================================

string CMD_LIST_SONGS = "LIST_SONGS";
string CMD_SONG_COUNT = "SONG_COUNT";


//==============================================================
// Dialog Buttons
//==============================================================

string BTN_PLAY   = "▶ Play";
string BTN_STOP   = "■ Stop";
string BTN_SONGS  = "🎵 Songs";
string BTN_VOLUME = "🔊 Volume";

string BTN_BACK   = "Back";
string BTN_CLOSE  = "Close";

string BTN_NEXT   = "Next ▶";
string BTN_PREV   = "◀ Prev";


//==============================================================
// Menu States
//==============================================================

integer MENU_MAIN   = 0;
integer MENU_SONGS  = 1;
integer MENU_VOLUME = 2;

integer gMenu = MENU_MAIN;


//==============================================================
// Dialog
//==============================================================

integer gChannel;
integer gListen;


//==============================================================
// Playback Status
//==============================================================

integer gState = 0;

string gSong = "No Song";
string gArtist = "";


//==============================================================
// Song Cache
//
// Current Library Format:
//
// SongID
// Song Title
//
// Each song occupies TWO entries.
//
// Record Size = 2
//==============================================================

integer SONG_RECORD = 2;

list gLibrary = [];

integer gSongCount = 0;

integer gSongPage = 0;

integer BUTTONS_PER_PAGE = 9;


//==============================================================
// Library Helper Functions
//==============================================================

integer SongOffset(integer song)
{
    return song * SONG_RECORD;
}

string SongID(integer song)
{
    return llList2String(
        gLibrary,
        SongOffset(song));
}

string SongTitle(integer song)
{
    return llList2String(
        gLibrary,
        SongOffset(song) + 1);
}


//==============================================================
// Dialog Support
//==============================================================

OpenDialog(key id)
{
    if(gListen)
        llListenRemove(gListen);

    gChannel =
        -1 - (integer)llFrand(2000000000.0);

    gListen =
        llListen(
            gChannel,
            "",
            id,
            "");
}


//==============================================================
// Library Requests
//==============================================================

RequestSongList()
{
    llMessageLinked(
        LINK_SET,
        API_DB_REQUEST,
        CMD_LIST_SONGS,
        NULL_KEY);
}

RequestSongCount()
{
    llMessageLinked(
        LINK_SET,
        API_DB_REQUEST,
        CMD_SONG_COUNT,
        NULL_KEY);
}
//==============================================================
// MAIN MENU
//==============================================================

ShowMain(key id)
{
    gMenu = MENU_MAIN;

    OpenDialog(id);

    list buttons =
    [
        BTN_PLAY,
        BTN_STOP,
        BTN_SONGS,
        BTN_VOLUME,
        BTN_CLOSE
    ];

    string text =
        "Max Modular Music Engine\n\n"
        + "Now Playing\n\n"
        + gSong;

    if(gArtist != "")
        text += "\n" + gArtist;

    llDialog(
        id,
        text,
        buttons,
        gChannel);
}



//==============================================================
// VOLUME MENU
//==============================================================

ShowVolume(key id)
{
    gMenu = MENU_VOLUME;

    OpenDialog(id);

    list buttons =
    [
        "100%",
        "80%",
        "60%",
        "40%",
        "20%",
        "Mute",
        BTN_BACK
    ];

    llDialog(
        id,
        "Volume Control\n\n(Playback support coming soon)",
        buttons,
        gChannel);
}



//==============================================================
// SONG BROWSER
//==============================================================

ShowSongs(key id)
{
    gMenu = MENU_SONGS;

    OpenDialog(id);

    //----------------------------------------------------------
    // No cached songs?
    //----------------------------------------------------------

    if(gSongCount == 0)
    {
        RequestSongList();

        llDialog(
            id,
            "The music library is loading.\n\nPlease open Songs again in a moment.",
            [BTN_BACK],
            gChannel);

        return;
    }

    integer start = gSongPage * BUTTONS_PER_PAGE;
    integer end = start + BUTTONS_PER_PAGE - 1;

    if(end >= gSongCount)
        end = gSongCount - 1;

    list buttons = [];

    integer i;

    for(i = start; i <= end; ++i)
    {
        buttons += [ SongTitle(i) ];
    }

    //----------------------------------------------------------
    // Navigation
    //----------------------------------------------------------

    if(gSongPage > 0)
        buttons += [BTN_PREV];

    if(end < (gSongCount - 1))
        buttons += [BTN_NEXT];

    buttons += [BTN_BACK];

    string text =
        "Songs\n\n"
        + "Showing "
        + (string)(start + 1)
        + " - "
        + (string)(end + 1)
        + " of "
        + (string)gSongCount;

    llDialog(
        id,
        text,
        buttons,
        gChannel);
}
//==============================================================
// MAIN MENU HANDLER
//==============================================================

HandleMainMenu(key id, string msg)
{
    if(msg == BTN_PLAY)
    {
        llMessageLinked(
            LINK_SET,
            API_ENGINE_PLAY,
            "",
            id);

        ShowMain(id);
        return;
    }

    if(msg == BTN_STOP)
    {
        llMessageLinked(
            LINK_SET,
            API_ENGINE_STOP,
            "",
            id);

        ShowMain(id);
        return;
    }

    if(msg == BTN_SONGS)
    {
        ShowSongs(id);
        return;
    }

    if(msg == BTN_VOLUME)
    {
        ShowVolume(id);
        return;
    }

    if(msg == BTN_CLOSE)
    {
        if(gListen)
        {
            llListenRemove(gListen);
            gListen = 0;
        }

        return;
    }
}



//==============================================================
// VOLUME MENU HANDLER
//==============================================================

HandleVolumeMenu(key id, string msg)
{
    if(msg == BTN_BACK)
    {
        ShowMain(id);
        return;
    }

    //----------------------------------------------------------
    // Placeholder for future playback volume support
    //----------------------------------------------------------

    llOwnerSay("[MMME] Volume selected: " + msg);

    ShowVolume(id);
}



//==============================================================
// SONG MENU HANDLER
//==============================================================

HandleSongMenu(key id, string msg)
{
    //----------------------------------------------------------
    // Back
    //----------------------------------------------------------

    if(msg == BTN_BACK)
    {
        ShowMain(id);
        return;
    }

    //----------------------------------------------------------
    // Next Page
    //----------------------------------------------------------

    if(msg == BTN_NEXT)
    {
        ++gSongPage;
        ShowSongs(id);
        return;
    }

    //----------------------------------------------------------
    // Previous Page
    //----------------------------------------------------------

    if(msg == BTN_PREV)
    {
        if(gSongPage > 0)
            --gSongPage;

        ShowSongs(id);
        return;
    }

    //----------------------------------------------------------
    // Song Selection
    //----------------------------------------------------------

    integer i;

    for(i = 0; i < gSongCount; ++i)
    {
        if(msg == SongTitle(i))
        {
            // Playback integration comes in
            // MainEngine Developer Preview 2.

            llOwnerSay(
                "[MMME] Selected Song "
                + SongID(i)
                + " : "
                + SongTitle(i));

            ShowMain(id);
            return;
        }
    }

    //----------------------------------------------------------
    // Unknown selection
    //----------------------------------------------------------

    ShowSongs(id);
}



//==============================================================
// LISTEN DISPATCHER
//==============================================================

HandleListen(
    key id,
    string msg)
{
    if(gMenu == MENU_MAIN)
    {
        HandleMainMenu(id,msg);
        return;
    }

    if(gMenu == MENU_VOLUME)
    {
        HandleVolumeMenu(id,msg);
        return;
    }

    if(gMenu == MENU_SONGS)
    {
        HandleSongMenu(id,msg);
        return;
    }
}
//==============================================================
// LIBRARY CACHE
//==============================================================

CacheSongList(string message)
{
    gLibrary = [];
    gSongCount = 0;

    //----------------------------------------------------------
    // Remove "SONG_LIST|"
    //----------------------------------------------------------

    list records =
        llParseStringKeepNulls(
            message,
            ["|"],
            []);

    integer i;

    for(i = 1; i < llGetListLength(records); ++i)
    {
        string record =
            llList2String(records,i);

        list fields =
            llParseStringKeepNulls(
                record,
                ["="],
                []);

        if(llGetListLength(fields) >= 2)
        {
            gLibrary +=
            [
                llList2String(fields,0),   // SongID
                llList2String(fields,1)    // Title
            ];

            ++gSongCount;
        }
    }
}



//==============================================================
// LINK MESSAGE HANDLER
//==============================================================

HandleLinkMessage(
    integer num,
    string message)
{
    //----------------------------------------------------------
    // Playback State
    //----------------------------------------------------------

    if(num == API_IF_STATE)
    {
        gState = (integer)message;
        return;
    }

    //----------------------------------------------------------
    // Now Playing
    //----------------------------------------------------------

    if(num == API_IF_NOWPLAYING)
    {
        list p =
            llParseStringKeepNulls(
                message,
                ["|"],
                []);

        if(llGetListLength(p) >= 2)
        {
            gSong =
                llList2String(p,0);

            gArtist =
                llList2String(p,1);
        }

        return;
    }

    //----------------------------------------------------------
    // Library Reply
    //----------------------------------------------------------

    if(num == API_DB_REPLY)
    {
        if(llSubStringIndex(
            message,
            "SONG_LIST|") == 0)
        {
            CacheSongList(message);
            return;
        }

        if(llSubStringIndex(
            message,
            "SONG_COUNT|") == 0)
        {
            gSongCount =
                (integer)llGetSubString(
                    message,
                    11,
                    -1);

            return;
        }
    }
}
//==============================================================
// DEFAULT STATE
//==============================================================

default
{
    //----------------------------------------------------------
    // STARTUP
    //----------------------------------------------------------

    state_entry()
    {
        gMenu = MENU_MAIN;
        gSongPage = 0;

        RequestSongList();
        RequestSongCount();
    }


    //----------------------------------------------------------
    // OWNER TOUCH
    //----------------------------------------------------------

    touch_start(integer total)
    {
        key id = llDetectedKey(0);

        if(id != llGetOwner())
            return;

        ShowMain(id);
    }


    //----------------------------------------------------------
    // DIALOG LISTENER
    //----------------------------------------------------------

    listen(
        integer channel,
        string name,
        key id,
        string message)
    {
        HandleListen(id, message);
    }


    //----------------------------------------------------------
    // LINKED MESSAGE ROUTER
    //----------------------------------------------------------

    link_message(
        integer sender,
        integer num,
        string message,
        key id)
    {
        HandleLinkMessage(
            num,
            message);
    }


    //----------------------------------------------------------
    // INVENTORY CHANGED
    //----------------------------------------------------------

    changed(integer change)
    {
        if(change & CHANGED_INVENTORY)
        {
            RequestSongList();
            RequestSongCount();
        }
    }


    //----------------------------------------------------------
    // RESET
    //----------------------------------------------------------

    on_rez(integer start)
    {
        llResetScript();
    }
}
