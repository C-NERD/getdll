when not defined(Windows):

    {.error : "This application is for windows os".}

import httpclient, os, logging, pkgs / [datatype, utils]
import std/[re, parseopt, sha1], md5
from os import `/`, dirExists, getCurrentDir, getConfigDir
from strformat import fmt
from sequtils import anyIt, filterIt, foldl
from strutils import contains, split, strip
from uri import `/`, `$`, isAbsolute, parseUri

#let logger = newFileLogger(open(getConfigDir() / "getdll.log", fmAppend), fmtStr = "$levelname -> ")
let logger = newConsoleLogger(fmtStr = "$levelname -> ")
addHandler(logger)

let 
    client = newHttpClient()
    architecture : Bit = block :

        var architecture : Bit = Bit32
        when defined(amd64):

            architecture = Bit64
        
        architecture

    sys_dir : string = block :

        var sys_dir : string
        let
            sys_dir1 = "C:/Windows/System32"
            sys_dir2 = "C:/Winnt/system32"

        if dirExists(sys_dir1):

            sys_dir = sys_dir1

        else:

            sys_dir = sys_dir2

        sys_dir
    
## Datatypes
type

    Option {.pure.} = enum
        ## Used for parsing cmdline params
        Getdlls Listdlls None

iterator searchForDlls(dll: string): Dll =
               
    try:

        info("Searching dll-files.com for {dll}".fmt)
        var 
            html = client.getContent("https://www.dll-files.com/search/?q={dll}".fmt)
            count : int

        for dll in parseDllFiles(html):

            yield dll
            count.inc()

        if count == 0:

            info("Searching windll.com for {dll}".fmt)
            html = client.getContent("https://windll.com/search?query={dll}".fmt)

            for dll in parseWinDll(html):

                yield dll

    except HttpRequestError:

        error("Cannot access the web, make sure this app is not blocked by a firewall")
        quit(-1)

proc getDlls(exe: string): seq[string] =
    ## Identifies the required dlls by exe

    let exepath = exe.splitFile
    if exepath.ext != ".exe": #ExeExt:
        ## Makes sure file is an executable

        error("File {exe} is not an executable".fmt)
        return
    else:

        if not fileExists(exe):
            ## Makes sure file exists

            error("File {exe} does not exists".fmt)
            return

    info(fmt"Scanning {exepath.name} for required dlls")
    ## Identifies the required and missing dlls for a .exe file
    try:

        ## Identifies dlls from .exe file
        let data = readFile(exe)
        for dll in data.findAll(re"@([A-z]|[0-9]|[-()|])*\.dll"):

            let lib = $dll[1..^5]
            if result.anyIt(it.contains(lib) or lib.contains($it[0..^5])):

                continue
            else:

                result.add("{lib}.dll".fmt)

    except RangeDefect:

        fatal("Could not find executable {exe}".fmt)
        return

proc getMissingDlls(exe : string) : seq[string] =
    ## Filters out non required dlls
    ## C:\Windows\System32 windows dirrectory where all dlls are stored
    
    result = getDlls(exe)

    let exepath = exe.splitFile
    for env in envPairs():
        ## Filters out non required dlls from path

        for dll in walkFiles($env / "*.dll"):

            result = result.filterIt(dll notin it)

    for dll in walkFiles(exepath.dir / "*.dll"):
        ## Filters out non required dlls from executables dir

        result = result.filterIt(dll notin it)

proc downloadLinks(dll, version : string, bit: Bit) : seq[DownloadData] =

    info(fmt"getting download links for dll {dll}...")
    for dll in searchForDlls(dll):

        var url = dll.url
        if not dll.url.parseUri().isAbsolute():
            ## Makes sure that dll.url is an absolute url

            url = $(dll.site.domain.parseUri() / dll.url)

        let 
            html = client.getContent(url)
            link = dllLink(dll, html, version, bit)

        if link.isNil():

            continue
                
        if link.link.strip.len > 0:

            result.add(link)

