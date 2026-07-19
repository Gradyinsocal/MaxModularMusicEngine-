
///////////////////////////////////////////////////////////////
//
// Max Modular UUID Music Engine
// File: 06_ControlPanel.lsl
// Version: 1.3 — Faster VU and Dialog Cleanup
//
// Physical controls, power lighting, top crystal and VU meters.
//
///////////////////////////////////////////////////////////////

integer API_ENGINE_PLAY      = 2100;
integer API_ENGINE_STOP      = 2101;
integer API_ENGINE_PAUSE     = 2102;
integer API_ENGINE_RESUME    = 2103;
integer API_ENGINE_NEXT      = 2106;
integer API_ENGINE_PREV      = 2107;

integer API_IF_STATE         = 3000;
integer API_IF_OPEN_BROWSE   = 3002;
integer API_IF_OPEN_VOLUME   = 3003;
integer API_IF_GUEST_STATE   = 3004;
integer API_PANEL_POWER      = 3100;

integer STATE_STOPPED = 0;
integer STATE_PLAYING = 1;
integer STATE_PAUSED  = 2;

string NAME_POWER = "POWER";
string NAME_PREV = "PREV";
string NAME_PLAY = "PLAY";
string NAME_PAUSE = "PAUSE";
string NAME_STOP = "STOP";
string NAME_NEXT = "NEXT";
string NAME_BROWSE = "BROWSE";
string NAME_VOLUME = "VOLUME";

string NAME_LIGHTS = "LIGHTS";
string NAME_LIGHTTOP = "LIGHTTOP";
string NAME_VULEFT = "VULEFT";
string NAME_VURIGHT = "VURIGHT";
string NAME_RUNES = "RUNES";

integer SCREEN_LINK = LINK_ROOT;
integer SCREEN_FACE = 6;

list VU_FACES = [6,5,4,7,3,2,1,0];

// Bottom to top on the mesh.
list RUNE_FACES = [4,3,1,2,0];

// Top-to-bottom logical roles.
integer RUNE_LOADING = 0;
integer RUNE_READY   = 2;
integer RUNE_PLAYING = 1;
integer RUNE_PAUSED  = 3;
integer RUNE_GUEST   = 4;

vector COLOR_RUNE_LOADING = <0.20,0.55,1.00>;
vector COLOR_RUNE_READY   = <0.65,0.30,1.00>;
vector COLOR_RUNE_PLAYING = <0.20,1.00,0.35>;
vector COLOR_RUNE_PAUSED  = <1.00,0.55,0.10>;
vector COLOR_RUNE_GUEST   = <0.85,0.25,1.00>;
vector COLOR_RUNE_ERROR   = <1.00,0.10,0.10>;

float TIMER_STEP = 0.08;
float POWER_FADE_STEP = 0.055;

float DORMANT_CRYSTAL_LEVEL = 0.72;
float DORMANT_LIGHT_LEVEL   = 0.55;
float DORMANT_SCREEN_LEVEL  = 0.18;

integer gPowered = FALSE;
integer gState = STATE_STOPPED;

integer gTopLink = 0;
integer gVuLeftLink = 0;
integer gVuRightLink = 0;
integer gRunesLink = 0;
list gLightsLinks = [];

float gPowerLevel = 0.0;
integer gPowerDirection = 0;

float gPulsePhase = 0.0;

float gVuLeft = 0.0;
float gVuRight = 0.0;
float gVuLeftTarget = 0.0;
float gVuRightTarget = 0.0;
integer gTargetTicks = 0;

integer gRuneSweepDirection = 0;
integer gRuneSweepStep = 0;
integer gRuneSweepTick = 0;
integer gGuestEnabled = FALSE;

integer FindLinkByName(string name)
{
    integer count = llGetNumberOfPrims();
    integer link;
    for(link=1;link<=count;++link)
        if(llGetLinkName(link) == name)
            return link;
    return 0;
}

list FindAllLinksByName(string name)
{
    list found = [];
    integer count = llGetNumberOfPrims();
    integer link;
    for(link=1;link<=count;++link)
        if(llGetLinkName(link) == name)
            found += [link];
    return found;
}

