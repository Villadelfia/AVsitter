/*
 * [AV]root-RLV - RLV plugin for AVsitter
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright © the AVsitter Contributors (http://avsitter.github.io)
 * AVsitter™ is a trademark. For trademark use policy see:
 * https://avsitter.github.io/TRADEMARK.mediawiki
 *
 * Please consider supporting continued development of AVsitter and
 * receive automatic updates and other benefits! All details and user
 * instructions can be found at http://avsitter.github.io
 */

string product = "AVsitter™ RLV";
string #version = "2.2p04";
integer ignorenextswap;
string notecard_name = "AVpos";
string unDressScript = "[AV]root-RLV-extra";
string main_script = "[AV]sitA";
string Dominant_name = "Dominant";
string Submissive_name = "Submissive";
string Submissive_name_plural = "submissives";
integer RLV_ON = TRUE;
string WAITPOSE;
string DOMPOSE;
string SUBPOSE;
integer HTEXT = 1;
list SITTER_DESIGNATIONS_MASTER = ["S"];
list DESIGNATIONS_NOW;
string onTouch = "ASK";
string onSit = "CAPTURE";
integer autoRecapture;
key notecard_key;
key notecard_query;
integer notecard_line;
integer RELAY_CHANNEL = -1812221819;
integer RELAY_SEARCH_CHANNEL;
integer RELAY_GETCAPTURESTATUSchannel;
integer RELAY_CHECK_CHANNEL;
integer ASKROLE_CHANNEL = -748363;
integer menu_channel;
integer menu_handle;
integer relay_handle;
integer GETCAPTURESTATUShandle;
integer SEARCHhandle;
integer CHECKhandle;
integer ASKROLEhandle;
list DETECTED_AVATAR_SHORTNAMES;
list DETECTED_AVATAR_KEYS = [WAITPOSE]; //OSS::list DETECTED_AVATAR_KEYS; // Force error in LSO
integer awaiting_results;
string baseCaptureRestrictions = "@unsit=n";
string baseReleaseRestrictions = "@unsit=force";
integer expected_number;
integer expecting_relay_results;
integer controllerHasKeys;
string PairWhoStartedCapture = "NA";
integer defaultTimelock;
integer TimelockSecUntilRelease;
integer TimelockHidden;
integer TimelockPaused;
key CONTROLLER = "";
string controllerName;
key SLAVE;
string slaveName;
integer slaveWearingRelay;
list CAPTIVES;
list SITTERS;
list SITTING_AVATARS;
list SITTERS_MENUKEYS;
list SITTERS_SHORTNAMES;
integer activePrim;
string menu;
integer menuPage;
integer subControl;
string ping;
integer captureOnAsk = TRUE;
integer verbose = 0;

Out(integer level, string out)
{
    if (verbose >= level)
    {
        llOwnerSay(llGetScriptName() + "[" + version + "]:" + out);
    }
}

string strReplace(string str, string search, string replace)
{
    return llDumpList2String(llParseStringKeepNulls(str, [search], []), replace);
}

list order_buttons(list buttons)
{
    return llList2List(buttons, -3, -1) + llList2List(buttons, -6, -4) + llList2List(buttons, -9, -7) + llList2List(buttons, -12, -10);
}

relay(key av, string msg)
{
    msg = "RLV," + (string)av + "," + msg;
    llSay(RELAY_CHANNEL, msg);
}

string humantime()
{
    integer hours = TimelockSecUntilRelease / 3600;
    integer minutes = TimelockSecUntilRelease % 3600;
    integer seconds = minutes % 60;
    minutes = minutes / 60;
    string hours_text;
    string minutes_text;
    string seconds_text;
    if (hours)
    {
        hours_text = (string)hours + " hrs, ";
    }
    if (minutes || hours)
    {
        minutes_text = (string)minutes + " min";
    }
    if (!hours)
    {
        if (minutes)
        {
            seconds_text += ", ";
        }
        seconds_text += (string)seconds + " sec";
    }
    return hours_text + minutes_text + seconds_text;
}

Timelock_menu()
{
    menu = "Timelock";
    list menu_items = ["+1min", "+30min", "+1hrs"];
    string text = "Time Remaining: " + humantime() + "\n";
    string pauseButton = " ";
    string hidButton = " ";
    if (TimelockSecUntilRelease)
    {
        pauseButton = "Stop";
        if (TimelockPaused)
        {
            pauseButton = "Start";
            text += "\nTimelock Stopped";
            if (TimelockSecUntilRelease)
            {
                menu_items += ["-1min", "-30min", "-1hrs"];
            }
        }
        if (!TimelockPaused)
        {
            hidButton = "Hide";
            if (TimelockHidden)
            {
                hidButton = "Show";
                text += "\nTimelock Hidden";
            }
        }
    }
    dialog(text, ["[BACK]", pauseButton, hidButton] + menu_items);
}

