addon.name      = 'lschat';
addon.author    = 'K0D3R';
addon.version   = '1.0';
addon.desc      = 'Outputs Linkshell Chat to a Window';
addon.link      = '';

require('common');
local imgui = require('imgui');

-- Chat Variables
local chat = {
    messages = T{ },
    is_open = { true, },
};

-- Color Window Variable
local colorWindowOpen = { false, }

-- Add new variables for the input buffers
local usernameBuffer = {''}
local colorBuffer = {''}

-- Table to store the usernames and colors
local userColors = {}

--------------------------------
-- Load User Colors From File --
--------------------------------
local function loadUserColors()
	local file = io.open(addon.path:append('\\usercolors.txt'), 'r');
    if file then
        for line in file:lines() do
            local username, color = line:match('(%w+): ({[^}]+})')
            local r, g, b, a = color:match('{(%d+%.?%d*), (%d+%.?%d*), (%d+%.?%d*), (%d+%.?%d*)}')
            userColors[username] = {tonumber(r), tonumber(g), tonumber(b), tonumber(a)}
        end
        file:close()
    end
end

-- Call the function to load User Colors
loadUserColors()

----------------------
-- Clean Up Strings --
----------------------
local function clean_str(str)
    -- Parse the strings auto-translate tags..
    str = AshitaCore:GetChatManager():ParseAutoTranslate(str, true);

    -- Strip FFXI-specific color and translate tags..
    str = str:strip_colors();
    str = str:strip_translate(true);

    -- Strip line breaks..
    while (true) do
        local hasN = str:endswith('\n');
        local hasR = str:endswith('\r');

        if (not hasN and not hasR) then
            break;
        end

        if (hasN) then str = str:trimend('\n'); end
        if (hasR) then str = str:trimend('\r'); end
    end

    -- Replace mid-linebreaks..
    return (str:gsub(string.char(0x07), '\n'));
end

------------------------------
-- Check for slash commands --
------------------------------
ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/lschat')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    -- Toggle the chat window..
    chat.is_open[1] = not chat.is_open[1];
end);

---------------------------
-- Read Incoming Packets --
---------------------------
ashita.events.register('packet_in', 'packet_in_cb', function (e)
    -- Packet: Linkshell Message
    if (e.id == 0x017) then
        local msgType = struct.unpack('B', e.data, 0x04 + 1);
        if (msgType == 5) or (msgType == 27) then
            local character = struct.unpack('c15', e.data_modified, 0x08 + 1):trimend('\x00');
            local msg = struct.unpack('s', e.data_modified, 0x17 + 0x01);
			 
			-- Replace percent signs with double percent signs
            msg = string.gsub(msg, "%%", "%%%%");
			msg = clean_str(msg);
			
            local fullMsg = character .. ": " .. msg;
            if (not chat.messages:hasval(fullMsg)) then
                chat.messages:append(fullMsg);
                -- Play a sound file when a new message is added
                ashita.misc.play_sound(addon.path:append('\\sounds\\message.wav'));
            end
        end
    end
end);

---------------------------
-- Read Outgoing Packets --
---------------------------
ashita.events.register('packet_out', 'outgoing_packet', function (e)
    if (e.id == 0x0B5) then
        local msgType = struct.unpack('B', e.data, 0x04 + 1);
        if (msgType == 5) or (msgType == 27) then
            local msg = struct.unpack('s', e.data_modified, 0x06 + 0x01);
			
			-- Replace percent signs with double percent signs
            msg = string.gsub(msg, "%%", "%%%%");
			msg = clean_str(msg);
			
            local character = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or 'Unknown';
            local fullMsg = character .. ": " .. msg;
            if (not chat.messages:hasval(fullMsg)) then
                chat.messages:append(fullMsg);
            end
        end
    end    
end);

-----------------
-- Form Design --
-----------------
ashita.events.register('d3d_present', 'present_cb', function ()
    if (chat.is_open[1]) then
        imgui.SetNextWindowSize({ 400, 400, }, ImGuiCond_FirstUseEver);
        if (imgui.Begin('Linkshell Chat', chat.is_open)) then
            if (imgui.Button('Clear Chat')) then
                chat.messages:clear();
            end
			
            imgui.Separator();
			
            if (imgui.BeginChild('MessagesWindow', {0, -imgui.GetFrameHeightWithSpacing() + 20})) then
                chat.messages:each(function (v, k)
                    local username, message = string.match(v, "(%w+): (.*)")
                    local color = userColors[username] or {0.0, 1.0, 0.0, 1.0}  -- Default color is Green
                    
                    imgui.TextColored(color, username .. ":")
                    imgui.SameLine()
                    imgui.TextWrapped(message)
                end);
                imgui.SetScrollHereY(1.0);  -- Scrolls to the bottom
            end
            imgui.EndChild();
        end
        imgui.End();
    end
end);