DiscoverHardware()
{
    gTopLink = FindLinkByName(NAME_LIGHTTOP);
    gVuLeftLink = FindLinkByName(NAME_VULEFT);
    gVuRightLink = FindLinkByName(NAME_VURIGHT);
    gRunesLink = FindLinkByName(NAME_RUNES);
    gLightsLinks = FindAllLinksByName(NAME_LIGHTS);
}

float ClampFloat(float value, float low, float high)
{
    if(value < low) return low;
    if(value > high) return high;
    return value;
}

SetMeshBrightness(integer link, float level, float glow)
{
    if(link <= 0) return;
    level = ClampFloat(level,0.0,1.0);
    glow = ClampFloat(glow,0.0,1.0);

    llSetLinkPrimitiveParamsFast(
        link,
        [
            PRIM_COLOR,ALL_SIDES,<level,level,level>,1.0,
            PRIM_GLOW,ALL_SIDES,glow,
            PRIM_FULLBRIGHT,ALL_SIDES,(level > 0.55)
        ]);
}

SetScreenBrightness(float level)
{
    level = ClampFloat(level,0.0,1.0);
    llSetLinkPrimitiveParamsFast(
        SCREEN_LINK,
        [
            PRIM_COLOR,SCREEN_FACE,<level,level,level>,1.0,
            PRIM_GLOW,SCREEN_FACE,0.08*level,
            PRIM_FULLBRIGHT,SCREEN_FACE,(level > 0.55)
        ]);
}

ApplyPowerLevel(float level)
{
    float lightLevel =
        DORMANT_LIGHT_LEVEL
        + ((1.0 - DORMANT_LIGHT_LEVEL) * level);

    float crystalLevel =
        DORMANT_CRYSTAL_LEVEL
        + ((1.0 - DORMANT_CRYSTAL_LEVEL) * level);

    float screenLevel =
        DORMANT_SCREEN_LEVEL
        + ((1.0 - DORMANT_SCREEN_LEVEL) * level);

    integer i;

    for(i=0;i<llGetListLength(gLightsLinks);++i)
    {
        SetMeshBrightness(
            llList2Integer(gLightsLinks,i),
            lightLevel,
            0.08 * level);
    }

    SetMeshBrightness(
        gTopLink,
        crystalLevel,
        0.16 * level);

    SetScreenBrightness(screenLevel);
}

SetVuLevel(integer link, float level)
{
    if(link <= 0) return;

    integer lit = (integer)llRound(level);
    integer i;
    for(i=0;i<8;++i)
    {
        integer face = llList2Integer(VU_FACES,i);
        integer on = FALSE;
        float glow = 0.0;

        if(i < lit)
        {
            on = TRUE;
            glow = 0.18;
        }

        llSetLinkPrimitiveParamsFast(
            link,
            [
                PRIM_COLOR,face,<1.0,1.0,1.0>,1.0,
                PRIM_GLOW,face,glow,
                PRIM_FULLBRIGHT,face,on
            ]);
    }
}

float ChooseVuTarget()
{
    float r = llFrand(1.0);

    if(r < 0.45) return 3.0 + llFrand(2.0);   // common: 3–5
    if(r < 0.78) return 4.5 + llFrand(1.5);   // common-high: 4.5–6
    if(r < 0.94) return 5.5 + llFrand(1.5);   // occasional: 5.5–7
    if(r < 0.992) return 6.5 + llFrand(0.8);  // uncommon: 6.5–7.3
    return 8.0;                                // rare full peak
}

float MoveToward(float current, float target, float amount)
{
    if(current < target)
    {
        current += amount;
        if(current > target) current = target;
    }
    else if(current > target)
    {
        current -= amount;
        if(current < target) current = target;
    }
    return current;
}

UpdateVu()
{
    if(!gPowered || gState == STATE_STOPPED)
    {
        gVuLeft = MoveToward(gVuLeft,0.0,0.9);
        gVuRight = MoveToward(gVuRight,0.0,0.9);
    }
    else if(gState == STATE_PAUSED)
    {
        gVuLeft = MoveToward(gVuLeft,0.0,0.25);
        gVuRight = MoveToward(gVuRight,0.0,0.25);
    }
    else
    {
        --gTargetTicks;
        if(gTargetTicks <= 0)
        {
            gVuLeftTarget = ChooseVuTarget();
            gVuRightTarget = ClampFloat(gVuLeftTarget + llFrand(2.1) - 1.05,1.0,8.0);
            gTargetTicks = 3 + (integer)llFrand(7.0);
        }

        gVuLeft = MoveToward(gVuLeft,gVuLeftTarget,0.46 + llFrand(0.24));
        gVuRight = MoveToward(gVuRight,gVuRightTarget,0.46 + llFrand(0.24));
    }

    SetVuLevel(gVuLeftLink,gVuLeft);
    SetVuLevel(gVuRightLink,gVuRight);
}