proc downloadDll(dll, dir: string, version: string = "", bit: Bit = architecture, global : bool = false) =
    
    let links = downloadLinks(dll, version, bit)
    if links.len == 0:

        info(fmt"Could not find any dll with keyword {dll}, make sure you type the name correctly")
        return

    var download_dir : string
    if global:
        ## download to global folder (system32)
        
        info(fmt"downloading dll to {sys_dir}")
        download_dir = sys_dir

    else:
        ## download in dir if dir exists and if not download in current working dirrectory
        
        info(fmt"downloading dll to {dir}")
        download_dir = dir ## default download location to given directory
        if not dirExists(download_dir):
            ## if directory does not exists download dll to current working directory
                
            debug(fmt"Dir {download_dir} does not exists")
            download_dir = getCurrentDir()

            info(fmt"Dll will be downloaded to {download_dir}")

    for pos in 0..<links.len:
        
        let
            sha1_len = links[pos].sha1.strip().len()
            md5_len = links[pos].md5.strip().len()

        ## TODO : uncomment code after proper testing
        #if sha1_len == 0 and md5_len == 0:

        client.downloadFile(links[pos].link, download_dir / links[pos].name)

        #[else:

            var 
                cond : bool
                msg : string
            let content = client.getContent(links[pos].link)
            if sha1_len != 0:

                try:
                    
                    cond = (parseSecureHash(links[pos].sha1) == secureHash(content))
                
                except:
                    
                    discard
                
                if not cond:
                    
                    msg = fmt"dll {links[pos].name} has miss matched sha1 hash"
            
            elif (not cond) and md5_len != 0:

                try:

                    cond = (getMD5(content) == links[pos].md5)

                except:

                    discard

                if not cond:

                    msg = fmt"dll {links[pos].name} has miss matched md5 hash"

            if cond:

                writeFile(download_dir / links[pos].name, content)

            else:

                debug(msg)
                info(fmt"will not download {links[pos].name}")]#

        info(fmt"dll {links[pos].name} download completed")

when isMainModule:

    ## Get and parse cmd parameters
    let parameters = commandLineParams()
    if parameters.len == 0:

        stdout.writeLine("Use -h or --help to print out the help message")
        quit(0)

    var
        params = initOptParser(parameters.foldl("{a} {b}".fmt))
        option: Option = Option.None
    while true:

        params.next()
        case params.kind

        of cmdEnd: break
        of cmdShortOption, cmdLongOption:

            let
                appname = getAppFilename().split("/")[^1]
                help = """
                {appname}
                Caution : This software is meant for the windows operating system only

                Usage:

                    {appname} [options] [path-to-executable]
                Options:

                    --getdlls                                     Gets all required dlls for the executable
                    --listdlls                                    Lists all required dlls for the executable

                Options that take parameters, no need to supply [path-to-executable]

                    --search | -s:dll                             Search the web for dll

                Options that do not that parameters, no need to supply [path-to-executable]

                    --help   | -h                                 Displays this help message

                """.fmt
            case params.key

            of "getdlls":

                option = Getdlls

            of "listdlls":

                option = Listdlls

            of "search", "s":

                if params.key.strip.len == 0:

                    stdout.writeLine("Add a dll keyword to your search param like -s:dll")

                else:

                    for dll in searchForDlls(params.val):

                        var url: string
                        if dll.url.parseUri.isAbsolute:

                            url = dll.url
                        else:

                            if dll.url.strip.len != 0:

                                url = $(dll.site.domain / dll.url)
                            else:

                                continue

                        stdout.writeLine("{dll.name} : {url}".fmt)

            of "help", "h":

                for line in help.split("\n"):

                    stdout.writeLine line.strip

            else:

                stdout.writeLine(fmt"Invalid option {params.key}")
                quit(-1)

        of cmdArgument:

            case option

            of Getdlls:

                for dll in params.key.getMissingDlls():

                    downloadDll(dll, "")

            of Listdlls:

                for dll in params.key.getMissingDlls():

                    stdout.writeLine dll

            of Option.None:

                discard
