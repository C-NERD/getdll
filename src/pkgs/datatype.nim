when defined(js):

    {.error : "This code is not meant to compile for js".}

type

    SiteName* {.pure.} = enum

        Dllfiles = "dll-files.com"
        WinDll = "windll.com"

    Site* = object

        name*: SiteName
        domain*: string

    Dll* = ref object of RootObj

        name*, url*, description*: string
        site*: Site

    Bit* {.pure.} = enum

        Bit32 = "32" 
        Bit64 = "64"

    DownloadData* = ref object of Dll

        link*, md5*, sha1*: string

converter toDownloadData*(dll : Dll) : DownloadData =

    return DownloadData(
        name : dll.name,
        url : dll.url,
        description : dll.description,
        site : dll.site,
        link : "",
        md5 : "",
        sha1 : ""
    )
    