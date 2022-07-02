local inspect = require 'inspect'

local FileHeader = {}
FileHeader.__index = FileHeader

function FileHeader:new(machine, nsections, timdat,
        symptr, nsyms, szopthdr, flags)
    local fileheader = {}
    setmetatable(fileheader, FileHeader)

    fileheader.machine = machine
    fileheader.nsections = nsections
    fileheader.timdat = timdat
    fileheader.symptr = symptr
    fileheader.nsyms = nsyms
    fileheader.szopthdr = szopthdr
    fileheader.flags = flags

    return fileheader
end

function FileHeader:from_bytes(buf)
    local machine, nsections, timdat, symptr,
    nsyms, szopthdr, flags, offset = string.unpack(
        "<HHIIIHH", buf
    )

    return FileHeader:new(
        machine, nsections, timdat, symptr,
        nsyms, szopthdr, flags
    )
end

local coff = {}
coff.FileHeader = FileHeader

return coff
