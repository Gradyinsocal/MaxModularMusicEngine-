///////////////////////////////////////////////////////////////
//
// Max Modular UUID Music Engine
//
// File: 03_Database.lsl
// Version: 1.00 Foundation
//
// Designed by Max Pitre
// Programming Assistance by OpenAI ChatGPT
//
///////////////////////////////////////////////////////////////

//---------------- API ----------------
integer API_DB_REQUEST = 2000;
integer API_DB_REPLY   = 2001;
integer API_DB_READY   = 2002;

string NOTECARD_PREFIX = "MMME_";

//--------------- Catalog --------------
// One entry per song (same index in every list)
list gSongTitles  = [];
list gSongArtists = [];
list gSongVolumes = [];
list gSongClips   = [];   // Each entry is a "|" delimited clip list

//------------ Parser State ------------
list gCards = [];
integer gCardIndex;
integer gLine;
string gCardName;
key gQuery;

integer gInsideSong = FALSE;
string pTitle;
string pArtist;
float  pVolume;
list   pClips;

ResetSong()
{
    pTitle="";
    pArtist="";
    pVolume=1.0;
    pClips=[];
}

integer FindDuplicate(string title,string artist)
{
    integer i;
    for(i=0;i<llGetListLength(gSongTitles);++i)
    {
        if(llList2String(gSongTitles,i)==title &&
           llList2String(gSongArtists,i)==artist)
            return i;
    }
    return -1;
}

StoreSong()
{
    if(FindDuplicate(pTitle,pArtist)>=0)
    {
        llOwnerSay("[MMME-DB] Duplicate skipped: "+pTitle+" / "+pArtist);
        return;
    }

    gSongTitles  += [pTitle];
    gSongArtists += [pArtist];
    gSongVolumes += [pVolume];
    gSongClips   += [llDumpList2String(pClips,"|")];

    llOwnerSay("[MMME-DB] Loaded SongID "
        +(string)llGetListLength(gSongTitles)+": "+pTitle);
}

Process(string line)
{
    line=llStringTrim(line,STRING_TRIM);

    if(line=="" || llSubStringIndex(line,"//")==0) return;

    if(line=="BEGIN SONG")
    {
        ResetSong();
        gInsideSong=TRUE;
        return;
    }

    if(line=="END SONG")
    {
        StoreSong();
        gInsideSong=FALSE;
        return;
    }

    if(!gInsideSong) return;

    if(llSubStringIndex(line,"Title=")==0)
        pTitle=llGetSubString(line,6,-1);
    else if(llSubStringIndex(line,"Artist=")==0)
        pArtist=llGetSubString(line,7,-1);
    else if(llSubStringIndex(line,"Volume=")==0)
        pVolume=(float)llGetSubString(line,7,-1);
    else if(llSubStringIndex(line,"Clip=")==0)
        pClips += [llGetSubString(line,5,-1)];
}

StartNextCard()
{
    if(gCardIndex>=llGetListLength(gCards))
    {
        llOwnerSay("[MMME-DB] READY  Songs="
            +(string)llGetListLength(gSongTitles));

        llMessageLinked(LINK_SET,API_DB_READY,"DB_READY",NULL_KEY);
        return;
    }

    gCardName=llList2String(gCards,gCardIndex);
    gLine=0;
    gQuery=llGetNotecardLine(gCardName,gLine);
}

Scan()
{
    integer i;
    integer count=llGetInventoryNumber(INVENTORY_NOTECARD);

    gCards=[];

    for(i=0;i<count;++i)
    {
        string n=llGetInventoryName(INVENTORY_NOTECARD,i);
        if(llSubStringIndex(n,NOTECARD_PREFIX)==0)
            gCards+=[n];
    }

    gCardIndex=0;
    StartNextCard();
}

default
{
    state_entry()
    {
        llOwnerSay("[MMME-DB] Building Catalog...");
        Scan();
    }

    dataserver(key id,string data)
    {
        if(id!=gQuery) return;

        if(data==EOF)
        {
            ++gCardIndex;
            StartNextCard();
            return;
        }

        Process(data);

        ++gLine;
        gQuery=llGetNotecardLine(gCardName,gLine);
    }

    link_message(integer sender,integer num,string msg,key id)
    {
        if(num!=API_DB_REQUEST) return;

        list cmd=llParseString2List(msg,["|"],[]);
        if(llGetListLength(cmd)<2) return;
        if(llList2String(cmd,0)!="GET_SONG") return;

        integer songID=(integer)llList2String(cmd,1)-1;
        if(songID<0 || songID>=llGetListLength(gSongTitles)) return;

        list packet=[
            "SONG",
            (string)(songID+1),
            llList2String(gSongTitles,songID),
            llList2String(gSongArtists,songID),
            llList2String(gSongVolumes,songID)
        ];

        list clips=llParseStringKeepNulls(
            llList2String(gSongClips,songID),["|"],[]);

        packet += clips;

        llMessageLinked(
            LINK_SET,
            API_DB_REPLY,
            llDumpList2String(packet,"|"),
            NULL_KEY);
    }

    changed(integer c)
    {
        if(c & CHANGED_INVENTORY) llResetScript();
    }
}