relay_select_menu()
{
    menu = "SELECT";
    list menu_items;
    integer i;
    for (i = 0; i < llGetListLength(DETECTED_AVATAR_KEYS); i++)
    {
        if (llListFindList(SITTING_AVATARS, [llList2Key(DETECTED_AVATAR_KEYS, i)]) == -1)
        {
            menu_items += llList2String(DETECTED_AVATAR_SHORTNAMES, i);
        }
    }
    string text = "No RLV relays found in range!";
    if (llGetListLength(menu_items))
    {
        text = "Who do you want to capture?\n\nRLV relays found on:\n";
    }
    if (CONTROLLER == llGetOwner() && (!llGetListLength(SITTING_AVATARS)))
    {
        menu_items += "[SECURITY]";
    }
    dialog(text, menu_items);
}

playpose(string pose, string target_sitter)
{
    if (pose != "")
    {
        llSleep(1);
        llMessageLinked(LINK_SET, 90000, pose, target_sitter);
    }
}

rlv_top_menu()
{
    menu = "";
    list menu_items;
    string text = "RLV for " + slaveName;
    list extra;
    if (llGetListLength(SITTING_AVATARS) > 1 || llListFindList(DESIGNATIONS_NOW, ["S"]) != -1)
    {
        extra += "[BACK]";
    }
    integer designationIndex = llListFindList(DESIGNATIONS_NOW, [SLAVE]);
    if (RLV_ON)
    {
        if (llListFindList(CAPTIVES, [SLAVE]) == -1)
        {
            if (slaveWearingRelay)
            {
                if (designationIndex != -1 && llList2String(SITTER_DESIGNATIONS_MASTER, designationIndex) == "D")
                {
                    text = slaveName + " has not chosen " + llToLower(Submissive_name) + " role.";
                }
                else
                {
                    menu_items += ["Capture!"];
                }
            }
            else
            {
                text = "No RLV relay found for " + slaveName + ".";
            }
        }
        else
        {
            menu_items += ["Timelock"];
            if (llGetInventoryType(unDressScript) == INVENTORY_SCRIPT)
            {
                menu_items += ["Restrict", "Un/Dress"];
            }
            menu_items += ["Release!"];
            if (controllerHasKeys)
                extra += ["Drop Keys"];
            else
                extra += ["Take Keys"];
        }
        if (llList2String(SITTER_DESIGNATIONS_MASTER, designationIndex) == "S")
        {
            if (llListFindList(SITTING_AVATARS, [CONTROLLER]) == -1)
            {
                menu_items += ["[STOP]"];
            }
            menu_items += ["Menu..."];
        }
    }
    else
    {
        text = "RLV is off.";
    }
    dialog(text, extra + menu_items);
}

capture_attempt(key id, string target_sitter)
{
    if (RLV_ON)
    {
        relay(id, baseCaptureRestrictions);
        llListenRemove(GETCAPTURESTATUShandle);
        GETCAPTURESTATUShandle = llListen(RELAY_GETCAPTURESTATUSchannel, "", "", "");
        relay(id, "@getstatus=" + (string)RELAY_GETCAPTURESTATUSchannel);
    }
    if (llGetInventoryType(main_script + " 1") == INVENTORY_SCRIPT)
    {
        playpose(SUBPOSE, target_sitter);
    }
    else
    {
        playpose(SUBPOSE, id);
    }
}

dialog(string text, list buttons)
{
    llDialog(CONTROLLER, product + " " + version + "\n\n" + text, order_buttons(buttons), menu_channel);
}

reset()
{
    CAPTIVES = [];
    CONTROLLER = "";
    controllerHasKeys = FALSE;
    TimelockHidden = FALSE;
    TimelockPaused = FALSE;
    llSetTimerEvent(0);
    TimelockSecUntilRelease = defaultTimelock;
    hovertext();
}

unsit_all()
{
    integer i = llGetNumberOfPrims();
    while (llGetAgentSize(llGetLinkKey(i)) != ZERO_VECTOR)
    {
        llUnSit(llGetLinkKey(i));
        i--;
    }
}

release_all()
{
    while (llGetListLength(CAPTIVES))
    {
        release(llList2Key(CAPTIVES, 1), FALSE);
    }
}

stop()
{
    release_all();
    unsit_all();
    reset();
}

release(key SLAVE, integer allowUnsit)
{
    integer index = llListFindList(CAPTIVES, [SLAVE]);
    if (index != -1)
    {
        CAPTIVES = llDeleteSubList(CAPTIVES, index - 1, index);
        llSay(0, llKey2Name(SLAVE) + " was released.");
        relay(SLAVE, baseReleaseRestrictions);
        relay(SLAVE, "!release");
        if (allowUnsit && llSubStringIndex(baseReleaseRestrictions, "@unsit=force") != -1)
        {
            llUnSit(SLAVE);
        }
    }
    if (!llGetListLength(CAPTIVES))
    {
        reset();
    }
}

