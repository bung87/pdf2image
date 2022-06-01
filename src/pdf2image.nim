import std/[os, strutils, nre, osproc]
from pkg/filetype import nil
import struct
import nimtesseract

# filter:
# https://blog.didierstevens.com/2008/05/19/pdf-stream-objects/
# /CCITTFaxDecode/ImageMask true/BitsPerComponent 1/Width 800/DecodeParms<</K -1/Columns 800>>/Height 1200/Type/XObject>>stream
# /DCTDecode/BitsPerComponent 8/ColorSpace 1007 0 R/Width 401/Height 585/Type/XObject>>stream

proc tiffHeaderForCCITT(width:int, height:int, imgSize:int, CCITT_group=4):string =
  # https://stackoverflow.com/questions/2641770/extracting-image-from-pdf-with-ccittfaxdecode-filter
  # https://gist.github.com/gstorer/f6a9f1dfe41e8e64dcf58d07afa9ab2a correct header format
  let tiffHeaderStruct = '<' & "2s" & 'H' & 'I' & 'H' & "HHII".repeat(8) & 'I'
  result = pack(tiffHeaderStruct,
                      "II",  # Byte order indication: Little indian
                      42,  # Version number (always 42)
                      8,  # Offset to first IFD
                      8,  # Number of tags in IFD
                      256, 4, 1, width,  # ImageWidth, LONG, 1, width
                      257, 4, 1, height,  # ImageLength, LONG, 1, lenght
                      258, 3, 1, 1,  # BitsPerSample, SHORT, 1, 1
                      259, 3, 1, CCITT_group,  # Compression, SHORT, 1, 4 = CCITT Group 4 fax encoding
                      262, 3, 1, 0,  # Threshholding, SHORT, 1, 0 = WhiteIsZero
                      273, 4, 1, computeLength(tiffHeaderStruct),  # StripOffsets, LONG, 1, len of header
                      278, 4, 1, height,  # RowsPerStrip, LONG, 1, lenght
                      279, 4, 1, imgSize,  # StripByteCounts, LONG, 1, size of image
                      0  # last IFD
                      )
proc extractImages*(filePath: string; outDir: string) = 
  let content = readFile(filePath)
  var i = 0
  var 
    width:int
    height:int
    k:int
    ccittGroup:int
    header: string
  for m in findIter(content, re"(?msU)/Filter(.*)\n?stream(?:\r?\n)(.*)(?:\r?\n)endstream(?:\n)?"):
    if "/CCITTFaxDecode" in m.captures[0]:
      let p = m.captures[0].find(re"/CCITTFaxDecode/ImageMask true/BitsPerComponent 1/Width (?<width>\d+)/DecodeParms<</K (?<k>-?\d+)/Columns (?:\d+)>>/Height (?<height>\d+)/")
      let d = m.captures[0].find(re"/CCITTFaxDecode/DecodeParms<</K (?<k>-?\d+)/Columns (?:\d+)>>/Width (?<width>\d+)/Height (?<height>\d+)/BitsPerComponent 1/ImageMask true/")
      if p.isSome:
        width = parseInt p.get.captures["width"]
        height = parseInt p.get.captures["height"]
        k = parseInt p.get.captures["k"]
        ccittGroup = if k == -1: 4 else: 3
        header = tiffHeaderForCCITT(width,height, m.captures[1].len, ccittGroup )
        writeFile(outDir / $i & ".tiff", header & m.captures[1] )
      elif d.isSome:
        width = parseInt d.get.captures["width"]
        height = parseInt d.get.captures["height"]
        k = parseInt d.get.captures["k"]
        ccittGroup = if k == -1: 4 else: 3
        header = tiffHeaderForCCITT(width,height, m.captures[1].len, ccittGroup )
        writeFile(outDir / $i & ".tiff", header & m.captures[1] )
      else: 
        # echo "not CCITTFaxDecode"
        # echo m.captures[0]
        discard
    elif "/JBIG2Decode" in m.captures[0]:
      # let h = @[0x97, 0x4A, 0x42, 0x32, 0x0D, 0x0A, 0x1A, 0x0A]
      # writeFile(outDir / $i & ".jbig", cast[string](h) & m.captures[1] )
      discard
    else:
      let ft = filetype.match(toOpenArrayByte(m.captures[1], 0, m.captures[1].len - 1))
      if ft.extension.len > 0:
        writeFile(outDir / $i & "." & ft.extension, m.captures[1] )
      else:
        # echo "no ext"
        # echo repr m.captures[0]
        discard
    inc i

when isMainModule:
  let path = "/Users/bung/Documents/阿尔都塞 - 意识形态和意识形态国家机器.pdf"
  let datapath = "/usr/local/Cellar/tesseract/4.1.1/share/tessdata/"
  let tmpDir = getCurrentDir() / "tmp"
  extractImages(path, tmpDir)
  var file = open("output.txt",fmAppend)
  for f in walkDir(tmpDir):
    if f.kind == pcFile:
      # echo imageToText(f.path, "chi_sim", datapath)
      let txt = execProcess("tesseract", args=[f.path, "stdout", "-l", "chi_sim","--tessdata-dir", datapath], options={poUsePath})
      file.write txt
  file.close
