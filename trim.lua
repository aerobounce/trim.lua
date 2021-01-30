--
--  trim.lua
--
--  AGPLv3 License
--  Created by github.com/aerobounce on 2019/11/18.
--  Copyright © 2019-present aerobounce. All rights reserved.
--
local utils = require "mp.utils"
local msg = require "mp.msg"
local assdraw = require "mp.assdraw"

local ffmpeg_bin = "ffmpeg"
local ffprobe_bin = "ffprobe"

local initialized = false
local initializedMessageShown = false
local startPositionDisplay = 0.0
local startPosition = 0.0
local endPosition = 0.0

local function initializeIfNeeded()
    if initialized then
        return
    end
    initialized = true

    endPosition = mp.get_property_native("length")

    if endPosition == "none" then
        endPosition = 0.0
    end

    -- Settings suitable for trimming
    mp.commandv("script-message", "osc-visibility", "always")
    mp.set_property("pause", "yes")
    mp.set_property("hr-seek", "no")
    mp.set_property("hr-seek-framedrop", "no")
    mp.set_property("options/keep-open", "always")
    mp.register_event("eof-reached", function()
        msg.log("info", "Playback Reached End of File")
        mp.set_property("pause", "yes")
        mp.commandv("seek", 100, "absolute-percent", "exact")
    end)

    -- Precise keyframe seek
    mp.add_key_binding("shift+LEFT", "seek-backward-precise", function()
        mp.commandv("seek", -0.1, "keyframes")
        mp.command("show-progress")
    end)
    mp.add_key_binding("shift+RIGHT", "seek-forward-precise", function()
        mp.commandv("seek", 0.1, "keyframes")
        mp.command("show-progress")
    end)

    -- Seek to trimming position
    mp.add_key_binding("shift+h", "seek-to-start-position", function()
        mp.commandv("seek", startPosition, "absolute")
    end)
    mp.add_key_binding("shift+k", "seek-to-end-position", function()
        mp.commandv("seek", endPosition, "absolute")
    end)

    -- Show OSD
    showMessage("trim.lua Enabled!")
    mp.add_timeout(1, function()
        initializedMessageShown = true
        mp.set_osd_ass(0, 0, "")
    end)
end

local function generatePositionText()
    function formatSeconds(seconds)
        local ret = string.format("%02d:%02d.%03d",
                                  math.floor(seconds / 60) % 60,
                                  math.floor(seconds) % 60,
                                  seconds * 1000 % 1000)
        if seconds > 3600 then
            ret = string.format("%d:%s", math.floor(seconds / 3600), ret)
        end
        return ret
    end

    return
        "Trimming: " .. tostring(formatSeconds(startPositionDisplay, true)) ..
            " secs ~ " .. tostring(formatSeconds(endPosition, true)) .. " secs"
end

function showMessage(message)
    msg.log("info", message)
    ass = assdraw.ass_new()
    ass:pos(10, 34)
    ass:append(message)
    mp.set_osd_ass(0, 0, ass.text)
end

local function showPositions()
    showMessage(generatePositionText())
end

-- function seekToClosestBackwardKeyframe()
--     local currentTimePosition = mp.get_property_number("time-pos")
--     local sourcePath = mp.get_property_native("path")
--     local args = {
--         "sh",
--         "-c",
--         ffprobe_bin .. " " .. "-loglevel error " .. "-read_intervals " ..
--             currentTimePosition .. "%-60 " .. "-skip_frame nokey " ..
--             "-select_streams v:0 " .. "-show_entries frame=pkt_pts_time " ..
--             "-of csv=print_section=0 " .. "-i \"" .. sourcePath ..
--             "\" | awk '$1 > " .. currentTimePosition .. " { print $1 }' " ..
--             "| awk 'NR==1' | tr -d '\\n'",
--     }
--     local res = utils.subprocess({args = args, cancellable = false})
--     local result = tonumber(res["stdout"]) or currentTimePosition

--     msg.log("info", "result: ", result)

--     mp.commandv("seek", result, "absolute")
-- end

