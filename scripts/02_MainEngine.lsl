
///////////////////////////////////////////////////////////////
//
// MMME - Max Modular Music Engine
//
// File: 02_MainEngine.lsl
// Version: 1.01
// Build: 5.2T1 — 19.8 Second Timing Test
//
// FEATURES
//
// • Seamless queued UUID playback
// • Preloads upcoming clips
// • Play / Pause / Continue / Stop
// • PLAY_SONG support from the song browser
// • Immediate session volume control
// • Next / Previous track navigation with wraparound
// • Preserves each song's notecard volume as its base
// • Ignores non-song Library replies
//
///////////////////////////////////////////////////////////////


//==============================================================
// LIBRARY API
//==============================================================

integer API_DB_REQUEST = 2000;
integer API_DB_REPLY   = 2001;
integer API_DB_READY   = 2002;


//==============================================================
// PLAYBACK API
//==============================================================

integer API_ENGINE_PLAY      = 2100;
integer API_ENGINE_STOP      = 2101;
integer API_ENGINE_PAUSE     = 2102;
integer API_ENGINE_RESUME    = 2103;
integer API_ENGINE_PLAY_SONG = 2104;
integer API_ENGINE_VOLUME    = 2105;
integer API_ENGINE_NEXT      = 2106;
integer API_ENGINE_PREV      = 2107;


//==============================================================
// INTERFACE API
//==============================================================

integer API_IF_STATE      = 3000;
integer API_IF_NOWPLAYING = 3001;


//==============================================================
// PLAYER STATES
//==============================================================

integer STATE_STOPPED = 0;
integer STATE_PLAYING = 1;
integer STATE_PAUSED  = 2;


//==============================================================
// PLAYBACK TIMING
//==============================================================

float CLIP_LENGTH     = 20.0;

// Proven timing rule: queue 0.2 seconds before the nominal end.
float QUEUE_LEAD_TIME = 19.80;

// Time remaining in the current clip when the next clip is queued.
float QUEUE_TAIL_TIME = 0.20;

// The final clip may override this through LastClipLength.
float gLastClipLength = 20.0;


//==============================================================
// ENGINE STATUS
//==============================================================

integer DEBUG = FALSE;

integer gState         = STATE_STOPPED;
integer gDatabaseReady = FALSE;
integer gSongLoaded    = FALSE;
integer gAutoPlay      = FALSE;

integer gRequestedSongID = 1;
integer gCurrentSongID   = 1;
integer gSongCount       = 0;


//==============================================================
// SONG DATA
//==============================================================

string gTitle  = "";
string gArtist = "";

// Base volume supplied by the song notecard.
float gSongVolume = 1.0;

// Owner-selected session volume from 0.0 through 1.0.
float gUserVolume = 1.0;

list gClips = [];


//==============================================================
// PLAYBACK POSITION
//==============================================================

integer gRunStartClip      = 0;
integer gNextClipToQueue   = 0;
integer gWaitingForFinish  = FALSE;

float gRunStartTime = 0.0;


//==============================================================
// DEBUG
//==============================================================

Debug(string text)
{
    if(DEBUG)
        llOwnerSay("[MMME-PLAY] " + text);
}


//==============================================================
// INTERFACE NOTIFICATIONS
//==============================================================

NotifyState()
{
    llMessageLinked(
        LINK_SET,
        API_IF_STATE,
        (string)gState,
        NULL_KEY);
}

NotifyNowPlaying()
{
    llMessageLinked(
        LINK_SET,
        API_IF_NOWPLAYING,
        gTitle + "|" + gArtist,
        NULL_KEY);
}


//==============================================================
// UUID VALIDATION
//==============================================================

integer IsValidSoundUUID(string value)
{
    value = llStringTrim(value, STRING_TRIM);

    if(value == "")
        return FALSE;

    if(llStringLength(value) != 36)
        return FALSE;

    if((key)value == NULL_KEY)
        return FALSE;

    return TRUE;
}


//==============================================================
// VOLUME
//==============================================================

float EffectiveVolume()
{
    float volume = gSongVolume * gUserVolume;

    if(volume < 0.0)
        volume = 0.0;

    if(volume > 1.0)
        volume = 1.0;

    return volume;
}

SetUserVolume(float volume)
{
    if(volume < 0.0)
        volume = 0.0;

    if(volume > 1.0)
        volume = 1.0;

    gUserVolume = volume;

    // Changes the currently playing attached sound immediately.
    llAdjustSoundVolume(EffectiveVolume());
}


//==============================================================
// QUEUE CONTROL
//==============================================================

FlushSoundQueue()
{
    llSetSoundQueueing(FALSE);
    llStopSound();
    llSetTimerEvent(0.0);
    llSetSoundQueueing(TRUE);
}


//==============================================================
// LIBRARY REQUESTS
//==============================================================

RequestSong(integer songID, integer autoPlay)
{
    if(songID < 1)
        songID = 1;

    gRequestedSongID = songID;
    gAutoPlay = autoPlay;

    llMessageLinked(
        LINK_SET,
        API_DB_REQUEST,
        "GET_SONG|" + (string)songID,
        NULL_KEY);
}


