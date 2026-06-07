import UIKit
import Foundation

struct DocxGenerator {
    static func generate(
        template: ReportTemplate,
        draft: ReportDraft,
        property: Property
    ) -> Data? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy年M月d日"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "yyyy/MM/dd HH:mm"

        var images: [(id: String, data: Data)] = []
        var imageIndex = 0

        // Build document body XML
        var body = ""

        // Title
        body += paragraph("マンション清掃 作業報告書", bold: true, size: 32, alignment: "center")
        body += paragraph("", size: 12) // spacer

        // Basic info table
        body += "<w:tbl>"
        body += tableProperties()
        body += tableRow("物件名", property.name)
        if !property.address.isEmpty {
            body += tableRow("住所", property.address)
        }
        body += tableRow("作業日", dateFormatter.string(from: draft.workDate))
        body += tableRow("作業者", draft.workerName)
        body += "</w:tbl>"
        body += paragraph("", size: 12)

        // Sections
        for section in template.sections {
            body += paragraph("■ \(section.title)", bold: true, size: 24)

            if !section.description.isEmpty {
                body += paragraph(section.description, size: 18, color: "666666")
            }

            switch section.type {
            case .photo:
                if section.perFloor {
                    for floor in stride(from: property.floors, through: 1, by: -1) {
                        body += paragraph("\(floor)F", bold: true, size: 20, color: "444444")
                        let photos = draft.photosFor(sectionId: section.id, floor: floor)
                        if photos.isEmpty {
                            body += paragraph("（写真なし）", size: 18, color: "999999")
                        } else {
                            for photo in photos {
                                if let imgData = photo.jpegData(compressionQuality: 0.6) {
                                    imageIndex += 1
                                    let imgId = "rImg\(imageIndex)"
                                    images.append((id: imgId, data: imgData))
                                    body += imageElement(rId: imgId, width: photo.size.width, height: photo.size.height)
                                }
                            }
                        }
                    }
                } else {
                    let photos = draft.photosFor(sectionId: section.id)
                    if photos.isEmpty {
                        body += paragraph("（写真なし）", size: 18, color: "999999")
                    } else {
                        for photo in photos {
                            if let imgData = photo.jpegData(compressionQuality: 0.6) {
                                imageIndex += 1
                                let imgId = "rImg\(imageIndex)"
                                images.append((id: imgId, data: imgData))
                                body += imageElement(rId: imgId, width: photo.size.width, height: photo.size.height)
                            }
                        }
                    }
                }

            case .checklist:
                let checks = draft.checks[section.id] ?? []
                body += "<w:tbl>"
                body += tableProperties(col1: 7800, col2: 1226)
                for (i, item) in section.checklistItems.enumerated() {
                    let checked = i < checks.count && checks[i]
                    let mark = checked ? "☑" : "☐"
                    let status = checked ? "済" : "未"
                    body += tableRow("\(mark) \(item)", status, col1: 7800, col2: 1226)
                }
                body += "</w:tbl>"

            case .text:
                let text = draft.texts[section.id] ?? ""
                if text.isEmpty {
                    body += paragraph("（記入なし）", size: 18, color: "999999")
                } else {
                    body += paragraph(text, size: 20)
                }
            }

            if !section.note.isEmpty {
                body += paragraph("※ \(section.note)", size: 16, color: "999999")
            }

            body += paragraph("", size: 8) // spacer
        }

        // Footer
        body += paragraph("送信日時: \(timeFormatter.string(from: Date()))", size: 16, color: "999999")

