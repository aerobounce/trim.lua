--
--  trim.lua
--
--  AGPLv3 License
--  Created by github.com/aerobounce on 2019/11/18.
--  Copyright © 2019 aerobounce. All rights reserved.
--

utils = require "mp.utils"
msg = require "mp.msg"
assdraw = require "mp.assdraw"

initialized = false
startPositionDisplay = 0.0
startPosition = 0.0
endPosition = 0.0

function initializeIfNeeded()
    if initialized then
        return
    end

    endPosition = mp.get_property_native("length")

    if endPosition == "none" then
        endPosition = 0.0
    end

    mp.commandv("script-message", "osc-visibility", "always")

    mp.set_property("pause","yes")
    mp.set_property("hr-seek-framedrop","no")
    mp.set_property("options/keep-open","always")

    mp.register_event("eof-reached", function()
        msg.log("info", "Playback Reached End of File")
        mp.set_property("pause","yes")
        mp.commandv("seek", 100, "absolute-percent", "exact")
    end)

    mp.add_key_binding("shift+h", "seekToStartPosition", function()
        mp.commandv("seek", startPositionDisplay, "absolute", "exact")
    end)
    mp.add_key_binding("shift+k", "seekToEndPosition", function()
        mp.commandv("seek", endPosition, "absolute", "exact")
    end)

    initialized = true
end

function generatePositionText()

    function formatSeconds(seconds)
        local ret = string.format(
              "%02d:%02d.%03d",
              math.floor(seconds / 60) % 60,
              math.floor(seconds) % 60,
              seconds * 1000 % 1000
        )
        if seconds > 3600 then
            ret = string.format("%d:%s", math.floor(seconds / 3600), ret)
        end
        return ret
    end

    return "trim: "
           .. tostring(formatSeconds(startPositionDisplay, true))
           .. " secs ~ "
           .. tostring(formatSeconds(endPosition, true))
           .. " secs"
end

function showPositions()
    local message = generatePositionText()
    msg.log("info", message)
    ass = assdraw.ass_new()
    ass:pos(10, 34)
    ass:append(message)
    mp.set_osd_ass(0, 0, ass.text)
end

function saveStartPosition()
    initializeIfNeeded()

    local newPosition = mp.get_property_number("time-pos")
    -- newPosition = mp.get_property_native("playback-time")

    if newPosition == nil or newPosition == "none" then
        newPosition = 0.0
    end

    startPositionDisplay = newPosition

    -- msg.log("info", "saveStartPosition: " ..newPosition)

    if newPosition > 1.0 then
        local sourcePath = mp.get_property_native("path")
        local args = {
            "sh", "-c",
            "/usr/local/bin/ffprobe "
            .. "-loglevel error "
            .. "-read_intervals " .. newPosition .. "%+60 "
            .. "-skip_frame nokey "
            .. "-select_streams v:0 "
            .. "-show_entries frame=pkt_pts_time "
            .. "-of csv=print_section=0 "
            .. "-i \"" .. sourcePath
            .. "\" | awk '$1 > " .. newPosition .. " { print $1 }' "
            .. "| awk 'NR==1' | tr -d '\\n'"
        }
        local res = utils.subprocess({ args = args,
                                       cancellable = false })
        local adjustedKeyframe = tonumber(res["stdout"])
                                 or newPosition

        -- for _, val in pairs(args) do msg.log("info", val) end

        -- msg.log("info", "res[\"stdout\"]: " .. res["stdout"])
        -- msg.log("info", "res[\"stderr\"]: " .. (res["stderr"]
        --                                         or "stderr is nil"))
        msg.log("info", "newPosition: " .. newPosition)
        msg.log("info", "adjustedKeyframe: " .. adjustedKeyframe)

        newPosition = adjustedKeyframe
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

        showPositions()
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

        showPositions()
    end
end

function generateDestinationPath()
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
        "/usr/local/bin/ffmpeg",
        "-loglevel", "verbose",
        "-hide_banner",

        "-ss", tostring(startPosition),
        "-i", tostring(sourcePath),
        "-t", tostring(trimDuration),

        "-map", "v:0",
        "-map", "a:0",
        "-c", "copy",

        "-avoid_negative_ts", "make_zero",
        "-async", "1",
        "-strict", "-2",
        -- "-noaccurate_seek",

        destinationPath
    }

    for _, val in pairs(args) do msg.log("info", val) end

    local res = utils.subprocess({ args = args,
                                   cancellable = false })

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
        msg.log("info", "Success ✅: '" .. destinationPath .. "'")
        message = message .. "Done ✅"
        msg.log("info", message)
        mp.osd_message(message, 10)

        -- for _, val in pairs(args) do msg.log("info", val) end

        utils.subprocess({ args = {
            "sh", "-c",
[[osascript <<EOL
display notification "Success ✅" with title "mpv: trim" sound name "Glass"
EOL]]
                        },
                        cancellable = false })
    end
end

mp.add_key_binding("h", "saveStartPosition", saveStartPosition)
mp.add_key_binding("k", "saveEndPosition", saveEndPosition)

mp.add_key_binding("Shift+LEFT", "seek", function()
    initializeIfNeeded()
    mp.commandv("seek", -0.01, "relative", "keyframes")
    mp.command("show-progress")
end)
mp.add_key_binding("Shift+RIGHT", "seek", function()
    initializeIfNeeded()
    mp.commandv("seek", 0.01, "relative", "keyframes")
    mp.command("show-progress")
end)