start_relay_search()
{
    DETECTED_AVATAR_KEYS = [];
    DETECTED_AVATAR_SHORTNAMES = [];
    slaveWearingRelay = 0;
    llSensor("", NULL_KEY, AGENT, 20, PI);
    expecting_relay_results = TRUE;
    SEARCHhandle = llListen(RELAY_SEARCH_CHANNEL, "", "", "");
    llSetTimerEvent(1.5);
}

remove_script(string reason)
{
    string message = "\n" + llGetScriptName() + " ==Script Removed==\n\n" + reason;
    llDialog(llGetOwner(), message, ["OK"], -3675);
    llInstantMessage(llGetOwner(), message);
    if (llGetOwner() != "b30c9262-9abf-4cd1-9476-adcf5723c029" && llGetOwner() != "f2e0ed5e-6592-4199-901d-a659c324ca94")
    {
        llRemoveInventory(llGetScriptName());
    }
}

new_controller(key id)
{
    CONTROLLER = id;
    controllerName = llKey2Name(CONTROLLER);
    llListenRemove(menu_handle);
    menu_handle = llListen((menu_channel = ((integer)llFrand(0x7FFFFF80) + 1) * -1), "", CONTROLLER, ""); // 7FFFFF80 = max float < 2^31
}

no_sensor_results()
{
    expecting_relay_results = FALSE;
    list menu_items;
    if (CONTROLLER == llGetOwner())
    {
        menu_items += "[SECURITY]";
    }
    dialog("No avatars found in range!", menu_items);
}

get_unique_channels()
{
    RELAY_SEARCH_CHANNEL = (integer)llFrand(999999936) + 1; // 999999936 = max float < 1e9
    RELAY_GETCAPTURESTATUSchannel = RELAY_SEARCH_CHANNEL + 2;
    RELAY_CHECK_CHANNEL = RELAY_SEARCH_CHANNEL + 4;
    ASKROLE_CHANNEL = ((integer)llFrand(0x7FFFFF80) + 1) * -1; // 7FFFFF80 = max float < 2^31
    llListenRemove(relay_handle);
    relay_handle = llListen(RELAY_CHANNEL, "", "", (ping = "ping," + (string)llGetKey() + ",ping,ping"));
}

check_submissive()
{
    relay(SLAVE, "@versionnew=" + (string)RELAY_CHECK_CHANNEL);
    slaveWearingRelay = -1;
    llSensorRepeat("", llGetOwner(), PASSIVE, 0.1, PI, 2);
    slaveName = llKey2Name(SLAVE);
}

select_submissive_rlv()
{
    menu = "SUB_SELECT";
    string text = "Which " + llToLower(Submissive_name) + "?";
    SITTERS_MENUKEYS = [];
    list menu_items;
    integer i;
    for (i = 0; i < llGetListLength(SITTER_DESIGNATIONS_MASTER); i++)
    {
        if (llList2String(SITTER_DESIGNATIONS_MASTER, i) == "S")
        {
            if (llList2Key(DESIGNATIONS_NOW, i)) // OSS::key k = llList2Key(DESIGNATIONS_NOW, i); if (osIsUUID(k) && k != NULL_KEY)
            {
                menu_items += llGetSubString(strReplace(llKey2Name(llList2Key(DESIGNATIONS_NOW, i)), " Resident", ""), 0, 11);
                SITTERS_MENUKEYS += llList2Key(DESIGNATIONS_NOW, i);
            }
        }
    }
    SITTERS_SHORTNAMES = menu_items;
    if (!llGetListLength(menu_items))
    {
        text = "There are no " + llToLower(Submissive_name_plural) + " sitting.";
    }
    if (llListFindList(DESIGNATIONS_NOW, ["S"]) != -1 && llGetListLength(SITTING_AVATARS) < llGetListLength(DESIGNATIONS_NOW))
    {
        text += "\n\nCapture = trap a new avatar.";
        menu_items += "Capture...";
    }
    else if (llGetListLength(menu_items) == 1)
    {
        SLAVE = llList2Key(SITTERS_MENUKEYS, 0);
        check_submissive();
        return;
    }
    dialog(text, menu_items);
}

