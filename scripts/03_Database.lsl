///////////////////////////////////////////////////////////////
//
// MMME - Max Modular Music Engine
//
// Module
// 03_Database
//
// Version
// 1.01
//
// Build
// 3A 
// Developer Preview 1
// GitHub
// github.com/Gradyinsocal/MaxModularMusicEngine
//
// PURPOSE
// --------
// Builds the in-memory music library from all
// MMME_ notecards.
//
// This module SHALL:
//
// • Scan notecards
// • Parse songs
// • Detect duplicates
// • Build the music catalog
// • Serve library requests
//
// This module SHALL NOT:
//
// • Play music
// • Display dialogs
// • Change textures
// • Handle queue management
//
///////////////////////////////////////////////////////////////


//==============================================================
// API CHANNELS
//==============================================================

integer API_DB_REQUEST = 2000;
integer API_DB_REPLY   = 2001;
integer API_DB_READY   = 2002;


//==============================================================
// LIBRARY COMMANDS
//==============================================================

string CMD_GET_SONG      = "GET_SONG";
string CMD_LIST_SONGS    = "LIST_SONGS";
string CMD_SONG_COUNT    = "SONG_COUNT";
string CMD_LIBRARY_INFO  = "LIBRARY_INFO";


//==============================================================
// CONFIGURATION
//==============================================================

string NOTECARD_PREFIX = "MMME_";


//==============================================================
// LIBRARY CATALOG
//
// Every list shares the same index.
//
// SongID = List Index + 1
//==============================================================

list gSongTitles  = [];
list gSongArtists = [];
list gSongVolumes = [];
list gSongClips   = [];


//==============================================================
// LIBRARY STATISTICS
//==============================================================

integer gSongsLoaded      = 0;
integer gDuplicatesFound  = 0;
integer gCardsScanned     = 0;


//==============================================================
// PARSER STATE
//==============================================================

list gCards = [];

integer gCardIndex = 0;
integer gLine      = 0;

string gCardName = "";

key gQuery;

integer gInsideSong = FALSE;


//==============================================================
// CURRENT SONG BEING PARSED
//==============================================================

string pTitle;
string pArtist;

float pVolume;

list pClips;



//==============================================================
// PARSER SUPPORT
//==============================================================

ResetSong()
{
    pTitle  = "";
    pArtist = "";
    pVolume = 1.0;
    pClips  = [];
}


//==============================================================
// DUPLICATE DETECTION
//==============================================================

integer FindDuplicate(string title, string artist)
{
    integer i;

    for(i = 0; i < llGetListLength(gSongTitles); ++i)
    {
        if(llList2String(gSongTitles,i) == title &&
           llList2String(gSongArtists,i) == artist)
        {
            return i;
        }
    }

    return -1;
}


//==============================================================
// STORE SONG
//==============================================================

StoreSong()
{
    if(pTitle == "")
    {
        llOwnerSay("[MMME-LIB] Warning: Song skipped (missing Title).");
        return;
    }

    if(FindDuplicate(pTitle,pArtist) >= 0)
    {
        ++gDuplicatesFound;

        llOwnerSay(
            "[MMME-LIB] Duplicate skipped: "
            + pTitle
            + " / "
            + pArtist);

        return;
    }

    gSongTitles  += [pTitle];
    gSongArtists += [pArtist];
    gSongVolumes += [pVolume];
    gSongClips   += [llDumpList2String(pClips,"|")];

    ++gSongsLoaded;

    llOwnerSay(
        "[MMME-LIB] Loaded Song "
        + (string)gSongsLoaded
        + ": "
        + pTitle);
}


//==============================================================
// PROCESS ONE NOTECARD LINE
//==============================================================

Process(string line)
{
    line = llStringTrim(line, STRING_TRIM);

    // Ignore blank lines
    if(line == "")
        return;

    // Ignore comments
    if(llSubStringIndex(line,"//") == 0)
        return;

    //----------------------------------------------------------
    // Song Begin
    //----------------------------------------------------------

    if(line == "BEGIN SONG")
    {
        ResetSong();
        gInsideSong = TRUE;
        return;
    }

    //----------------------------------------------------------
    // Song End
    //----------------------------------------------------------

    if(line == "END SONG")
    {
        StoreSong();
        gInsideSong = FALSE;
        return;
    }

    if(!gInsideSong)
        return;

    //----------------------------------------------------------
    // Metadata
    //----------------------------------------------------------

    if(llSubStringIndex(line,"Title=") == 0)
    {
        pTitle = llGetSubString(line,6,-1);
        return;
    }

    if(llSubStringIndex(line,"Artist=") == 0)
    {
        pArtist = llGetSubString(line,7,-1);
        return;
    }

    if(llSubStringIndex(line,"Volume=") == 0)
    {
        pVolume = (float)llGetSubString(line,7,-1);
        return;
    }

    //----------------------------------------------------------
    // Clip UUID
    //----------------------------------------------------------

    if(llSubStringIndex(line,"Clip=") == 0)
    {
        string clip = llGetSubString(line,5,-1);

        if(clip != "")
            pClips += [clip];

        return;
    }
}
//==============================================================
// START READING NEXT NOTECARD
//==============================================================

