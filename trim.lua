--
--  trim.lua
--  version 2021.03.01
--
--  AGPLv3 License
--  Created by github.com/aerobounce on 2019/11/18.
--  Copyright © 2019-present aerobounce. All rights reserved.
--
local utils = require "mp.utils"
local msg = require "mp.msg"
local assdraw = require "mp.assdraw"

-- ffmpeg path
if package.config:sub(1, 1) == "/" then
    -- macOS, *nix
    ffmpeg_bin = "ffmpeg"
else
    -- Windows
    ffmpeg_bin = "ffmpeg.exe"
end

local isVideoFile = false
local stripMetadata = false
local initialized = false
local startPosition = 0.0
local endPosition = 0.0

local function initializeIfNeeded()
    if initialized then
        return
    end
    initialized = true

    --
    -- mpv Settings
    --

    -- "track-list" is consistent against video on/off cycle.
    local videoTrack = mp.get_property_native("track-list")[1] or {}
    isVideoFile = videoTrack["type"] == "video" and videoTrack["albumart"] == "false"

    -- Settings suitable for trimming
    mp.commandv("script-message", "osc-visibility", "always")
    mp.set_property("pause", "yes")
    if isVideoFile then
        mp.set_property("hr-seek", "no")
    end
    mp.set_property("options/keep-open", "always")
    mp.register_event("eof-reached", function()
        msg.log("info", "Playback Reached End of File")
        mp.set_property("pause", "yes")
        mp.commandv("seek", 100, "absolute-percent", "exact")
    end)

    --
    -- Key Bindings
    --

    -- Toggle stripMetadata
    mp.add_forced_key_binding("t", "toggle-strip-metadata", function()
        stripMetadata = not stripMetadata
        local message = ""
        if stripMetadata then
            message ="trim: Strip Metadata Enabled"
        else
            message ="trim: Strip Metadata Disabled"
        end
        mp.osd_message(message, 3)
    end)

    if isVideoFile then
        -- Seeking by Keyframe
        local function seekByKeyframes(amount)
            mp.commandv("seek", amount, "keyframes", "exact")
            mp.command("show-progress")
            updateTrimmingPositionsOSDASS()
        end
        mp.add_forced_key_binding("LEFT", "-0.1_keyframes", function()
            seekByKeyframes(-0.1)
        end, {repeatable = true})
        mp.add_forced_key_binding("RIGHT", "0.1_keyframes", function()
            seekByKeyframes(0.1)
        end, {repeatable = true})
        mp.add_forced_key_binding("UP", "10_keyframes", function()
            seekByKeyframes(10)
        end, {repeatable = true})
        mp.add_forced_key_binding("DOWN", "-10_keyframes", function()
            seekByKeyframes(-10)
        end, {repeatable = true})

        -- Precise Seeking by Seconds
        local function seekBySeconds(amount)
            mp.commandv("seek", amount, "relative", "exact")
            mp.command("show-progress")
            updateTrimmingPositionsOSDASS()
        end
        mp.add_forced_key_binding("shift+LEFT", "-0.1_seconds", function()
            seekBySeconds(-0.1)
        end, {repeatable = true})
        mp.add_forced_key_binding("shift+RIGHT", "0.1_seconds", function()
            seekBySeconds(0.1)
        end, {repeatable = true})
        mp.add_forced_key_binding("shift+UP", "0.5_seconds", function()
            seekBySeconds(0.5)
        end, {repeatable = true})
        mp.add_forced_key_binding("shift+DOWN", "-0.5_seconds", function()
            seekBySeconds(-0.5)
        end, {repeatable = true})

        -- Seek to Default Trim Positions
        if isVideoFile then
            seekByKeyframes(-0.1)
            seekByKeyframes(0.1)
        end
    else
        -- Seeking by Seconds
        local function seekBySeconds(amount)
            mp.commandv("seek", amount, "relative")
            mp.command("show-progress")
            updateTrimmingPositionsOSDASS()
        end
        mp.add_forced_key_binding("LEFT", "-1_seconds", function()
            seekBySeconds(-1)
        end, {repeatable = true})
        mp.add_forced_key_binding("RIGHT", "1_seconds", function()
            seekBySeconds(1)
        end, {repeatable = true})
        mp.add_forced_key_binding("UP", "5_seconds", function()
            seekBySeconds(5)
        end, {repeatable = true})
        mp.add_forced_key_binding("DOWN", "-5_seconds", function()
            seekBySeconds(-5)
        end, {repeatable = true})

        mp.add_forced_key_binding("shift+LEFT", "-10_seconds", function()
            seekBySeconds(-10)
        end, {repeatable = true})
        mp.add_forced_key_binding("shift+RIGHT", "10_seconds", function()
            seekBySeconds(10)
        end, {repeatable = true})
        mp.add_forced_key_binding("shift+UP", "30_seconds", function()
            seekBySeconds(30)
        end, {repeatable = true})
        mp.add_forced_key_binding("shift+DOWN", "-30_seconds", function()
            seekBySeconds(-30)
        end, {repeatable = true})
    end

    -- Seek to Trimming Positions
    mp.add_forced_key_binding("shift+h", "seek-to-start-position", function()
        mp.commandv("seek", startPosition, "absolute")
        mp.command("show-progress")
        updateTrimmingPositionsOSDASS()
    end)
    mp.add_forced_key_binding("shift+k", "seek-to-end-position", function()
        mp.commandv("seek", endPosition, "absolute")
        mp.command("show-progress")
        updateTrimmingPositionsOSDASS()
    end)

    -- Show OSD
    showOsdAss("Enabled trim.lua")

    -- Set Default Trim Positions
    mp.add_timeout(0.5, function()
        -- If initialized by startPosition, trim should be startPosition to EOF.
        if startPosition ~= 0.0 then
            startPosition = mp.get_property_number("time-pos")
            endPosition = mp.get_property_native("duration")
            if startPosition == "none" then startPosition = 0.0 end

        -- If initialized by endPosition, trim should be 0.0 to endPosition.
        elseif endPosition ~= 0.0 then
            startPosition = 0.0
            if endPosition == "none" then endPosition = 0.0 end
        end

        updateTrimmingPositionsOSDASS()
    end)