//==============================================================
// LIBRARY PACKET
//==============================================================

LoadSongPacket(string packet)
{
    if(llSubStringIndex(packet, "SONG|") != 0)
        return;

    list fields =
        llParseStringKeepNulls(
            packet,
            ["|"],
            []);

    if(llGetListLength(fields) < 6)
    {
        Debug("Invalid SONG packet.");
        gAutoPlay = FALSE;
        return;
    }

    integer packetSongID =
        (integer)llList2String(fields, 1);

    gCurrentSongID = packetSongID;

    gTitle =
        llStringTrim(
            llList2String(fields, 2),
            STRING_TRIM);

    gArtist =
        llStringTrim(
            llList2String(fields, 3),
            STRING_TRIM);

    gSongVolume =
        (float)llStringTrim(
            llList2String(fields, 4),
            STRING_TRIM);

    if(gSongVolume < 0.0)
        gSongVolume = 0.0;

    if(gSongVolume > 1.0)
        gSongVolume = 1.0;

    gLastClipLength = 20.0;

    integer clipStart = 5;
    string metadata = llList2String(fields, 5);

    if(llSubStringIndex(metadata, "LAST=") == 0)
    {
        float lastValue =
            (float)llGetSubString(metadata, 5, -1);

        if(lastValue > 0.0 && lastValue <= 30.0)
            gLastClipLength = lastValue;

        clipStart = 6;
    }

    list cleanClips = [];
    integer i;

    for(i = clipStart; i < llGetListLength(fields); ++i)
    {
        string clip =
            llStringTrim(
                llList2String(fields, i),
                STRING_TRIM);

        if(IsValidSoundUUID(clip))
            cleanClips += [clip];
        else
            Debug(
                "Skipped invalid clip entry in "
                + gTitle
                + ": "
                + clip);
    }

    if(llGetListLength(cleanClips) == 0)
    {
        gClips = [];
        gSongLoaded = FALSE;
        gAutoPlay = FALSE;

        Debug(
            "No valid sound UUIDs found for "
            + gTitle
            + ".");

        return;
    }

    FlushSoundQueue();

    gClips = cleanClips;
    gSongLoaded = TRUE;

    gRunStartClip = 0;
    gNextClipToQueue = 0;
    gWaitingForFinish = FALSE;

    NotifyNowPlaying();

    Debug(
        "Loaded Song "
        + (string)packetSongID
        + ": "
        + gTitle);

    if(gAutoPlay)
    {
        gAutoPlay = FALSE;

        gState = STATE_PLAYING;
        NotifyState();

        BeginPlaybackAt(0);
    }
}


//==============================================================
// PRELOAD
//==============================================================

PreloadClip(integer clipIndex)
{
    if(clipIndex < 0)
        return;

    if(clipIndex >= llGetListLength(gClips))
        return;

    string clipUUID =
        llList2String(
            gClips,
            clipIndex);

    if(IsValidSoundUUID(clipUUID))
        llPreloadSound(clipUUID);
}


//==============================================================
// BEGIN PLAYBACK
//==============================================================

BeginPlaybackAt(integer clipIndex)
{
    integer count = llGetListLength(gClips);

    if(count == 0)
        return;

    if(clipIndex < 0)
        clipIndex = 0;

    if(clipIndex >= count)
        clipIndex = count - 1;

    FlushSoundQueue();

    gRunStartClip = clipIndex;
    gNextClipToQueue = clipIndex + 1;
    gWaitingForFinish = FALSE;

    llResetTime();
    gRunStartTime = llGetTime();

    llPlaySound(
        llList2String(gClips, clipIndex),
        EffectiveVolume());

    if(gNextClipToQueue < count)
    {
        llSetTimerEvent(QUEUE_LEAD_TIME);
        PreloadClip(gNextClipToQueue);
    }
    else
    {
        gWaitingForFinish = TRUE;
        llSetTimerEvent(gLastClipLength);
    }
}


//==============================================================
// TRANSPORT
//==============================================================

StartSong()
{
    if(!gDatabaseReady)
    {
        Debug("Library is not ready.");
        return;
    }

    if(!gSongLoaded)
    {
        Debug("No valid song is loaded.");
        return;
    }

    gState = STATE_PLAYING;
    NotifyState();

    BeginPlaybackAt(0);
}

PlaySpecificSong(integer songID)
{
    if(!gDatabaseReady)
    {
        Debug("Library is not ready.");
        return;
    }

    FlushSoundQueue();

    gSongLoaded = FALSE;
    gState = STATE_STOPPED;
    NotifyState();

    RequestSong(songID, TRUE);
}

StopSong()
{
    FlushSoundQueue();

    gRunStartClip = 0;
    gNextClipToQueue = 0;
    gWaitingForFinish = FALSE;

    gState = STATE_STOPPED;
    NotifyState();
}