StartNextCard()
{
    if(gCardIndex >= llGetListLength(gCards))
    {
        llOwnerSay("========================================");
        llOwnerSay("[MMME-LIB] Library Ready");
        llOwnerSay("[MMME-LIB] Cards Scanned : "
            + (string)gCardsScanned);
        llOwnerSay("[MMME-LIB] Songs Loaded  : "
            + (string)gSongsLoaded);
        llOwnerSay("[MMME-LIB] Duplicates   : "
            + (string)gDuplicatesFound);
        llOwnerSay("========================================");

        llMessageLinked(
            LINK_SET,
            API_DB_READY,
            "DB_READY",
            NULL_KEY);

        return;
    }

    gCardName = llList2String(gCards,gCardIndex);

    llOwnerSay("[MMME-LIB] Reading: " + gCardName);

    gLine = 0;

    gQuery = llGetNotecardLine(
        gCardName,
        gLine);
}


//==============================================================
// SCAN INVENTORY FOR LIBRARY NOTECARDS
//==============================================================

Scan()
{
    integer i;
    integer totalCards =
        llGetInventoryNumber(INVENTORY_NOTECARD);

    gCards = [];

    gSongsLoaded = 0;
    gDuplicatesFound = 0;
    gCardsScanned = 0;

    for(i=0;i<totalCards;++i)
    {
        string card =
            llGetInventoryName(
                INVENTORY_NOTECARD,
                i);

        if(llSubStringIndex(
                card,
                NOTECARD_PREFIX) == 0)
        {
            gCards += [card];
            ++gCardsScanned;
        }
    }

    llOwnerSay(
        "[MMME-LIB] Found "
        + (string)gCardsScanned
        + " library notecard(s).");

    if(gCardsScanned == 0)
    {
        llOwnerSay(
            "[MMME-LIB] No MMME_ notecards found.");

        llMessageLinked(
            LINK_SET,
            API_DB_READY,
            "DB_READY",
            NULL_KEY);

        return;
    }

    gCardIndex = 0;

    StartNextCard();
}


//==============================================================
// READ NEXT LINE
//==============================================================

ReadNextLine()
{
    ++gLine;

    gQuery =
        llGetNotecardLine(
            gCardName,
            gLine);
}


//==============================================================
// ADVANCE TO NEXT CARD
//==============================================================

AdvanceCard()
{
    ++gCardIndex;

    StartNextCard();
}
//==============================================================
// LIBRARY SERVICES
//==============================================================


//--------------------------------------------------------------
// GET SONG COUNT
//--------------------------------------------------------------

string GetSongCount()
{
    return (string)llGetListLength(gSongTitles);
}


//--------------------------------------------------------------
// BUILD SONG LIST
//
// Returns:
//
// 1=Hotel California|2=Africa|3=Dream On
//--------------------------------------------------------------

string GetSongList()
{
    integer i;
    list result = [];

    integer count = llGetListLength(gSongTitles);

    for(i = 0; i < count; ++i)
    {
        result +=
        [
            (string)(i + 1)
            + "="
            + llList2String(gSongTitles,i)
        ];
    }

    return llDumpList2String(result,"|");
}


//--------------------------------------------------------------
// LIBRARY INFORMATION
//--------------------------------------------------------------

string GetLibraryInfo()
{
    list uniqueArtists = [];

    integer i;
    integer songs = llGetListLength(gSongTitles);

    for(i = 0; i < songs; ++i)
    {
        string artist =
            llList2String(gSongArtists,i);

        if(llListFindList(
            uniqueArtists,
            [artist]) == -1)
        {
            uniqueArtists += [artist];
        }
    }

    return
        "SONGS=" + (string)songs
        + "|ARTISTS="
        + (string)llGetListLength(uniqueArtists)
        + "|CARDS="
        + (string)gCardsScanned
        + "|DUPLICATES="
        + (string)gDuplicatesFound;
}


//--------------------------------------------------------------
// SEND ONE SONG
//--------------------------------------------------------------