find_seat(key id, integer index, string msg, integer captureSub)
{
    if (index != -1)
    {
        if (msg == Dominant_name || msg == "D")
            msg = "D";
        else
            msg = "S";
        integer first_available = index;
        if (llListFindList(DESIGNATIONS_NOW, [id]) != -1)
        {
            first_available = llListFindList(DESIGNATIONS_NOW, [id]);
        }
        else if (llList2String(DESIGNATIONS_NOW, index) != msg)
        {
            first_available = llListFindList(DESIGNATIONS_NOW, [msg]);
        }
        if (first_available != -1)
        {
            if (msg == "D")
            {
                playpose(DOMPOSE, (string)first_available);
            }
            else //if (msg == "S") // assumed
            {
                if (captureSub)
                {
                    capture_attempt(id, (string)first_available);
                }
            }
            if (first_available != index)
            {
                if (llGetInventoryType(main_script + " 1") == INVENTORY_SCRIPT)
                {
                    llSleep(1);
                    llMessageLinked(LINK_SET, 90030, (string)index, (string)first_available);
                    ignorenextswap = TRUE;
                }
            }
            DESIGNATIONS_NOW = llListReplaceList(DESIGNATIONS_NOW, [id], first_available, first_available);
            if (llListFindList(DESIGNATIONS_NOW, ["S"]) == -1)
            {
                integer i = llGetListLength(CAPTIVES) - 1;
                while (i > 0)
                {
                    if (llListFindList(SITTING_AVATARS, [llList2Key(CAPTIVES, i)]) == -1)
                    {
                        CAPTIVES = llDeleteSubList(CAPTIVES, i - 1, i);
                    }
                    i -= 2;
                }
            }
            hovertext();
            llMessageLinked(LINK_THIS, 90206, llDumpList2String(DESIGNATIONS_NOW, "|"), "");
            if (msg == "D")
            {
                llSleep(1);
                llMessageLinked(LINK_THIS, 90007, "", id);
            }
        }
        else
        {
            llUnSit(id);
            if (msg == "D")
                msg = Dominant_name;
            else
                msg = Submissive_name;
            info_dialog(id, "there no available seats for " + msg);
        }
    }
}

info_dialog(key id, string text)
{
    llDialog(id, product + " " + version + "\n\nSorry, " + text + ".\n", ["OK"], -7947386);
}

hovertext()
{
    string text;
    vector color = <0,1,0>;
    if (llGetListLength(CAPTIVES))
    {
        string s;
        if (llGetListLength(CAPTIVES) > 2)
        {
            s = "s";
        }
        text += "\n \nCaptive" + s + ":\n";
        integer i;
        for (i = 0; i < llGetListLength(CAPTIVES); i += 2)
        {
            string captiveName = llList2String(CAPTIVES, i);
            key captiveUUID = (key)llList2String(CAPTIVES, i + 1);
            text += "\"" + captiveName + "\"\n";
        }
        if (TimelockSecUntilRelease)
        {
            if (TimelockPaused)
            {
            }
            else if (llGetListLength(SITTING_AVATARS) && llGetListLength(CAPTIVES))
            {
                text += "\n \nTimelocked for:\n";
                if (TimelockHidden)
                {
                    text += "(hidden)";
                }
                else
                {
                    text += humantime();
                }
            }
        }
        if (!controllerHasKeys)
        {
            text += "\n \nKeys available";
        }
        if (controllerHasKeys)
        {
            color = <1,0,0>;
            text += "\n \nLocked by:\n\"" + controllerName + "\"";
        }
    }
    if (HTEXT)
    {
        integer i = 1;
        while (i++ < HTEXT)
        {
            text += "\n ";
        }
        llSetText(text, color, 0.8);
    }
    else
    {
        llMessageLinked(LINK_SET, 90207, text, (string)color);
    }
    llMessageLinked(LINK_SET, 90014, llDumpList2String([CONTROLLER, llDumpList2String(CAPTIVES, ",")], "|"), "");
}

ask_role(key id)
{
    llDialog(id, product + " " + version + "\n\nPlease select your role:\n", [Dominant_name, Submissive_name], ASKROLE_CHANNEL);
}

back(key id)
{
    if (llListFindList(SITTING_AVATARS, [id]) != -1)
    {
        llMessageLinked(LINK_SET, 90005, "", id);
    }
    else
    {
        llMessageLinked(LINK_THIS, 90007, "", id);
    }
}

integer isSub(key id)
{
    integer index = llListFindList(DESIGNATIONS_NOW, [id]);
    if (index != -1)
    {
        if (llList2String(SITTER_DESIGNATIONS_MASTER, index) == "S")
        {
            info_dialog(id, Submissive_name_plural + " can't access this");
            return TRUE;
        }
    }
    return FALSE;
}

default
{
    state_entry()
    {
        if (llSubStringIndex(llGetScriptName(), " ") != -1)
        {
            remove_script("Use only one copy of this script!");
        }
        else
        {
            state running;
        }
    }
}

