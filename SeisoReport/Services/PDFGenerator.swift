import UIKit

struct PDFGenerator {
    static func generate(
        template: ReportTemplate,
        draft: ReportDraft,
        property: Property
    ) -> Data {
        let pageWidth: CGFloat = 595.28 // A4
        let pageHeight: CGFloat = 841.89
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2
        let photoSize: CGFloat = 160
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            var y: CGFloat = 0

            func newPage() {
                context.beginPage()
                y = margin
            }

            func checkSpace(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    newPage()
                }
            }

            func drawText(_ text: String, fontSize: CGFloat, bold: Bool = false, color: UIColor = .black, maxWidth: CGFloat = contentWidth) -> CGFloat {
                let font: UIFont = bold ? .boldSystemFont(ofSize: fontSize) : .systemFont(ofSize: fontSize)
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 4
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
                let rect = CGRect(x: margin, y: y, width: maxWidth, height: 9999)
                let boundingRect = (text as NSString).boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                checkSpace(boundingRect.height + 4)
                (text as NSString).draw(in: CGRect(x: margin, y: y, width: maxWidth, height: boundingRect.height + 4), withAttributes: attrs)
                let h = boundingRect.height + 8
                y += h
                return h
            }

            func drawSeparator() {
                checkSpace(10)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                UIColor.lightGray.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                y += 10
            }

            func drawPhoto(_ image: UIImage) {
                let aspect = image.size.width / image.size.height
                let w = min(photoSize, contentWidth)
                let h = w / aspect
                checkSpace(h + 8)
                let rect = CGRect(x: margin, y: y, width: w, height: h)
                image.draw(in: rect)
                y += h + 8
            }

            // === Page 1 ===
            newPage()

            // Title
            drawText("マンション清掃 作業報告書", fontSize: 20, bold: true)
            y += 8
            drawSeparator()

            // Basic info
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ja_JP")
            dateFormatter.dateFormat = "yyyy年M月d日"

            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "ja_JP")
            timeFormatter.dateFormat = "yyyy/MM/dd HH:mm"

            drawText("物件名:  \(property.name)", fontSize: 13)
            if !property.address.isEmpty {
                drawText("住所:    \(property.address)", fontSize: 13)
            }
            drawText("作業日:  \(dateFormatter.string(from: draft.workDate))", fontSize: 13)
            drawText("作業者:  \(draft.workerName)", fontSize: 13)
            y += 4
            drawSeparator()

            // Sections
            for section in template.sections {
                checkSpace(60)
                drawText("■ \(section.title)", fontSize: 15, bold: true)

                if !section.description.isEmpty {
                    drawText(section.description, fontSize: 10, color: .darkGray)
                }

                switch section.type {
                case .photo:
                    if section.perFloor {
                        for floor in stride(from: property.floors, through: 1, by: -1) {
                            drawText("\(floor)F", fontSize: 12, bold: true, color: .darkGray)
                            let photos = draft.photosFor(sectionId: section.id, floor: floor)
                            if photos.isEmpty {
                                drawText("  （写真なし）", fontSize: 10, color: .gray)
                            } else {
                                for photo in photos { drawPhoto(photo) }
                            }
                        }
                    } else {
                        let photos = draft.photosFor(sectionId: section.id)
                        if photos.isEmpty {
                            drawText("  （写真なし）", fontSize: 10, color: .gray)
                        } else {
                            for photo in photos { drawPhoto(photo) }
                        }
                    }

                case .checklist:
                    let checks = draft.checks[section.id] ?? []
                    for (i, item) in section.checklistItems.enumerated() {
                        let checked = i < checks.count && checks[i]
                        let mark = checked ? "☑" : "☐"
                        let status = checked ? "済" : "未"
                        drawText("\(mark) \(item)  [\(status)]", fontSize: 12)
                    }

                case .text:
                    let text = draft.texts[section.id] ?? ""
                    if text.isEmpty {
                        drawText("  （記入なし）", fontSize: 10, color: .gray)
                    } else {
                        drawText("  \(text)", fontSize: 12)
                    }
                }

                if !section.note.isEmpty {
                    drawText("※ \(section.note)", fontSize: 9, color: .gray)
                }

                drawSeparator()
            }

            // Footer
            checkSpace(30)
            drawText("送信日時: \(timeFormatter.string(from: Date()))", fontSize: 10, color: .gray)
        }
    }
}
