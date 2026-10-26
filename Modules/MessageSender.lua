local addon = WhisperManager

local function copy(list)
    local result = {}
    for i, value in ipairs(list) do result[i] = value end
    return result
end

-- Hyperlinks are atomic; everything else is a UTF-8 codepoint.
local function tokenize(text)
    local tokens, pos = {}, 1
    while pos <= #text do
        local rest = text:sub(pos)
        local link = rest:match("^|c%x%x%x%x%x%x%x%x|H.-|h.-|h|r")
            or rest:match("^|H.-|h.-|h")
        local byte = text:byte(pos)
        local width = byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))
        local value = link or text:sub(pos, pos + width - 1)
        tokens[#tokens + 1] = {text = value, atomic = link ~= nil}
        pos = pos + #value
    end
    -- Only matched markers participate. Unmatched user punctuation is untouched.
    local parentheses, star = {}, nil
    for i, token in ipairs(tokens) do
        local value = token.text
        if value == "*" then
            if star then
                tokens[star].open, token.close = true, "*"
                star = nil
            else
                star = i
            end
        elseif value == "(" then
            parentheses[#parentheses + 1] = i
        elseif value == ")" and #parentheses > 0 then
            tokens[table.remove(parentheses)].open, token.close = true, "("
        end
    end
    return tokens
end

local function markers(active, closing)
    local result = {}
    if closing then
        for i = #active, 1, -1 do result[#result + 1] = active[i] == "(" and ")" or "*" end
    else
        for i, value in ipairs(active) do result[i] = value end
    end
    return table.concat(result)
end

function addon:SplitWhisperMessage(text, limit)
    limit = limit or self.WHISPER_CHUNK_BYTES or 245
    if #text <= limit then return {text} end
    local tokens, chunks, active = tokenize(text), {}, {}
    local start = 1
    while start <= #tokens do
        local prefix = markers(active, false)
        local state, bytes, last, lastState = copy(active), #prefix, nil, nil
        local space, spaceState
        for i = start, #tokens do
            local token = tokens[i]
            local nextState = copy(state)
            if token.open then nextState[#nextState + 1] = token.text end
            if token.close then
                for j = #nextState, 1, -1 do
                    if nextState[j] == token.close then table.remove(nextState, j); break end
                end
            end
            if bytes + #token.text + #markers(nextState, true) > limit then break end
            if token.text:match("^%s$") and i > start then
                space, spaceState = i, copy(state)
            end
            bytes, state, last, lastState = bytes + #token.text, nextState, i, copy(nextState)
        end
        if not last then return nil, "A link or formatting span is too large for one whisper." end
        local finish, nextStart = last, last + 1
        if last < #tokens and space then
            finish, nextStart, lastState = space - 1, space + 1, spaceState
            while tokens[nextStart] and tokens[nextStart].text:match("^%s$") do nextStart = nextStart + 1 end
        end
        local body = {}
        for i = start, finish do body[#body + 1] = tokens[i].text end
        chunks[#chunks + 1] = prefix .. table.concat(body) .. markers(lastState, true)
        active, start = lastState, nextStart
    end
    return chunks
end

local queue, current = {}, nil
local pump

local function fail(job, reason)
    if job.finished then return end
    job.finished = true
    if current == job then current = nil end
    job.win.whisperSendPending = nil
    local remaining = {}
    for i = job.index, #job.chunks do remaining[#remaining + 1] = job.chunks[i] end
    -- Never overwrite a new draft typed while waiting for delivery.
    local unsent = job.index == 1 and job.original or table.concat(remaining, " ")
    if job.win.Input:GetText() == job.original and addon:CanChangeAddonFrame(job.win.Input) then
        job.win.Input:SetText(unsent)
        addon:Print("|cffff8800" .. reason .. " Unconfirmed text remains in the composer; check chat before retrying.|r")
    else
        job.win.unsentWhisperDraft = unsent
        addon.lastFailedWhisperWindow = job.win
        addon:Print("|cffff8800" .. reason .. " Clear the new draft, then use /wmgr recover to restore unconfirmed text. Check chat before retrying.|r")
    end
    C_Timer.After(0.5, pump)
end

function addon:RecoverUnsentWhisper()
    local win = self.lastFailedWhisperWindow
    if not win or not win.unsentWhisperDraft then self:Print("No saved unsent whisper."); return end
    if not self:CanChangeAddonFrame(win) then
        self:Print("This window is temporarily protected. Restore the draft after combat.")
        return
    end
    if win.whisperSendPending or win.Input:GetText() ~= "" then
        self:Print("Clear the draft in that conversation before restoring the unsent whisper.")
        return
    end
    win.Input:SetText(win.unsentWhisperDraft)
    win.unsentWhisperDraft = nil
    win:Show()
    self:Print("Restored the unconfirmed whisper draft.")
end

local function dispatch(job)
    local reason = addon:GetWhisperRestrictionReason()
    if reason then fail(job, reason); return end
    local index = job.index
    job.awaitingConfirmation = true
    local ok, result = pcall(function()
        if job.win.isBNet then return C_BattleNet.SendWhisper(job.target, job.chunks[index]) end
        return C_ChatInfo.SendChatMessage(job.chunks[index], "WHISPER", nil, job.target)
    end)
    if not ok or result == false then
        fail(job, "Whisper could not be sent.")
        return
    end
    C_Timer.After(10, function()
        if current == job and job.index == index then fail(job, "Whisper delivery was not confirmed.") end
    end)
end

pump = function()
    if current or #queue == 0 then return end
    current = table.remove(queue, 1)
    dispatch(current)
end

function addon:SendComposedWhisper(win, text)
    local reason = self:GetWhisperRestrictionReason()
    if reason then self:Print(reason); return false end
    if self:IsSecretValue(text) then return false end
    if win.whisperSendPending then
        self:Print("This conversation is still sending. Wait for confirmation before sending again.")
        return false
    end
    if not text or not text:find("%S") then return false end
    if (strlenutf8(text) or 0) > self.CHAT_MAX_LETTERS then
        self:Print("Messages can contain up to " .. self.CHAT_MAX_LETTERS .. " characters.")
        return false
    end
    local target = win.isBNet and win.bnSenderID or win.playerTarget
    if not target or target == "" then
        self:Print("Unable to determine the whisper recipient.")
        return false
    end
    local chunks, err
    if win.isBNet then chunks = {text} else chunks, err = self:SplitWhisperMessage(text) end
    if not chunks then self:Print(err); return false end
    win.whisperSendPending = true
    queue[#queue + 1] = {win = win, target = target, original = text, chunks = chunks, index = 1}
    pump()
    return true
end

function addon:ConfirmQueuedWhisper(playerKey, text)
    if self:IsSecretValue(playerKey) or self:IsSecretValue(text) then return end
    local job = current
    if not job or not job.awaitingConfirmation or job.win.playerKey ~= playerKey
        or job.chunks[job.index] ~= text then return end
    job.awaitingConfirmation = false
    job.index = job.index + 1
    if job.index > #job.chunks then
        job.win.whisperSendPending = nil
        if job.win.Input:GetText() == job.original then job.win.Input:SetText("") end
        current = nil
        C_Timer.After(0.5, pump)
    else
        local index = job.index
        C_Timer.After(0.5, function()
            if current == job and job.index == index then dispatch(job) end
        end)
    end
end

function addon:FailQueuedWhisper(target)
    local job = current
    if not job or job.win.isBNet then return end
    if self.StripRealmFromName(target):lower() == self.StripRealmFromName(job.target):lower() then
        fail(job, "Whisper recipient is offline or unavailable.")
    end
end

-- Stop instead of automatically resuming text whose delivery may be ambiguous.
function addon:CancelRestrictedWhispers(reason)
    reason = reason or self:GetWhisperRestrictionReason()
    if not reason then return end
    local pending = queue
    queue = {}
    if current then fail(current, reason) end
    for _, job in ipairs(pending) do fail(job, reason) end
end