function saveStartPosition()
    initializeIfNeeded()

    if not initializedMessageShown then
        return
    end

    local newPosition = mp.get_property_number("time-pos")

    if newPosition == nil or newPosition == "none" then
        newPosition = 0.0
    end

    startPositionDisplay = newPosition

    if newPosition > 1.0 then
        -- THIS MAY BE NEEDLESS LOGIC since mpv is doing the same using ffmpeg.
        -- Subtracting 0.01 to get the next closest keyframe from ffprobe.
        local newPosition_minus_0_01 = newPosition - 0.01
        local sourcePath = mp.get_property_native("path")
        local args = {
            "sh",
            "-c",
            ffprobe_bin .. " " .. "-loglevel error " .. "-read_intervals " ..
                newPosition_minus_0_01 .. "%+60 " .. "-skip_frame nokey " ..
                "-select_streams v:0 " .. "-show_entries frame=pkt_pts_time " ..
                "-of csv=print_section=0 " .. "-i \"" .. sourcePath ..
                "\" | awk '$1 > " .. newPosition_minus_0_01 .. " { print $1 }' " ..
                "| awk 'NR==1' | tr -d '\\n'",
        }
        local res = utils.subprocess({args = args, cancellable = false})
        local adjustedKeyframe = tonumber(res["stdout"]) or newPosition

        -- For debug use --
        -- for _, val in pairs(args) do msg.log("info", val) end
        -- msg.log("info", "res[\"stdout\"]: " .. res["stdout"])
        -- msg.log("info", "res[\"stderr\"]: " .. (res["stderr"] or "stderr is nil"))

        newPosition = adjustedKeyframe

        -- THIS MAY BE NEEDLESS LOGIC.

        -- Seek to the keyframe from ffprobe
        local old_time_pos = mp.get_property_number("time-pos")
        mp.commandv("seek", newPosition, "absolute")
        local new_time_pos = mp.get_property_number("time-pos")

        -- If mpv's keyframe was different from what ffprobe indicated,
        if old_time_pos ~= new_time_pos then
            -- Modify the value not to writeOut
            newPosition = newPosition - 0.001
        end

        -- For debug use --
        -- msg.log("info", "time-pos: ", mp.get_property_number("time-pos"))
        -- msg.log("info", "newPosition: ", newPosition)

    else
        newPosition = 0.0
        startPositionDisplay = newPosition
    end

    if startPosition == newPosition then
        writeOut()
    else
        startPosition = newPosition

        if startPosition > endPosition then
            endPosition = startPosition
        end

        if initializedMessageShown then
            showPositions()
        end
    end
end

function saveEndPosition()
    initializeIfNeeded()

    newPosition = mp.get_property_number("time-pos")
    -- newPosition = mp.get_property_native("playback-time")

    if newPosition == nil or newPosition == "none" then
        newPosition = 0.0
    end

    if endPosition == newPosition then
        writeOut()
    else
        endPosition = newPosition

        if endPosition < startPosition then
            startPosition = endPosition
        end

        if initializedMessageShown then
            showPositions()
        end
    end
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

function writeOut()

    if startPosition == endPosition then
        message = "trim: Error - Start/End Position are the same."
        mp.osd_message(message, 3)

        if initializedMessageShown then
            showPositions()
        end
        return
    end

    local destinationPath = generateDestinationPath()
    if (destinationPath == "") then
        message = "trim: Failed to generate destination path."
        mp.osd_message(message, 3)
        return
    end

    mp.set_osd_ass(0, 0, "")

    local trimDuration = endPosition - startPosition
    local sourcePath = mp.get_property_native("path")

    local message = generatePositionText() .. "\nWriting out... "
    msg.log("info", message)
    mp.osd_message(message, 10)

    local args = {
        "sh",
        "-c",
        ffmpeg_bin .. " " .. "-hide_banner " .. "-loglevel " .. "verbose " ..
            "-ss " .. tostring(startPosition) .. " -i " .. "\"" ..
            tostring(sourcePath) .. "\"" .. " -t " .. tostring(trimDuration) ..
            " -map " .. "v:0 " .. "-map " .. "a:0 " .. "-c " .. "copy " ..
            "-avoid_negative_ts " .. "make_zero " .. "-async " .. "1 " ..
            "-strict " .. "-2 " .. "\"" .. destinationPath .. "\"",
    }
    -- "-noaccurate_seek",

    msg.log("info", "Executing ffmpeg command:")
    for _, val in pairs(args) do
        msg.log("info", val)
    end

    local res = utils.subprocess({args = args, cancellable = false})

    if (res["status"] ~= 0) then
        if (res["status"] ~= nil) then
            message = message .. "\nERROR: " .. res["status"]
        end

        if (res["error"] ~= nil) then
            message = message .. "\nERROR: " .. res["error"]
        end

        if (res["stdout"] ~= nil) then
            message = message .. "\nstdout: " .. res["stdout"]
        end

        msg.log("error", message)
        mp.osd_message(message, 10)

    else
        msg.log("info", "Success ✔︎: '" .. destinationPath .. "'")
        message = message .. "Done ✔︎"
        msg.log("info", message)
        mp.osd_message(message, 10)

        -- Debug use --
        -- for _, val in pairs(args) do msg.log("info", val) end

        utils.subprocess({
            args = {
                "sh",
                "-c",
                [[osascript << EOL 2> /dev/null
display notification "Success ✅" with title "mpv: trim" sound name "Glass"
EOL]],
            },
            cancellable = false,
        })
    end
end

mp.add_key_binding("h", "save-start-position", saveStartPosition)
mp.add_key_binding("k", "save-end-position", saveEndPosition)