UpdateTopCrystal()
{
    if(!gPowered)
    {
        SetMeshBrightness(
            gTopLink,
            DORMANT_CRYSTAL_LEVEL,
            0.0);

        return;
    }

    gPulsePhase += TIMER_STEP;

    float level;
    float glow;

    if(gState == STATE_PLAYING)
    {
        level = 0.78 + 0.12 * llSin(gPulsePhase * 2.0);
        glow = 0.12 + 0.06 * llSin(gPulsePhase * 2.0);
    }
    else if(gState == STATE_PAUSED)
    {
        level = 0.62 + 0.18 * llSin(gPulsePhase * 0.8);
        glow = 0.08 + 0.05 * llSin(gPulsePhase * 0.8);
    }
    else
    {
        level = 0.36;
        glow = 0.04;
    }

    SetMeshBrightness(gTopLink,level,glow);
}

SetRuneFace(
    integer face,
    integer on,
    vector activeColor,
    float glow)
{
    if(gRunesLink <= 0)
        return;

    vector tint = <1.0,1.0,1.0>;
    integer fullBright = FALSE;

    if(on)
    {
        tint = activeColor;
        fullBright = TRUE;
    }

    llSetLinkPrimitiveParamsFast(
        gRunesLink,
        [
            PRIM_COLOR,
            face,
            tint,
            1.0,

            PRIM_GLOW,
            face,
            glow,

            PRIM_FULLBRIGHT,
            face,
            fullBright
        ]);
}


ClearRunes()
{
    integer i;

    for(i=0;i<llGetListLength(RUNE_FACES);++i)
    {
        SetRuneFace(
            llList2Integer(RUNE_FACES,i),
            FALSE,
            <1.0,1.0,1.0>,
            0.0);
    }
}


ShowStateRunes()
{
    ClearRunes();

    if(!gPowered)
        return;

    if(gState == STATE_PLAYING)
    {
        SetRuneFace(
            RUNE_PLAYING,
            TRUE,
            COLOR_RUNE_PLAYING,
            0.18);
    }
    else if(gState == STATE_PAUSED)
    {
        SetRuneFace(
            RUNE_PAUSED,
            TRUE,
            COLOR_RUNE_PAUSED,
            0.14);
    }
    else
    {
        SetRuneFace(
            RUNE_READY,
            TRUE,
            COLOR_RUNE_READY,
            0.11);
    }

    if(gGuestEnabled)
    {
        SetRuneFace(
            RUNE_GUEST,
            TRUE,
            COLOR_RUNE_GUEST,
            0.05);
    }
}


StartRuneSweep(integer direction)
{
    gRuneSweepDirection = direction;
    gRuneSweepTick = 0;

    if(direction > 0)
        gRuneSweepStep = 4;
    else
        gRuneSweepStep = 0;

    ClearRunes();
}


UpdateRuneSweep()
{
    if(gRuneSweepDirection == 0)
        return;

    ++gRuneSweepTick;

    if(gRuneSweepTick < 2)
        return;

    gRuneSweepTick = 0;
    ClearRunes();

    if(
        gRuneSweepStep >= 0
        && gRuneSweepStep < 5)
    {
        SetRuneFace(
            llList2Integer(
                RUNE_FACES,
                gRuneSweepStep),
            TRUE,
            COLOR_RUNE_LOADING,
            0.20);
    }

    if(gRuneSweepDirection > 0)
        --gRuneSweepStep;
    else
        ++gRuneSweepStep;

    if(
        gRuneSweepStep < 0
        || gRuneSweepStep > 4)
    {
        gRuneSweepDirection = 0;

        if(gPowered)
            ShowStateRunes();
        else
            ClearRunes();
    }
}


SetButtonGlow(string buttonName, integer on)
{
    integer link = FindLinkByName(buttonName);
    if(link <= 0) return;

    float glow = 0.0;

    if(on)
        glow = 0.12;

    llSetLinkPrimitiveParamsFast(
        link,
        [
            PRIM_GLOW,ALL_SIDES,glow,
            PRIM_FULLBRIGHT,ALL_SIDES,on
        ]);
}

