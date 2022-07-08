import datatype, xmltree, segfaults
from httpclient import newHttpClient, getContent
from strutils import isEmptyOrWhitespace, strip, parseInt, contains
from uri import `$`, `/`, parseUri, Uri
from htmlparser import parseHtml

method getText(node : Xmlnode): string {.base.} =

    if node.kind == xnText:

        if not ($node).isEmptyOrWhitespace():

            return $node

    elif node.kind == xnElement:

        for child in node:

            if child.kind == xnText:
                
                if not ($child).isEmptyOrWhitespace():

                    result.add($child)
    
iterator parseDllFiles*(html : string): Dll =
    ## Parses dlls from https://www.dll-files.com/
    
    let html = parseHtml(html)
    for section in html.findAll("section"):

        if section.attr("class") == "results":

            for tr in section.findAll("tr")[1..^1]:

                try:

                    let 
                        td : seq[XmlNode] = tr.findAll("td")
                        hyperlink : XmlNode = td[0].child("a")

                    yield Dll(
                        name : hyperlink.getText(),
                        url : hyperlink.attr("href"),
                        description : td[1].getText(),
                        site : Site(
                            name : Dllfiles,
                            domain : "https://www.dll-files.com/"
                        )
                    )
                
                except NilAccessDefect:

                    continue

iterator parseWinDll*(html : string): Dll =
    ## Parses dlls from https://windll.com/
    
    let html = parseHtml(html)
    for tdiv in html.findAll("div"):

        if tdiv.attr("class") == "dll-item":

            var value: tuple[name, description, url: string, found: bool]
            for element in tdiv.child("div"):

                if element.kind == xnElement:

                    if element.tag == "h5":

                        value.name = element.getText()
                        if value.name.len != 0:

                            value.found = true
                        else:

                            value.found = false
                    
                    elif element.tag == "p":

                        value.description = element.getText()
                        if value.description.strip.len != 0:

                            value.found = true

                        else:

                            value.found = false

                    elif element.tag == "a":

                        value.url = element.attr("href")
                        if value.url.strip.len != 0:

                            value.found = true

                        else:

                            value.found = false

            if value.found:

                yield Dll(
                    name: value.name, 
                    url: value.url, 
                    description : value.description,
                    site: Site(
                        name: WinDll,
                        domain: "https://windll.com/"
                    )
                )

proc getDllFilesLink(html : XmlNode) : Uri =

    for p_tag in html.findAll("p"):

        if p_tag.attr("class") == "backup-link":

            let hyperlink = p_tag.child("a")
            if hyperlink.isNil():

                continue

            return parseUri(hyperlink.attr("href"))

proc dllLink*(dll: Dll, html, version : string, bit : Bit): DownloadData =
    ## Get dll download link

    let html = parseHtml(html)
    case dll.site.name:

    of Dllfiles:

        for section in html.findAll("section"):

            if section.attr("class") == "file-info-grid":

                block inner_for:

                    let inner_divs = section.findAll("div")
                    for tdiv in inner_divs:

                        if tdiv.attr("class") == "right-pane":

                            let
                                p_tags = tdiv.findAll("p")
                                architecture : Bit = block:

                                    var arch : Bit = Bit32
                                    try:

                                        if getText(p_tags[1]).strip().parseInt() == 64:

                                            arch = Bit64

                                    except ValueError:

                                        discard

                                    arch

                            if version.len != 0:
                                ## if version is specified check if dll is of specified version

                                if p_tags[0].getText().strip() != version:

                                    break inner_for

                            if bit != architecture:
                                ## check if dll architecture matches the specified architecture

                                break inner_for
                            
                            let meta : DownloadData = block :

                                var meta : DownloadData = toDownloadData(dll)
                                for each in inner_divs:

                                    if each.attr("class") == "download-pane":
                                        
                                        for each in each.findAll("div"):

                                            if each.attr("class") != "download-link":

                                                let
                                                    key : string = block : 

                                                        var title : string
                                                        let title_tag = each.child("b")
                                                        if not title_tag.isNil():

                                                            title = title_tag.getText().strip()

                                                        title
                                                    
                                                    val : string = block :

                                                        var val : string
                                                        let val_tag = each.child("span")
                                                        if not val_tag.isNil():

                                                            val = val_tag.getText().strip()

                                                        val

                                                case key

                                                of "MD5:":

                                                    meta.md5 = val
                                                
                                                of "SHA-1:":

                                                    meta.sha1 = val

                                                else:

                                                    discard

                                            else:

                                                let uri : Uri = block :

                                                    var uri : Uri
                                                    let url_tag = each.child("a")
                                                    if not url_tag.isNil():

                                                        let url_html = newHttpClient().getContent($(parseUri(dll.site.domain) / url_tag.attr("href")))
                                                        uri = parseHtml(url_html).getDllFilesLink()

                                                    uri

                                                meta.link = $uri

                                meta

                            return meta
                
    of WinDll:

        for tdiv in html.findAll("div"):

            if "row version" in tdiv.attr("class"):

                let 
                    inner_divs = tdiv.findAll("div")
                    meta_tag = inner_divs[^1].findAll("p")

                    architecture : Bit = block :

                        var arch : Bit = Bit32
                        try:

                            if "64" in meta_tag[1].getText():

                                arch = Bit64
                        
                        except NilAccessDefect:

                            continue

                        arch

                if bit != architecture:
                    ## check if dll architecture matches the specified architecture

                    continue

                if version.len != 0:
                    ## if version is specified check if dll is of specified version

                    try:

                        if meta_tag[0].child("strong").getText().strip() != version:

                            continue
                    
                    except NilAccessDefect:

                        continue

                let meta : DownloadData = block :

                    var meta : DownloadData = toDownloadData(dll)
                    let a_tags = tdiv.findAll("a")
                    for a_tag in a_tags:

                        let url = a_tag.attr("href")
                        if url.strip().len() != 0:

                            meta.link = url
                            break

                    meta

                return meta

