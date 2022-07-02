local Archive = {}
Archive.__index = Archiver

local FileHeader = {}
FileHeader.__index = FileHeader

function rtrim(s)
    local n = #s
    while n > 0 and s:find("^%s", n) do n = n - 1 end
    return s:sub(1, n)
end

function FileHeader:new(identifier, timestamp, ownerid, groupid, mode, size)
    local fileheader = {}
    setmetatable(fileheader, File)

    fileheader.identifier = identifier
    fileheader.timestamp = timestamp
    fileheader.ownerid = ownerid
    fileheader.groupid = groupid
    fileheader.mode = mode
    fileheader.size = size

    return fileheader
end

function FileHeader:from_bytes(buf)
    local identifier, timestamp, ownerid,
    groupid, mode, size, offset = string.unpack("c16c12c6c6c8c10", buf)

    return FileHeader:new(
        rtrim(identifier), tonumber(timestamp), tonumber(ownerid),
        tonumber(groupid), tonumber(mode, 8), tonumber(size)
    ), offset
end

function Archive:from_bytes(buf)
    local header, offset = string.unpack("c8", buf)

    local files = {}
    while offset < #buf do
        local fileheader_bytes = buf:sub(offset, offset + 58)
        local fileheader = FileHeader:from_bytes(fileheader_bytes)
        
        offset = offset + 58 + 2
        local filebuf = buf:sub(offset, offset + fileheader.size)
        offset = offset + fileheader.size

        if offset % 2 == 0 then
            offset = offset + 1
        end

        files[#files + 1] = {
            fileheader=fileheader,
            filebuf=filebuf
        }
    end
    return files
end

local ar = {}
ar.Archive = Archive
ar.File = FileHeader

return ar
