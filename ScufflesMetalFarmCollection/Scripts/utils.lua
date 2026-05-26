local ModName = "ScufflesMetalFarmCollection"

function Log(msg)
    print(string.format("[%s] %s\n", ModName, msg))
end

--Checks whether a string is nil or empty
function  IsNilOrEmpty(textToCheck)
    if textToCheck == nil or textToCheck == "" then
        return true
    end
    return false
end

function CreateDirectory(path)
    os.execute('mkdir "' .. path:gsub("/", "\\") .. '" 2>nul')
end

--fail-safe way access a file
function WithFile(path, mode, fn)
    local f, err = io.open(path, mode)
    if not f then
        return false, err
    end

    local ok, resultOrErr = pcall(fn, f)
    f:close()

    if not ok then
        return false, resultOrErr
    end

    return true, resultOrErr
end

function WriteText(path, body)
    CreateDirectory(path:match("(.*[/\\])"))

    if IsNilOrEmpty(body) then
        return false
    end

    return WithFile(path, "w", function(f)
        f:write(body)
    end)
end

function GetActorLabel(actor)
    --Make sure the actor is valid
    if not actor or not actor:IsValid() then
        return nil
    end
    
    --make sure it has a UGCComponent
    local ok, ugc = pcall(function() return actor.UGCComponent end)

    if not ok or not ugc then
        return nil
    end
    
    --make sure the UGCComponent is valid
    local ok1, isValid = pcall(function() return ugc:IsValid() end)

    if not ok1 or not isValid then
        return nil
    end

    --make sure the UGCComponent has user generated content
    local ok2, hasUGC = pcall(function() return ugc.HasUserGeneratedContent() end)

    if not ok2 or not hasUGC then
        return nil
    end

    --make sure the UGCComponent has player texts
    local ok3, texts = pcall(function() return ugc.PlayerTexts end)
    
    if not ok3 or not texts then
        return nil
    end

    --make sure the PlayerTexts is a non-empty collection
    local ok4, length = pcall(function() return #texts end)

    if not ok4 or length == 0 then
        return nil
    end

    --now that we've validated the actor and its UGCComponent, we can attempt to get the label from the PlayerTexts
    for i = 1, length do
        local label = nil
        
        pcall(function()
            local entry = texts[i]
            if entry then
                local value = entry.Value
                if value then
                   local str = nil

                   local ok_inner, stringFromValue = pcall(function() return value:ToString() end)

                    if ok_inner and type(stringFromValue) == "string" then
                        str = stringFromValue
                    end

                    if not str then
                        local raw = tostring(value)

                        if raw and not raw:match("^FString:") and not IsNilOrEmpty(raw) then
                            str = raw
                        end
                    end

                    if str and not IsNilOrEmpty(str) then
                        label = str
                    end
                end
            end
        end)

        if label then
            return label
        end
    end

    return nil
end

--- Calculate 3D distance between two actors
---@param actorA userdata Actor with K2_GetActorLocation
---@param actorB userdata Actor with K2_GetActorLocation
---@return number distance in Unreal units (1 unit = 1 cm, so 100 = 1 meter)
function GetDistance(actorA, actorB)
    local locA = actorA:K2_GetActorLocation()
    local locB = actorB:K2_GetActorLocation()
    local dx = locA.X - locB.X
    local dy = locA.Y - locB.Y
    local dz = locA.Z - locB.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end