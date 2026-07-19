
///////////////////////////////////////////////////////////////
//
// Max Modular UUID Music Engine
// File: 05_Display.lsl
// Version: 1.3 — Production Font
//
// 12 identical eight-face display strips:
// DISPLAY_R1_A ... DISPLAY_R4_C
//
// Face order on every strip, left to right:
// [1,0,2,7,6,5,4,3]
//
///////////////////////////////////////////////////////////////

integer API_IF_STATE        = 3000;
integer API_IF_NOWPLAYING   = 3001;
integer API_PANEL_POWER     = 3100;

integer STATE_STOPPED = 0;
integer STATE_PLAYING = 1;
integer STATE_PAUSED  = 2;

string FONT_ATLAS_UUID =
    "a486c3d6-f2f3-9705-e014-d901b91897a1";

integer ATLAS_COLUMNS = 16;
integer ATLAS_ROWS = 8;

integer ROW_COUNT = 4;
integer ROW_LENGTH = 24;
list DISPLAY_FACES = [1,0,2,7,6,5,4,3];

list PANEL_NAMES =
[
    "DISPLAY_R1_A","DISPLAY_R1_B","DISPLAY_R1_C",
    "DISPLAY_R2_A","DISPLAY_R2_B","DISPLAY_R2_C",
    "DISPLAY_R3_A","DISPLAY_R3_B","DISPLAY_R3_C",
    "DISPLAY_R4_A","DISPLAY_R4_B","DISPLAY_R4_C"
];

list ATLAS_CHARACTERS =
[
    " ","A","B","C","D","E","F","G",
    "H","I","J","K","L","M","N","O",
    "P","Q","R","S","T","U","V","W",
    "X","Y","Z","0","1","2","3","4",
    "5","6","7","8","9","a","b","c",
    "d","e","f","g","h","i","j",
    "k","l","m","n","o","p","q","r",
    "s","t","u","v","w","x","y","z",
    ".",",","!","?","-","_","/","\\",
    ":",";","'","\"","(",")","+","=",
    "<",">","[","]","{","}","@","#",
    "$","%","&","*","^","~","|","`",
    " "," "," "," "," "," "," "," ",
    " "," "," "," "," "," "," "," ",
    " "," "," "," "," "," "," "," ",
    " "," "," "," "," "," "," "," "
];

list gRowLinks0 = [];
list gRowFaces0 = [];
list gRowLinks1 = [];
list gRowFaces1 = [];
list gRowLinks2 = [];
list gRowFaces2 = [];
list gRowLinks3 = [];
list gRowFaces3 = [];

string gTitle = "";
string gArtist = "";
integer gState = STATE_STOPPED;
integer gPowered = FALSE;
integer gReady = FALSE;

integer gStartingUp = FALSE;
integer gStartupStep = 0;
integer gStartupTicks = 0;

list gScrollPos = [0,0,0,0];
list gScrollText = ["","","",""];
float SCROLL_INTERVAL = 0.40;
integer STARTUP_TICKS_PER_PAGE = 3;

integer FindLinkByName(string primName)
{
    integer count = llGetNumberOfPrims();
    integer link;
    for(link = 1; link <= count; ++link)
        if(llGetLinkName(link) == primName)
            return link;
    return 0;
}

AppendPanel(integer row, integer link)
{
    integer i;
    for(i = 0; i < llGetListLength(DISPLAY_FACES); ++i)
    {
        integer face = llList2Integer(DISPLAY_FACES, i);
        if(row == 0)
        {
            gRowLinks0 += [link];
            gRowFaces0 += [face];
        }
        else if(row == 1)
        {
            gRowLinks1 += [link];
            gRowFaces1 += [face];
        }
        else if(row == 2)
        {
            gRowLinks2 += [link];
            gRowFaces2 += [face];
        }
        else
        {
            gRowLinks3 += [link];
            gRowFaces3 += [face];
        }
    }
}

BuildHardwareMap()
{
    gRowLinks0=[]; gRowFaces0=[];
    gRowLinks1=[]; gRowFaces1=[];
    gRowLinks2=[]; gRowFaces2=[];
    gRowLinks3=[]; gRowFaces3=[];

    integer i;
    integer missing = 0;
    for(i = 0; i < 12; ++i)
    {
        string panelName = llList2String(PANEL_NAMES, i);
        integer link = FindLinkByName(panelName);
        if(link == 0)
        {
            ++missing;
            llOwnerSay("[MMME-DISPLAY] Missing " + panelName);
        }
        else
            AppendPanel(i / 3, link);
    }

    gReady = (missing == 0);
    if(gReady)
        llOwnerSay("[MMME-DISPLAY] 24x4 display hardware ready.");
}

integer CharacterIndex(string character)
{
    integer index = llListFindList(ATLAS_CHARACTERS, [character]);
    if(index >= 0) return index;
    return 0;
}

string CharAt(string text, integer index)
{
    if(index < 0 || index >= llStringLength(text)) return " ";
    return llGetSubString(text,index,index);
}

string PadRight(string text, integer width)
{
    while(llStringLength(text) < width) text += " ";
    return llGetSubString(text,0,width-1);
}

string CenterText(string text, integer width)
{
    if(llStringLength(text) >= width)
        return llGetSubString(text,0,width-1);

    integer left = (width - llStringLength(text)) / 2;
    string result = "";
    integer i;
    for(i=0;i<left;++i) result += " ";
    result += text;
    return PadRight(result,width);
}