state running
{
    state_entry()
    {
        llSetTimerEvent(0);
        hovertext();
        get_unique_channels();
        notecard_key = llGetInventoryKey(notecard_name);
        if (llGetInventoryType(notecard_name) == INVENTORY_NOTECARD)
        {
            notecard_query = llGetNotecardLine(notecard_name, 0);
        }
    }

    link_message(integer sender, integer num, string msg, key id)
    {
        integer one = (integer)msg;
        integer two;
        if (num == 90030)
        {
            if (!ignorenextswap)
            {
                two = (integer)((string)id);
                key des1 = llList2String(DESIGNATIONS_NOW, one);
                key des2 = llList2String(DESIGNATIONS_NOW, two);
                string role1 = llList2String(SITTER_DESIGNATIONS_MASTER, one);
                string role2 = llList2String(SITTER_DESIGNATIONS_MASTER, two);
                if (role1 != role2)
                {
                    release_all();
                }
                if (des1) // OSS::if (osIsUUID(des1) && des1 != NULL_KEY)
                {
                    DESIGNATIONS_NOW = llListReplaceList(DESIGNATIONS_NOW, [des1], two, two);
                }
                else
                {
                    DESIGNATIONS_NOW = llListReplaceList(DESIGNATIONS_NOW, [role2], two, two);
                }
                if (des2) // OSS::if (osIsUUID(des2) && des2 != NULL_KEY)
                {
                    DESIGNATIONS_NOW = llListReplaceList(DESIGNATIONS_NOW, [des2], one, one);
                }
                else
                {
                    DESIGNATIONS_NOW = llListReplaceList(DESIGNATIONS_NOW, [role1], one, one);
                }
                llMessageLinked(LINK_THIS, 90206, llDumpList2String(DESIGNATIONS_NOW, "|"), "");
            }
            ignorenextswap = FALSE;
        }
        else if (num == 90045)
        {
            if (sender == llGetLinkNumber())
            {
                list data = llParseStringKeepNulls(msg, ["|"], []);
                SITTERS = llParseStringKeepNulls(llList2String(data, 4), ["@"], []);
            }
        }
        else if (num == 90060)
        {
            menu = "";
            SITTING_AVATARS += id;
            // If they must be assigned a SUB spot, regardless of the
            // automatically assigned sitter, lock them as they sit.
            // That happens with ONSIT CAPTURE and with force-sitting.
            if (onSit == "CAPTURE" || (string)CONTROLLER + (string)id == PairWhoStartedCapture)
            {
                if (llListFindList(DESIGNATIONS_NOW, ["S"]) != -1)
                {
                    find_seat(id, one, Submissive_name, TRUE);
                }
            }
        }
        else if (num == 90070)
        {
            // This is the first message where we know the sitter number
            if (llListFindList(DESIGNATIONS_NOW, [id]) == -1)
            {
                if (onSit == "CAPIFSUB")
                {
                    find_seat(id, one, llList2String(DESIGNATIONS_NOW, one), TRUE);
                }
                else if (onSit == "ASK")
                {
                    ask_role(id);
                }
                else if (onSit == "NONE")
                {
                    DESIGNATIONS_NOW = llListReplaceList(DESIGNATIONS_NOW, [id], one, one);
                }
            }
        }
        else if (num == 90065)
        {
            playpose(WAITPOSE, msg);
            integer index = llListFindList(SITTING_AVATARS, [id]);
            if (index != -1)
            {
                SITTING_AVATARS = llDeleteSubList(SITTING_AVATARS, index, index);
            }
            index = llListFindList(DESIGNATIONS_NOW, [id]);
            if (index != -1)
            {
                DESIGNATIONS_NOW = llListReplaceList(DESIGNATIONS_NOW, llList2List(SITTER_DESIGNATIONS_MASTER, index, index), index, index);
                llMessageLinked(LINK_THIS, 90206, llDumpList2String(DESIGNATIONS_NOW, "|"), "");
            }
        }
        else if (num == 90012)
        {
            if (llListFindList(CAPTIVES, [id]) != -1)
            {
                if (subControl)
                {
                    llMessageLinked(LINK_THIS, 90007, "", id);
                }
                else
                {
                    info_dialog(id, "captives can't access the menu. Enjoy your captivity :)");
                }
                return;
            }
            activePrim = (integer)msg;
            if (!llGetListLength(SITTING_AVATARS))
            {
                if (controllerHasKeys && id != CONTROLLER)
                {
                    reset();
                }
                if (onTouch == "NONE")
                {
                    return;
                }
                else if (onTouch == "CAPTURE")
                {
                    relay(id, "@sit:" + (string)llGetLinkKey(activePrim) + "=force");
                    CONTROLLER = id;
                    PairWhoStartedCapture = (string)CONTROLLER + (string)id;
                    return;
                }
            }
            else
            {
                integer designationIndex = llListFindList(DESIGNATIONS_NOW, [id]);
                integer isSittingIndex = llListFindList(SITTING_AVATARS, [id]);
                if (isSittingIndex != -1)
                {
                    if (RLV_ON && designationIndex != -1 && llList2String(SITTER_DESIGNATIONS_MASTER, designationIndex) == "S")
                    {
                        if (subControl)
                        {
                            llMessageLinked(LINK_THIS, 90007, "", id);
                        }
                        else
                        {
                            info_dialog(id, Submissive_name_plural + " can't access the menu");
                        }
                        return;
                    }
                    if (onSit == "ASK")
                    {
                        if (designationIndex == -1)
                        {
                            ask_role(id);
                            return;
                        }
                    }
                }
                else
                {
                    integer i;
                    for (i = 0; i < llGetListLength(SITTER_DESIGNATIONS_MASTER); i++)
                    {
                        if (llList2String(SITTER_DESIGNATIONS_MASTER, i) == "D")
                        {
                            if (llList2String(DESIGNATIONS_NOW, i) != "D")
                            {
                                return;
                            }
                        }
                    }
                }
                if (controllerHasKeys && id != CONTROLLER)
                {
                    if (isSittingIndex != -1)
                    {
                        if (llList2String(SITTER_DESIGNATIONS_MASTER, designationIndex) == "D")
                        {
                            llMessageLinked(LINK_THIS, 90007, "", id);
                            return;
                        }
                    }
                    info_dialog(id, "this item is locked by " + controllerName);
                    return;
                }
            }
            llMessageLinked(LINK_THIS, 90007, "", id);
        }
        else if (num == 90100)
        {
            list data = llParseString2List(msg, ["|"], []);
            if (llList2String(data, 1) == "[STOP]")
            {
                if (isSub(id))
                    return;
                stop();
            }
            else if (llList2String(data, 1) == "Control...")
            {
                if (isSub(id))
                    return;
                if (controllerHasKeys && id != CONTROLLER)
                {
                    info_dialog(id, "this item is locked by " + controllerName);
                    return;
                }
                new_controller(id);
                if ((key)llList2String(data, 2) == id)
                {
                    select_submissive_rlv();
                    return;
                }
                SLAVE = (key)llList2String(data, 2);
                check_submissive();
            }
        }
        else if (num == 90201)
        {
            playpose(WAITPOSE, "");
        }
        else if (num == 90211)
        {
            if (llListFindList(DESIGNATIONS_NOW, ["S"]) != -1)
            {
                new_controller(id);
                start_relay_search();
            }
        }
    }

    listen(integer channel, string name, key id, string msg)
    {
        if (channel == ASKROLE_CHANNEL)
        {
            if (llListFindList(SITTING_AVATARS, [id]) != -1)
            {
                integer index = llListFindList(SITTERS, [(string)id]);
                find_seat(id, index, msg, captureOnAsk);
            }
        }
        else if (channel == RELAY_GETCAPTURESTATUSchannel)
        {
            key newSlave = llGetOwnerKey(id);
            string newSlaveName = llKey2Name(newSlave);
            if (llListFindList(SITTING_AVATARS, [newSlave]) != -1)
            {
                if (!llGetListLength(CAPTIVES))
                {
                    TimelockSecUntilRelease = defaultTimelock;
                }
                llSay(0, newSlaveName + " was captured!");
                if (llListFindList(CAPTIVES, [newSlave]) == -1)
                {
                    CAPTIVES += [newSlaveName, newSlave];
                    if (llGetListLength(CAPTIVES) / 2 > llGetListLength(DESIGNATIONS_NOW))
                    {
                        CAPTIVES = llDeleteSubList(CAPTIVES, 0, 1);
                    }
                }
                llSetTimerEvent(1);
                if (PairWhoStartedCapture == (string)CONTROLLER + (string)newSlave)
                {
                    PairWhoStartedCapture = "NA";
                    hovertext();
                }
                else
                {
                    if (CONTROLLER == newSlave)
                    {
                        controllerHasKeys = FALSE;
                        CONTROLLER = "";
                    }
                    TimelockPaused = FALSE;
                }
            }
        }
        else if (channel == RELAY_CHANNEL)
        {
            if (msg == ping)
            {
                integer index = llListFindList(CAPTIVES, [llGetOwnerKey(id)]);
                if (index != -1)
                {
                    if (autoRecapture)
                    {
                        if (llListFindList(DESIGNATIONS_NOW, ["S"]) != -1)
                        {
                            if (CONTROLLER) // OSS::if (osIsUUID(CONTROLLER) && CONTROLLER != NULL_KEY)
                            {
                                PairWhoStartedCapture = (string)CONTROLLER + (string)llGetOwnerKey(id);
                            }
                            string pong = "ping," + (string)llGetOwnerKey(id) + ",!pong";
                            llRegionSay(RELAY_CHANNEL, pong);
                            return;
                        }
                    }
                    CAPTIVES = llDeleteSubList(CAPTIVES, index - 1, index);
                }
            }
        }
        else if (channel == RELAY_CHECK_CHANNEL)
        {
            slaveWearingRelay = 1;
            rlv_top_menu();
            llSensorRemove();
        }
        else if (channel == RELAY_SEARCH_CHANNEL && expecting_relay_results)
        {
            key relay_owner = llGetOwnerKey(id);
            if (llListFindList(DETECTED_AVATAR_KEYS, [relay_owner]) == -1)
            {
                DETECTED_AVATAR_KEYS += relay_owner;
                DETECTED_AVATAR_SHORTNAMES += llGetSubString(strReplace(llKey2Name(relay_owner), " Resident", ""), 0, 11);
                if (llGetListLength(DETECTED_AVATAR_KEYS) == expected_number)
                {
                    llSetTimerEvent(0.01);
                }
            }
        }
        else if (channel == menu_channel)
        {
            if (msg == "[SECURITY]")
            {
                llMessageLinked(LINK_THIS, 90100, "0|[SECURITY]", llGetOwner());
            }
            else if (msg == "[BACK]")
            {
                if (menu != "")
                {
                    rlv_top_menu();
                }
                else
                {
                    back(id);
                }
            }
            else if (menu == "SUB_SELECT")
            {
                integer index = llListFindList(SITTERS_SHORTNAMES, [msg]);
                if (index != -1)
                {
                    SLAVE = llList2Key(SITTERS_MENUKEYS, index);
                    check_submissive();
                }
                else if (msg == "Capture...")
                {
                    start_relay_search();
                }
            }
            else if (menu == "SELECT")
            {
                integer index = llListFindList(DETECTED_AVATAR_SHORTNAMES, [msg]);
                if (index != -1)
                {
                    if (llList2String(DETECTED_AVATAR_KEYS, index) == CONTROLLER)
                    {
                        info_dialog(CONTROLLER, "you can not capture yourself");
                    }
                    else
                    {
                        if (RLV_ON)
                        {
                            controllerHasKeys = TRUE;
                        }
                        TimelockPaused = TRUE;
                        llSetTimerEvent(0);
                        PairWhoStartedCapture = (string)CONTROLLER + llList2String(DETECTED_AVATAR_KEYS, index);
                        if (llListFindList(SITTING_AVATARS, [llList2Key(DETECTED_AVATAR_KEYS, index)]) != -1)
                        {
                            capture_attempt(llList2Key(DETECTED_AVATAR_KEYS, index), "");
                        }
                        else
                        {
                            key linkkey = (string)llGetLinkKey(activePrim);
                            if (linkkey == NULL_KEY)
                            {
                                linkkey = llGetKey();
                            }
                            relay(llList2Key(DETECTED_AVATAR_KEYS, index), "@sit:" + (string)linkkey + "=force");
                        }
                    }
                }
            }
            else if (menu == "Timelock")
            {
                integer plusMinus;
                if (llGetSubString(msg, 0, 0) == "-")
                    plusMinus = -1;
                else if (llGetSubString(msg, 0, 0) == "+")
                    plusMinus = 1;
                if (plusMinus)
                {
                    integer timechange = (integer)llGetSubString(msg, 1, -4) * 60;
                    if (llGetSubString(msg, -3, -1) == "hrs")
                    {
                        timechange *= 60;
                    }
                    timechange *= plusMinus;
                    TimelockSecUntilRelease += timechange;
                    if (TimelockSecUntilRelease < 0)
                    {
                        TimelockSecUntilRelease = 0;
                    }
                }
                else if (msg == "Stop" || msg == "Start")
                {
                    TimelockPaused = !TimelockPaused;
                    llSetTimerEvent(1);
                }
                else if (msg == "Hide" || msg == "Show")
                {
                    TimelockHidden = !TimelockHidden;
                }
                else
                {
                    return;
                }
                Timelock_menu();
            }
            else if (msg == "[STOP]")
            {
                stop();
            }
            else if (msg == "Menu...")
            {
                llMessageLinked(LINK_SET, 90004, "", llDumpList2String([id, SLAVE], "|"));
            }
            else if (msg == "Un/Dress")
            {
                llMessageLinked(LINK_THIS, 90208, "", llDumpList2String([SLAVE, CONTROLLER, msg], "|"));
            }
            else if (msg == "Restrict")
            {
                llMessageLinked(LINK_THIS, 90209, "", llDumpList2String([SLAVE, CONTROLLER, msg], "|"));
            }
            else if (msg == "Take Keys")
            {
                controllerHasKeys = TRUE;
                rlv_top_menu();
                llSay(0, controllerName + " takes the keys.");
            }
            else if (msg == "Drop Keys")
            {
                controllerHasKeys = FALSE;
                rlv_top_menu();
                llSay(0, controllerName + " relinquishes the keys.");
            }
            else if (msg == "Timelock")
            {
                Timelock_menu();
            }
            else if (msg == "Capture!")
            {
                controllerHasKeys = TRUE;
                TimelockPaused = TRUE;
                llSetTimerEvent(0);
                PairWhoStartedCapture = (string)CONTROLLER + (string)SLAVE;
                integer index = llListFindList(SITTERS, [(string)SLAVE]);
                if (index == -1)
                {
                    index = 0;
                }
                find_seat(SLAVE, index, Submissive_name, TRUE);
                check_submissive();
            }
            else if (msg == "Release!")
            {
                release(SLAVE, TRUE);
                CONTROLLER = id;
            }
            hovertext();
        }
    }

    no_sensor()
    {
        if (slaveWearingRelay)
        {
            slaveWearingRelay++;
            if (!slaveWearingRelay)
            {
                rlv_top_menu();
                llSensorRemove();
            }
        }
        else
        {
            no_sensor_results();
        }
    }

    sensor(integer total_number)
    {
        expected_number = total_number;
        integer i;
        while (i < total_number && i < 10)
        {
            relay(llDetectedKey(i), "@versionnew=" + (string)RELAY_SEARCH_CHANNEL);
            i++;
        }
        if (!expected_number)
        {
            no_sensor_results();
        }
    }

    timer()
    {
        llSetTimerEvent(1);
        if (!llGetListLength(SITTING_AVATARS))
        {
            llSetTimerEvent(0);
        }
        if (TimelockPaused)
        {
            llSetTimerEvent(0);
        }
        else
        {
            if (TimelockSecUntilRelease)
            {
                TimelockSecUntilRelease--;
                if (!TimelockSecUntilRelease)
                {
                    integer i = llGetListLength(CAPTIVES);
                    if (i > 0)
                    {
                        i--;
                        while (i >= 0)
                        {
                            key SLAVE = llList2Key(CAPTIVES, i);
                            if (llListFindList(SITTING_AVATARS, [SLAVE]) != -1)
                            {
                                release(SLAVE, TRUE);
                            }
                            i -= 2;
                        }
                    }
                    llSetTimerEvent(0);
                }
            }
            else
            {
                TimelockSecUntilRelease = defaultTimelock;
                llSetTimerEvent(0);
            }
        }
        hovertext();
        if (expecting_relay_results)
        {
            llListenRemove(RELAY_SEARCH_CHANNEL);
            expecting_relay_results = FALSE;
            relay_select_menu();
        }
    }

    changed(integer change)
    {
        if (change & CHANGED_LINK)
        {
            if (llGetAgentSize(llGetLinkKey(llGetNumberOfPrims())) == ZERO_VECTOR)
            {
                DESIGNATIONS_NOW = SITTER_DESIGNATIONS_MASTER;
                SITTING_AVATARS = [];
                llSetTimerEvent(0);
                llListenRemove(menu_handle);
                llListenRemove(ASKROLEhandle);
                llListenRemove(GETCAPTURESTATUShandle);
                llListenRemove(CHECKhandle);
                playpose(WAITPOSE, "");
            }
            else
            {
                ASKROLEhandle = llListen(ASKROLE_CHANNEL, "", "", "");
                CHECKhandle = llListen(RELAY_CHECK_CHANNEL, "", "", "");
            }
            hovertext();
        }
        if (change & CHANGED_INVENTORY)
        {
            if (notecard_key != llGetInventoryKey(notecard_name))
            {
                llResetScript();
            }
        }
    }

    dataserver(key query_id, string data)
    {
        if (query_id == notecard_query)
        {
            while (data != NAK)
            {
                if (data == EOF)
                {
                    Out(0, "Loaded, Memory: " + (string)llGetFreeMemory());
                    return;
                }
                else
                {
                    data = llStringTrim(data, STRING_TRIM);
                    string command = llGetSubString(data, 0, llSubStringIndex(data, " ") - 1);
                    list parts = llParseStringKeepNulls(llGetSubString(data, llSubStringIndex(data, " ") + 1, 99999), [" | ", " |", "| ", "|"], []);
                    string part0 = llStringTrim(llList2String(parts, 0), STRING_TRIM);
                    part0 = llGetSubString(part0, 0, 22);
                    if (command == "WAITPOSE")
                    {
                        WAITPOSE = part0;
                        playpose(WAITPOSE, "");
                    }
                    else if (command == "RLV")
                    {
                        RLV_ON = (integer)part0;
                    }
                    else if (command == "SUBCONTROL")
                    {
                        subControl = (integer)part0;
                    }
                    else if (command == "HTEXT")
                    {
                        HTEXT = (integer)part0;
                    }
                    else if (command == "DOMPOSE")
                    {
                        DOMPOSE = part0;
                    }
                    else if (command == "SUBPOSE")
                    {
                        SUBPOSE = part0;
                    }
                    else if (command == "ONTOUCH")
                    {
                        onTouch = part0;
                    }
                    else if (command == "ONSIT")
                    {
                        onSit = part0;
                        if (onSit == "ASKONLY")
                        {
                            onSit = "ASK";
                            captureOnAsk = FALSE;
                        }
                    }
                    else if (command == "BRAND")
                    {
                        product = part0;
                    }
                    else if (command == "RECAPTURE")
                    {
                        autoRecapture = (integer)part0;
                    }
                    else if (command == "ROLES")
                    {
                        SITTER_DESIGNATIONS_MASTER = parts;
                        DESIGNATIONS_NOW = SITTER_DESIGNATIONS_MASTER;
                        llMessageLinked(LINK_THIS, 90206, llDumpList2String(DESIGNATIONS_NOW, "|"), "");
                    }
                    else if (command == "TIMELOCK")
                    {
                        defaultTimelock = TimelockSecUntilRelease = (integer)part0 * 60;
                    }
                    else if (command == "ONCAPTURE")
                    {
                        baseCaptureRestrictions = llDumpList2String(parts, "|");
                    }
                    else if (command == "ONRELEASE")
                    {
                        baseReleaseRestrictions = llDumpList2String(parts, "|");
                    }
                    data = llGetNotecardLineSync(notecard_name, ++notecard_line);
                }
            }

            if (data == NAK)
            {
                notecard_query = llGetNotecardLine(notecard_name, notecard_line);
            }
        }
    }

    on_rez(integer start)
    {
        get_unique_channels();
    }
}