SendSong(integer songIndex)
{
    if(songIndex < 0)
        return;

    if(songIndex >= llGetListLength(gSongTitles))
        return;

    list packet =
    [
        "SONG",
        (string)(songIndex + 1),
        llList2String(gSongTitles,songIndex),
        llList2String(gSongArtists,songIndex),
        llList2String(gSongVolumes,songIndex)
    ];

    list clips =
        llParseStringKeepNulls(
            llList2String(gSongClips,songIndex),
            ["|"],
            []);

    packet += clips;

    llMessageLinked(
        LINK_SET,
        API_DB_REPLY,
        llDumpList2String(packet,"|"),
        NULL_KEY);
}


//--------------------------------------------------------------
// SEND SONG LIST
//--------------------------------------------------------------

SendSongList()
{
    llMessageLinked(
        LINK_SET,
        API_DB_REPLY,
        "SONG_LIST|" + GetSongList(),
        NULL_KEY);
}


//--------------------------------------------------------------
// SEND SONG COUNT
//--------------------------------------------------------------

SendSongCount()
{
    llMessageLinked(
        LINK_SET,
        API_DB_REPLY,
        "SONG_COUNT|" + GetSongCount(),
        NULL_KEY);
}


//--------------------------------------------------------------
// SEND LIBRARY INFO
//--------------------------------------------------------------

SendLibraryInfo()
{
    llMessageLinked(
        LINK_SET,
        API_DB_REPLY,
        "LIBRARY_INFO|" + GetLibraryInfo(),
        NULL_KEY);
}
//==============================================================
// API REQUEST DISPATCHER
//==============================================================

DispatchRequest(string request, list args)
{
    //----------------------------------------------------------
    // GET SONG
    //----------------------------------------------------------

    if(request == CMD_GET_SONG)
    {
        if(llGetListLength(args) < 2)
            return;

        integer songIndex =
            (integer)llList2String(args,1) - 1;

        SendSong(songIndex);
        return;
    }

    //----------------------------------------------------------
    // LIST SONGS
    //----------------------------------------------------------

    if(request == CMD_LIST_SONGS)
    {
        SendSongList();
        return;
    }

    //----------------------------------------------------------
    // SONG COUNT
    //----------------------------------------------------------

    if(request == CMD_SONG_COUNT)
    {
        SendSongCount();
        return;
    }

    //----------------------------------------------------------
    // LIBRARY INFO
    //----------------------------------------------------------

    if(request == CMD_LIBRARY_INFO)
    {
        SendLibraryInfo();
        return;
    }

    //----------------------------------------------------------
    // UNKNOWN REQUEST
    //----------------------------------------------------------

    llOwnerSay(
        "[MMME-LIB] Unknown Request: "
        + request);
}


//==============================================================
// PROCESS LINKED MESSAGE
//==============================================================

HandleLinkMessage(
    integer sender,
    integer num,
    string message,
    key id)
{
    if(num != API_DB_REQUEST)
        return;

    list args =
        llParseStringKeepNulls(
            message,
            ["|"],
            []);

    if(llGetListLength(args) == 0)
        return;

    string request =
        llList2String(args,0);

    DispatchRequest(
        request,
        args);
}


//==============================================================
// PROCESS DATASERVER
//==============================================================

HandleDataserver(
    key queryID,
    string data)
{
    if(queryID != gQuery)
        return;

    if(data == EOF)
    {
        AdvanceCard();
        return;
    }

    Process(data);

    ReadNextLine();
}
//==============================================================
// DEFAULT STATE
//==============================================================

default
{
    //----------------------------------------------------------
    // SCRIPT START
    //----------------------------------------------------------

    state_entry()
    {
        llOwnerSay("========================================");
        llOwnerSay("[MMME-LIB] Initializing Library Module");
        llOwnerSay("[MMME-LIB] Version 1.01 Build 3A Alpha 1");
        llOwnerSay("========================================");

        Scan();
    }


    //----------------------------------------------------------
    // NOTECARD READER
    //----------------------------------------------------------

    dataserver(key queryID,string data)
    {
        HandleDataserver(queryID,data);
    }


    //----------------------------------------------------------
    // LINKED MESSAGE API
    //----------------------------------------------------------

    link_message(
        integer sender,
        integer num,
        string message,
        key id)
    {
        HandleLinkMessage(
            sender,
            num,
            message,
            id);
    }


    //----------------------------------------------------------
    // INVENTORY CHANGED
    //----------------------------------------------------------

    changed(integer change)
    {
        if(change & CHANGED_INVENTORY)
        {
            llOwnerSay(
                "[MMME-LIB] Inventory changed... rebuilding library.");

            llResetScript();
        }
    }


    //----------------------------------------------------------
    // SCRIPT RESET
    //----------------------------------------------------------

    on_rez(integer start)
    {
        llResetScript();
    }
}