UpdateButtonLights()
{
    SetButtonGlow(NAME_POWER,gPowered);
    SetButtonGlow(NAME_PLAY,(gPowered && gState == STATE_PLAYING));
    SetButtonGlow(NAME_PAUSE,(gPowered && gState == STATE_PAUSED));
    SetButtonGlow(NAME_STOP,(gPowered && gState == STATE_STOPPED));
}

PowerOn()
{
    if(gPowered) return;

    gPowered = TRUE;
    gPowerDirection = 1;
    gPowerLevel = 0.0;

    llMessageLinked(LINK_SET,API_PANEL_POWER,"1",NULL_KEY);

    StartRuneSweep(1);
    UpdateButtonLights();
}

PowerOff()
{
    if(!gPowered) return;

    llMessageLinked(LINK_SET,API_ENGINE_STOP,"",llGetOwner());

    gPowerDirection = -1;
    gPowerLevel = 1.0;
    gPowered = FALSE;

    llMessageLinked(LINK_SET,API_PANEL_POWER,"0",NULL_KEY);

    StartRuneSweep(-1);
    UpdateButtonLights();
}

HandleButton(key user, string name)
{
    if(name == NAME_POWER)
    {
        if(gPowered) PowerOff();
        else PowerOn();
        return;
    }

    if(!gPowered) return;

    if(name == NAME_PREV)
        llMessageLinked(LINK_SET,API_ENGINE_PREV,"",user);
    else if(name == NAME_PLAY)
    {
        if(gState == STATE_PAUSED)
            llMessageLinked(LINK_SET,API_ENGINE_RESUME,"",user);
        else
            llMessageLinked(LINK_SET,API_ENGINE_PLAY,"",user);
    }
    else if(name == NAME_PAUSE)
        llMessageLinked(LINK_SET,API_ENGINE_PAUSE,"",user);
    else if(name == NAME_STOP)
        llMessageLinked(LINK_SET,API_ENGINE_STOP,"",user);
    else if(name == NAME_NEXT)
        llMessageLinked(LINK_SET,API_ENGINE_NEXT,"",user);
    else if(name == NAME_BROWSE)
        llMessageLinked(LINK_SET,API_IF_OPEN_BROWSE,"",user);
    else if(name == NAME_VOLUME)
        llMessageLinked(LINK_SET,API_IF_OPEN_VOLUME,"",user);
}

default
{
    state_entry()
    {
        DiscoverHardware();
        ApplyPowerLevel(0.0);
        SetVuLevel(gVuLeftLink,0.0);
        SetVuLevel(gVuRightLink,0.0);
        ClearRunes();
        UpdateButtonLights();
        llSetTimerEvent(TIMER_STEP);
    }

    touch_start(integer total)
    {
        integer link = llDetectedLinkNumber(0);
        key user = llDetectedKey(0);
        string name = llGetLinkName(link);
        HandleButton(user,name);
    }

    timer()
    {
        if(gPowerDirection != 0)
        {
            gPowerLevel += POWER_FADE_STEP * (float)gPowerDirection;

            if(gPowerLevel >= 1.0)
            {
                gPowerLevel = 1.0;
                gPowerDirection = 0;
            }
            else if(gPowerLevel <= 0.0)
            {
                gPowerLevel = 0.0;
                gPowerDirection = 0;
            }

            ApplyPowerLevel(gPowerLevel);
        }

        UpdateTopCrystal();
        UpdateVu();
        UpdateRuneSweep();
    }

    link_message(integer sender, integer number, string message, key id)
    {
        if(number == API_IF_STATE)
        {
            gState = (integer)message;
            UpdateButtonLights();

            if(gRuneSweepDirection == 0)
                ShowStateRunes();

            return;
        }

        if(number == API_IF_GUEST_STATE)
        {
            gGuestEnabled = (integer)message;

            if(gRuneSweepDirection == 0)
                ShowStateRunes();

            return;
        }
    }

    changed(integer change)
    {
        if(change & CHANGED_LINK)
        {
            DiscoverHardware();
            ApplyPowerLevel(gPowerLevel);
        }
    }

    on_rez(integer start)
    {
        llResetScript();
    }
}