end

local function getTrimmingPositionsText()
    local function formatSeconds(seconds)
        local formatted = string.format("%02d:%02d.%03d",
                                        math.floor(seconds / 60) % 60,
                                        math.floor(seconds) % 60,
                                        seconds * 1000 % 1000)
        if seconds > 3600 then
            formatted = string.format("%d:%s",
                                      math.floor(seconds / 3600),
                                      formatted)
        end
        return formatted
    end

    return "Trimming: " .. tostring(formatSeconds(startPosition, true)) ..
               " secs ~ " .. tostring(formatSeconds(endPosition, true)) ..
               " secs"
end

local function generateDestinationPath()
    local path = mp.get_property("path") or ""
    local filename = mp.get_property("filename/no-ext") or "encode"
    local extension = tostring(string.match(path, "%.([^.]+)$"))
    local destinationDirectory, _ = utils.split_path(path)
    local contents = utils.readdir(destinationDirectory)

    if not contents then
        return nil
    end

    local files = {}

    for _, f in ipairs(contents) do
        files[f] = true
    end

    local output = filename .. " $n." .. extension

    if not string.find(output, "$n") then
        return files[output] and nil or output
    end

    local i = 1

    while true do
        local potential_name = string.gsub(output, "$n", tostring(i))
        if not files[potential_name] then
            return destinationDirectory .. potential_name
        end
        i = i + 1
    end
end

function showOsdAss(message)
    msg.log("info", message)
    ass = assdraw.ass_new()
    ass:pos(10, 34)
    ass:append(message)
    mp.set_osd_ass(0, 0, ass.text)
end

function updateTrimmingPositionsOSDASS()
    mp.osd_message("", 1)
    showOsdAss(getTrimmingPositionsText())
end

function setStartPosition()
    initializeIfNeeded()

    if isVideoFile then
        -- Make sure current time-pos is a keyframes
        mp.commandv("seek", -0.01, "keyframes", "exact")
        mp.commandv("seek", 0.01, "keyframes", "exact")
    end

    local newPosition = mp.get_property_number("time-pos")

    if startPosition == newPosition then
        writeOut()
        return
    end

    startPosition = newPosition
    updateTrimmingPositionsOSDASS()
end

function setEndPosition()
    local newPosition = mp.get_property_number("time-pos")

    if endPosition == newPosition then
        writeOut()
        return
    end

    endPosition = newPosition
    initializeIfNeeded()
    updateTrimmingPositionsOSDASS()
end