integer EstimatePlayingClip()
{
    float elapsed = llGetTime() - gRunStartTime;

    if(elapsed < 0.0)
        elapsed = 0.0;

    integer clipIndex =
        gRunStartClip
        + (integer)(elapsed / CLIP_LENGTH);

    integer lastClip =
        llGetListLength(gClips) - 1;

    if(clipIndex > lastClip)
        clipIndex = lastClip;

    if(clipIndex < 0)
        clipIndex = 0;

    return clipIndex;
}

PauseSong()
{
    if(gState != STATE_PLAYING)
        return;

    integer pausedClip = EstimatePlayingClip();

    FlushSoundQueue();

    gRunStartClip = pausedClip;
    gNextClipToQueue = pausedClip + 1;
    gWaitingForFinish = FALSE;

    gState = STATE_PAUSED;
    NotifyState();

    Debug(
        "Paused at clip "
        + (string)(pausedClip + 1)
        + ".");
}

ResumeSong()
{
    if(gState != STATE_PAUSED)
        return;

    gState = STATE_PLAYING;
    NotifyState();

    BeginPlaybackAt(gRunStartClip);
}


//==============================================================
// TRACK NAVIGATION
//==============================================================

RequestSongCount()
{
    llMessageLinked(
        LINK_SET,
        API_DB_REQUEST,
        "SONG_COUNT",
        NULL_KEY);
}

PlayNextSong()
{
    if(!gDatabaseReady)
    {
        Debug("Library is not ready.");
        return;
    }

    if(gSongCount < 1)
    {
        Debug("Song count is not available.");
        RequestSongCount();
        return;
    }

    integer nextSong = gCurrentSongID + 1;

    if(nextSong > gSongCount)
        nextSong = 1;

    PlaySpecificSong(nextSong);
}

PlayPreviousSong()
{
    if(!gDatabaseReady)
    {
        Debug("Library is not ready.");
        return;
    }

    if(gSongCount < 1)
    {
        Debug("Song count is not available.");
        RequestSongCount();
        return;
    }

    integer previousSong = gCurrentSongID - 1;

    if(previousSong < 1)
        previousSong = gSongCount;

    PlaySpecificSong(previousSong);
}


//==============================================================
// QUEUE TIMER
//==============================================================

HandleQueueTimer()
{
    integer count = llGetListLength(gClips);

    if(gWaitingForFinish)
    {
        llSetTimerEvent(0.0);
        gWaitingForFinish = FALSE;

        // Clear any residual queued sound before changing songs.
        FlushSoundQueue();

        Debug("Song finished.");

        // Natural completion advances through the library.
        PlayNextSong();
        return;
    }

    if(gNextClipToQueue >= count)
    {
        gWaitingForFinish = TRUE;
        llSetTimerEvent(gLastClipLength + QUEUE_TAIL_TIME);
        return;
    }

    string clipUUID =
        llList2String(
            gClips,
            gNextClipToQueue);

    if(IsValidSoundUUID(clipUUID))
        llPlaySound(clipUUID, EffectiveVolume());
    else
        Debug(
            "Skipped invalid queued clip "
            + (string)(gNextClipToQueue + 1)
            + ".");

    ++gNextClipToQueue;

    if(gNextClipToQueue < count)
    {
        llSetTimerEvent(CLIP_LENGTH);
        PreloadClip(gNextClipToQueue);
    }
    else
    {
        gWaitingForFinish = TRUE;
        llSetTimerEvent(gLastClipLength + QUEUE_TAIL_TIME);
    }
}


//==============================================================
// DEFAULT STATE
//==============================================================

default
{
    state_entry()
    {
        llSetSoundQueueing(TRUE);

        Debug(
            "Build 5.2T1 — 19.8 Second Timing Test");

        NotifyState();
    }

    timer()
    {
        if(gState == STATE_PLAYING)
            HandleQueueTimer();
    }

    link_message(
        integer sender,
        integer num,
        string message,
        key id)
    {
        if(num == API_DB_READY)
        {
            gDatabaseReady = TRUE;

            Debug("Library ready.");

            RequestSongCount();
            RequestSong(1, FALSE);
            return;
        }

        if(num == API_DB_REPLY)
        {
            if(llSubStringIndex(message, "SONG_COUNT|") == 0)
            {
                gSongCount =
                    (integer)llGetSubString(
                        message,
                        11,
                        -1);

                return;
            }

            LoadSongPacket(message);
            return;
        }

        if(num == API_ENGINE_PLAY)
        {
            StartSong();
            return;
        }

        if(num == API_ENGINE_PLAY_SONG)
        {
            PlaySpecificSong((integer)message);
            return;
        }

        if(num == API_ENGINE_VOLUME)
        {
            SetUserVolume((float)message);
            return;
        }

        if(num == API_ENGINE_NEXT)
        {
            PlayNextSong();
            return;
        }

        if(num == API_ENGINE_PREV)
        {
            PlayPreviousSong();
            return;
        }

        if(num == API_ENGINE_STOP)
        {
            StopSong();
            return;
        }

        if(num == API_ENGINE_PAUSE)
        {
            PauseSong();
            return;
        }

        if(num == API_ENGINE_RESUME)
        {
            ResumeSong();
            return;
        }
    }

    on_rez(integer start)
    {
        llResetScript();
    }
}