SetGlyph(integer link, integer face, string character)
{
    if(!gReady || link <= 0) return;

    integer cell = CharacterIndex(character);
    integer column = cell % ATLAS_COLUMNS;
    integer row = cell / ATLAS_COLUMNS;

    float repeatX = 1.0 / (float)ATLAS_COLUMNS;
    float repeatY = 1.0 / (float)ATLAS_ROWS;
    float offsetX = -0.5 + ((float)column + 0.5) * repeatX;
    float offsetY =  0.5 - ((float)row + 0.5) * repeatY;

    llSetLinkPrimitiveParamsFast(
        link,
        [PRIM_TEXTURE,face,FONT_ATLAS_UUID,
         <repeatX,repeatY,0.0>,<offsetX,offsetY,0.0>,0.0]);
}

RenderRow(integer row, string text)
{
    list links;
    list faces;

    if(row == 0) { links=gRowLinks0; faces=gRowFaces0; }
    else if(row == 1) { links=gRowLinks1; faces=gRowFaces1; }
    else if(row == 2) { links=gRowLinks2; faces=gRowFaces2; }
    else { links=gRowLinks3; faces=gRowFaces3; }

    text = PadRight(text,ROW_LENGTH);
    integer i;
    for(i=0;i<ROW_LENGTH;++i)
        SetGlyph(llList2Integer(links,i),llList2Integer(faces,i),CharAt(text,i));
}

string StateText()
{
    if(gState == STATE_PLAYING) return "PLAYING";
    if(gState == STATE_PAUSED) return "PAUSED";
    return "STOPPED";
}

SetScrollRow(integer row, string text)
{
    gScrollText = llListReplaceList(gScrollText,[text],row,row);
    gScrollPos = llListReplaceList(gScrollPos,[0],row,row);

    if(llStringLength(text) <= ROW_LENGTH)
        RenderRow(row,CenterText(text,ROW_LENGTH));
}

RenderScrollingRow(integer row)
{
    string text = llList2String(gScrollText,row);
    if(llStringLength(text) <= ROW_LENGTH) return;

    integer pos = llList2Integer(gScrollPos,row);
    string loop = text + "    " + text;
    integer len = llStringLength(loop);
    string window = "";
    integer i;
    for(i=0;i<ROW_LENGTH;++i)
        window += CharAt(loop,(pos+i)%len);

    RenderRow(row,window);
    gScrollPos = llListReplaceList(gScrollPos,[pos+1],row,row);
}

BlankDisplay()
{
    RenderRow(0,"");
    RenderRow(1,"");
    RenderRow(2,"");
    RenderRow(3,"");
}

ShowStartupPage()
{
    if(gStartupStep == 0)
    {
        RenderRow(0,"");
        RenderRow(1,CenterText("AWAKENING...",ROW_LENGTH));
        RenderRow(2,"");
        RenderRow(3,"");
    }
    else if(gStartupStep == 1)
    {
        RenderRow(0,CenterText("MAX MODULAR",ROW_LENGTH));
        RenderRow(1,CenterText("MUSIC ENGINE",ROW_LENGTH));
        RenderRow(2,CenterText("MMME",ROW_LENGTH));
        RenderRow(3,CenterText("VERSION 1.0",ROW_LENGTH));
    }
    else if(gStartupStep == 2)
    {
        RenderRow(0,"");
        RenderRow(1,CenterText("MMME READY",ROW_LENGTH));
        RenderRow(2,"");
        RenderRow(3,CenterText("SYSTEM ONLINE",ROW_LENGTH));
    }
    else
    {
        gStartingUp = FALSE;
        UpdateDisplay();
        return;
    }

    gStartupTicks = 0;
}

UpdateDisplay()
{
    if(!gPowered)
    {
        BlankDisplay();
        return;
    }

    RenderRow(0,CenterText("NOW PLAYING",ROW_LENGTH));

    string title = gTitle;
    if(title == "") title = "MMME READY";
    SetScrollRow(1,title);

    string artist = gArtist;
    if(artist == "") artist = "MAX MODULAR MUSIC ENGINE";
    SetScrollRow(2,artist);

    RenderRow(3,CenterText(StateText(),ROW_LENGTH));
}

HandleNowPlaying(string message)
{
    list fields = llParseStringKeepNulls(message,["|"],[]);
    if(llGetListLength(fields) >= 2)
    {
        gTitle = llList2String(fields,0);
        gArtist = llList2String(fields,1);
        UpdateDisplay();
    }
}

default
{
    state_entry()
    {
        BuildHardwareMap();

        if(FONT_ATLAS_UUID == "00000000-0000-0000-0000-000000000000")
            llOwnerSay("[MMME-DISPLAY] Paste the production atlas UUID.");

        BlankDisplay();
        llSetTimerEvent(SCROLL_INTERVAL);
    }

    timer()
    {
        if(!gPowered)
            return;

        if(gStartingUp)
        {
            ++gStartupTicks;

            if(gStartupTicks >= STARTUP_TICKS_PER_PAGE)
            {
                ++gStartupStep;
                ShowStartupPage();
            }

            return;
        }

        RenderScrollingRow(1);
        RenderScrollingRow(2);
    }

    link_message(integer sender, integer number, string message, key id)
    {
        if(number == API_IF_STATE)
        {
            gState = (integer)message;
            if(gPowered) RenderRow(3,CenterText(StateText(),ROW_LENGTH));
            return;
        }

        if(number == API_IF_NOWPLAYING)
        {
            HandleNowPlaying(message);
            return;
        }

        if(number == API_PANEL_POWER)
        {
            gPowered = (integer)message;

            if(gPowered)
            {
                gStartingUp = TRUE;
                gStartupStep = 0;
                gStartupTicks = 0;
                ShowStartupPage();
            }
            else
            {
                gStartingUp = FALSE;
                BlankDisplay();
            }

            return;
        }
    }

    changed(integer change)
    {
        if(change & CHANGED_LINK)
        {
            BuildHardwareMap();
            UpdateDisplay();
        }
    }

    on_rez(integer start)
    {
        llResetScript();
    }
}
