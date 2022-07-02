local ar = require 'ar'
local coff = require 'coff'
local inspect = require 'inspect'

local ImportHeader = {}
ImportHeader.__index = ImportHeader

ImportHeader.ImportType = {IMPORT_CODE=0, IMPORT_DATA=1, IMPORT_CONST=2}
ImportHeader.ImportTypeName = {"IMPORT_CODE", "IMPORT_DATA", "IMPORT_CONST"}

ImportHeader.ImportNameType = {IMPORT_ORDINAL=0, IMPORT_NAME=1, IMPORT_NAME_NOPREFIX=2, IMPORT_NAME_UNDECORATE=3}
ImportHeader.ImportNameTypeName = {"IMPORT_ORDINAL", "IMPORT_NAME", "IMPORT_NAME_NOPREFIX", "IMPORT_NAME_UNDECORATE"}

function ImportHeader:from_bytes(buf)
    local importheader = {}
    setmetatable(importheader, ImportHeader)

    local sig1, sig2, version, machine, timdat, size, ordinal_hint, type_name = 
        string.unpack("<HHHHIIHH", buf)

    assert(sig1 == 0, "sig1 must be IMAGE_FILE_MACHINE_UNKNOWN (0).")
    assert(sig2 == 0xFFFF, "sig2 must be 0xFFFF.")

    importheader.sig1 = sig1
    importheader.sig2 = sig2
    importheader.version = version
    importheader.machine = machine
    importheader.timdat = timdat
    importheader.size = size
    importheader.ordinal_hint = ordinal_hint
    importheader.type_name = type_name
    importheader.type = ImportHeader.ImportTypeName[(type_name & 3) + 1]
    importheader.name = ImportHeader.ImportNameTypeName[((type_name >> 2) & 7) + 1]

    return importheader
end
local LinkerMember = {}
LinkerMember.__index = LinkerMember

LinkerMember.Type = {FIRST = 1, SECOND = 2}
function hex_dump(buf, first, last)
    local function align(n) return math.ceil(n/16) * 16 end
    for i=(align((first or 1)-16)+1), align(math.min(last or #buf,#buf)) do
        if (i-1) % 16 == 0 then io.write(string.format('%08X  ', i-1)) end
        io.write( i > #buf and '   ' or string.format('%02X ', buf:byte(i)) )
        if i %  8 == 0 then io.write(' ') end
        if i % 16 == 0 then io.write( buf:sub(i-16+1, i):gsub('%c','.'), '\n' ) end
    end
end

function LinkerMember:from_bytes(type, buf)
    local linkermember = {}
    setmetatable(linkermember, LinkerMember)

    if type == LinkerMember.Type.FIRST then    
        local nsymbols, offset = string.unpack(">I4", buf)
        linkermember.nsymbols = nsymbols

        local offsets = {}
        for i=1, nsymbols do
            offsets[#offsets + 1], offset = string.unpack(">I4", buf, offset)
        end
        linkermember.offsets = offsets

        local stringtable = {}
        for i=1, nsymbols do
            stringtable[#stringtable + 1], offset = string.unpack("z", buf, offset)
        end
        linkermember.stringtable = stringtable
     elseif type == LinkerMember.Type.SECOND then
        local nmembers, offset = string.unpack("<I4", buf)
        linkermember.nmembers = nmembers

        local memberoffsets = {}
        for i=1, nmembers do
            memberoffsets[#memberoffsets + 1], offset = string.unpack("<I4", buf, offset)
        end
        linkermember.memberoffsets = memberoffsets

        local nsymbols, offset = string.unpack("<I4", buf, offset)
        linkermember.nsymbols = nsymbols

        local indices = {}
        for i=1, nsymbols do
            indices[#indices + 1], offset = string.unpack("<I2", buf, offset)
        end
        linkermember.indices = indices

        local stringtable = {}
        for i=1, nsymbols do
            stringtable[#stringtable + 1], offset = string.unpack("z", buf, offset)
        end
        linkermember.stringtable = stringtable

        local string_map = {}
        for i=1, nsymbols do
            local index = indices[i]
            string_map[index] = stringtable[i]
        end

        linkermember.string_map = string_map
     end

     return linkermember
end

local Library = {}
Library.__index = Library

function Library:from_bytes(buf)
    local library = {}
    setmetatable(library, Library)

    archive = ar.Archive:from_bytes(buf)
    library.linkermember1 = LinkerMember:from_bytes(
        LinkerMember.Type.FIRST,
        archive[1].filebuf
    )

    library.linkermember2 = LinkerMember:from_bytes(
        LinkerMember.Type.SECOND,
        archive[2].filebuf
    )

    -- longnames member
    local objstart = 3
    if archive[3].fileheader.identifier == "//" then
        objstart = 4
        for i=1, #archive do
            result = archive[i].fileheader.identifier:match("/(%d+)")
            if result then
                archive[i].fileheader.identifier = 
                    string.unpack("z", archive[3].filebuf, tonumber(result) + 1)
            end
        end
    end

    local headers = {}
    local ncoff = 0
    local nimport = 0
    for i=objstart, #archive do
        local header
        header = coff.FileHeader:from_bytes(archive[i].filebuf)
        if header.nsections == 65535 then
            header = ImportHeader:from_bytes(archive[i].filebuf)
            nimport = nimport + 1
        else
            ncoff = ncoff + 1
        end
        headers[#headers + 1] = header
    end

    library.ncoff = ncoff
    library.nimport = nimport
    return library
end


    print(sig1, sig2)
local file = io.open(arg[1], 'rb')
local buf = file:read("*all")

local remove_all_metatables = function(item, path)
    if path[#path] ~= inspect.METATABLE then return item end
end

print(inspect.inspect(Library:from_bytes(buf), {process = remove_all_metatables}))