        // Build .docx ZIP
        return buildDocx(body: body, images: images)
    }

    // MARK: - XML Helpers

    private static func paragraph(_ text: String, bold: Bool = false, size: Int = 22, color: String = "000000", alignment: String? = nil) -> String {
        var ppr = "<w:pPr>"
        if let alignment {
            ppr += "<w:jc w:val=\"\(alignment)\"/>"
        }
        ppr += "</w:pPr>"

        var rpr = "<w:rPr><w:sz w:val=\"\(size)\"/><w:szCs w:val=\"\(size)\"/>"
        if bold { rpr += "<w:b/><w:bCs/>" }
        if color != "000000" { rpr += "<w:color w:val=\"\(color)\"/>" }
        rpr += "</w:rPr>"

        let escaped = text.xmlEscaped
        return "<w:p>\(ppr)<w:r>\(rpr)<w:t xml:space=\"preserve\">\(escaped)</w:t></w:r></w:p>"
    }

    private static func tableProperties(col1: Int = 2500, col2: Int = 6526) -> String {
        let total = col1 + col2
        return """
        <w:tblPr>
        <w:tblW w:w="\(total)" w:type="dxa"/>
        <w:tblLayout w:type="fixed"/>
        <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        </w:tblBorders>
        </w:tblPr>
        <w:tblGrid><w:gridCol w:w="\(col1)"/><w:gridCol w:w="\(col2)"/></w:tblGrid>
        """
    }

    private static func tableRow(_ label: String, _ value: String, col1: Int = 2500, col2: Int = 6526) -> String {
        let cell1 = "<w:tc><w:tcPr><w:tcW w:w=\"\(col1)\" w:type=\"dxa\"/><w:shd w:val=\"clear\" w:fill=\"F0F0F0\"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val=\"20\"/></w:rPr><w:t xml:space=\"preserve\">\(label.xmlEscaped)</w:t></w:r></w:p></w:tc>"
        let cell2 = "<w:tc><w:tcPr><w:tcW w:w=\"\(col2)\" w:type=\"dxa\"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val=\"20\"/></w:rPr><w:t xml:space=\"preserve\">\(value.xmlEscaped)</w:t></w:r></w:p></w:tc>"
        return "<w:tr>\(cell1)\(cell2)</w:tr>"
    }

    private static func imageElement(rId: String, width: CGFloat, height: CGFloat) -> String {
        let maxW: CGFloat = 5000000 // ~13cm in EMU
        let aspect = width / height
        let emuW = Int(min(maxW, width * 9525))
        let emuH = Int(Double(emuW) / aspect)

        return """
        <w:p><w:r><w:drawing>
        <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="\(emuW)" cy="\(emuH)"/>
        <wp:docPr id="0" name="\(rId)"/>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:nvPicPr><pic:cNvPr id="0" name="\(rId)"/><pic:cNvPicPr/></pic:nvPicPr>
        <pic:blipFill><a:blip r:embed="\(rId)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(emuW)" cy="\(emuH)"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
        </pic:pic>
        </a:graphicData>
        </a:graphic>
        </wp:inline>
        </w:drawing></w:r></w:p>
        """
    }

    // MARK: - ZIP Builder

    private static func buildDocx(body: String, images: [(id: String, data: Data)]) -> Data? {
        let documentXml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                    xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <w:body>\(body)</w:body>
        </w:document>
        """

        // Image relationships
        var rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        """
        for img in images {
            rels += "<Relationship Id=\"\(img.id)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/\(img.id).jpg\"/>"
        }
        rels += "</Relationships>"

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Default Extension="jpg" ContentType="image/jpeg"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        </Types>
        """

        let topRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """

        let stylesXml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:docDefaults><w:rPrDefault><w:rPr>
        <w:rFonts w:ascii="Hiragino Sans" w:eastAsia="Hiragino Sans" w:hAnsi="Hiragino Sans"/>
        <w:sz w:val="22"/><w:szCs w:val="22"/>
        </w:rPr></w:rPrDefault></w:docDefaults>
        </w:styles>
        """

        // Build ZIP using simple store method (no compression needed for docx)
        var entries: [(path: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(topRels.utf8)),
            ("word/document.xml", Data(documentXml.utf8)),
            ("word/_rels/document.xml.rels", Data(rels.utf8)),
            ("word/styles.xml", Data(stylesXml.utf8)),
        ]

        for img in images {
            entries.append(("word/media/\(img.id).jpg", img.data))
        }

        return createZip(entries: entries)
    }

    // Minimal ZIP file creator (store method, no compression)
    private static func createZip(entries: [(path: String, data: Data)]) -> Data? {
        var zipData = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        for entry in entries {
            let pathData = Data(entry.path.utf8)
            let fileData = entry.data
            let crc = crc32(fileData)

            offsets.append(UInt32(zipData.count))

            // Local file header
            zipData.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // signature
            zipData.appendUInt16(20) // version needed
            zipData.appendUInt16(0)  // flags
            zipData.appendUInt16(0)  // compression (store)
            zipData.appendUInt16(0)  // mod time
            zipData.appendUInt16(0)  // mod date
            zipData.appendUInt32(crc)
            zipData.appendUInt32(UInt32(fileData.count)) // compressed
            zipData.appendUInt32(UInt32(fileData.count)) // uncompressed
            zipData.appendUInt16(UInt16(pathData.count))
            zipData.appendUInt16(0) // extra field length
            zipData.append(pathData)
            zipData.append(fileData)

            // Central directory entry
            centralDirectory.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            centralDirectory.appendUInt16(20) // version made by
            centralDirectory.appendUInt16(20) // version needed
            centralDirectory.appendUInt16(0)  // flags
            centralDirectory.appendUInt16(0)  // compression
            centralDirectory.appendUInt16(0)  // mod time
            centralDirectory.appendUInt16(0)  // mod date
            centralDirectory.appendUInt32(crc)
            centralDirectory.appendUInt32(UInt32(fileData.count))
            centralDirectory.appendUInt32(UInt32(fileData.count))
            centralDirectory.appendUInt16(UInt16(pathData.count))
            centralDirectory.appendUInt16(0) // extra
            centralDirectory.appendUInt16(0) // comment
            centralDirectory.appendUInt16(0) // disk start
            centralDirectory.appendUInt16(0) // internal attrs
            centralDirectory.appendUInt32(0) // external attrs
            centralDirectory.appendUInt32(offsets.last!)
            centralDirectory.append(pathData)
        }

        let cdOffset = UInt32(zipData.count)
        zipData.append(centralDirectory)

        // End of central directory
        zipData.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        zipData.appendUInt16(0) // disk number
        zipData.appendUInt16(0) // cd disk
        zipData.appendUInt16(UInt16(entries.count))
        zipData.appendUInt16(UInt16(entries.count))
        zipData.appendUInt32(UInt32(centralDirectory.count))
        zipData.appendUInt32(cdOffset)
        zipData.appendUInt16(0) // comment length

        return zipData
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (crc & 1 != 0 ? 0xEDB88320 : 0)
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Extensions

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }
    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