function writeOut()
    --
    -- Error Handlings
    --
    if startPosition == nil or startPosition == "none" or endPosition == nil or
        endPosition == "none" then
        message = "trim: Error - Start or End Position is unassigned."
        mp.osd_message(message, 3)
    end

    if startPosition == endPosition then
        message = "trim: Error - Start & End Position cannot be the same."
        mp.osd_message(message, 3)
        return
    end

    if startPosition > endPosition then
        message = "trim: Error - Start Position is exceeding the End Position."
        mp.osd_message(message, 3)
        return
    end

    if endPosition < startPosition then
        message = "trim: Error - End Position cannot be smaller then the Start Position."
        mp.osd_message(message, 3)
        return
    end

    -- Generate Destination Path
    local destinationPath = generateDestinationPath()

    if (destinationPath == "") then
        message = "trim: Failed to generate destination path."
        mp.osd_message(message, 3)
        return
    end

    -- Prepare values
    local trimDuration = endPosition - startPosition
    local sourcePath = mp.get_property_native("path")

    local message = getTrimmingPositionsText() .. "\nWriting out... "
    mp.set_osd_ass(0, 0, "")
    mp.osd_message(message, 10)

    --
    -- ffmpeg options
    -- Refs:
    -- https://ffmpeg.org/ffmpeg.html
    -- https://ffmpeg.org/ffmpeg-formats.html
    -- https://trac.ffmpeg.org/wiki/Seeking
    -- https://trac.ffmpeg.org/wiki/Map#Optionalmapping
    --

    --
    -- -map 0:v? -map 0:a?
    --
    -- Adding a trailing question mark (?) to -map will
    -- ignore the mapping if the stream does not exist.
    --

    --
    -- -async samples_per_second
    --
    -- -async 1 is a special case where only the start of
    -- the audio stream is corrected without any later correction.
    --

    --
    -- avoid_negative_ts integer (output)
    --
    -- ‘make_zero’
    -- Shift timestamps so that the first timestamp is 0.
    --
    -- NOTES:
    -- This parameter becomes crucial when joining excerpts
    -- and playing with certain players.
    --
    -- Without this option, output will be corrupted
    -- when viewed with a plain video player such as QuickTime.
    --
    -- However, the problem is, with this option, when trimming,
    -- keyframes may get shifted to one later or one before depending on a file.
    -- This seems to be trade-off. Maybe.
    --
    -- If how output will be shown with software like QuickTime is not a matter,
    -- nor going to join splits, you can actually trim at any positions.
    -- Aim of this script is to Avoid That Very Problem, though.
    --

    --
    -- ffmpeg command structure
    -- ffmpeg ... -ss VALUE -i VALUE -t VALUE ...
    -- ... -map v:0? -map a:0? -c copy
    -- ... -async 1 -avoid_negative_ts make_zero
    --

    -- Compose command
    local strip_metadata = ""
    if stripMetadata then
        strip_metadata = " -err_detect" .. " ignore_err" ..
                         " -ignore_chapters" .. " 1" ..
                         " -map_metadata" .. " -1" ..
                         " -fflags" .. " +bitexact" ..
                         " -flags:v" .. " +bitexact" ..
                         " -flags:a" .. " +bitexact "
                         -- " -movflags" .. " faststart "
    end
    local args = {
        ffmpeg_bin,

        "-hide_banner",
        "-loglevel", "verbose",

        "-ss", tostring(startPosition),
        "-i", tostring(sourcePath),
        "-t", tostring(trimDuration),

        "-map", "v:0?",
        "-map", "a:0?",
        "-c", "copy",

        strip_metadata ..

        "-avoid_negative_ts", "make_zero",
        "-async", "1",

        destinationPath
    }

    -- Print command to console
    msg.log("info", "Executing ffmpeg command:")
    for _, val in pairs(args) do
        msg.log("info", val)
    end

    -- Execute command
    mp.command_native_async({
        name = "subprocess",
        args = args,
        capture_stdout = true
    }, function(res, val, err)

        if val.status == 1 then
            message = message .. "Failed. Refer console for details."
            msg.log("error", message)
            mp.osd_message(message, 10)

        else
            msg.log("info", "Success!: '" .. destinationPath .. "'")
            message = message .. "Done!"
            msg.log("info", message)
            mp.osd_message(message, 2)

            -- Post notification on macOS
            mp.command_native_async({
                name = "subprocess",
                args = {
                    "sh", "-c",
[[osascript << EOL 2> /dev/null
display notification "Success ✅" with title "mpv: trim" sound name "Glass"
EOL]]
                },
                capture_stdout = false
            }, function(res, val, err)
            end)
        end
    end)
end

--
-- Static Key Bindings
--
mp.add_key_binding("h", "trim-set-start-position", setStartPosition)
mp.add_key_binding("k", "trim-set-end-position", setEndPosition)
