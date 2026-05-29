import AppKit

struct StatusBarUI {
    
    static func makeTimerCircle(secondsLeft: Double, size: CGFloat = 14) -> NSImage {
        let maxCycle: Double = 5400 // 90 min cycle
        let elapsed = max(0, min(1, 1.0 - secondsLeft / maxCycle))

        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = (size - 2) / 2

            let bgPath = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            NSColor.white.withAlphaComponent(0.35).setFill()
            bgPath.fill()
            NSColor.white.withAlphaComponent(0.6).setStroke()
            bgPath.lineWidth = 0.75
            bgPath.stroke()

            if elapsed > 0.01 {
                let startAngle: CGFloat = 90
                let endAngle = startAngle - CGFloat(elapsed * 360)

                let piePath = NSBezierPath()
                piePath.move(to: center)
                piePath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                piePath.close()
                NSColor.white.withAlphaComponent(0.85).setFill()
                piePath.fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    static func makeSparkline(history: [Int], color: NSColor, size: NSSize = NSSize(width: 30, height: 12)) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            let count = max(history.count, 2)
            let stepX = rect.width / CGFloat(count - 1)
            
            var points: [NSPoint] = []
            for (i, val) in history.enumerated() {
                let x = CGFloat(i) * stepX
                let y = (CGFloat(val) / 100.0) * rect.height
                points.append(NSPoint(x: x, y: y))
            }
            
            let fillPath = NSBezierPath()
            fillPath.move(to: NSPoint(x: 0, y: 0))
            fillPath.line(to: points[0])
            for pt in points.dropFirst() {
                fillPath.line(to: pt)
            }
            fillPath.line(to: NSPoint(x: rect.width, y: 0))
            fillPath.close()
            
            color.withAlphaComponent(0.85).setFill()
            fillPath.fill()
            
            return true
        }
        img.isTemplate = false
        return img
    }

    static func makeCenteredBlock(text: String, font: NSFont, color: NSColor, width: CGFloat) -> NSTextAttachment {
        let attrStr = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let size = attrStr.size()
        let height: CGFloat = 16
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let x = (rect.width - size.width) / 2
            let y = (rect.height - size.height) / 2 + 0.5
            attrStr.draw(at: NSPoint(x: x, y: y))
            return true
        }
        img.isTemplate = false
        let attachment = NSTextAttachment()
        attachment.image = img
        attachment.bounds = CGRect(x: 0, y: -2, width: width, height: height)
        return attachment
    }


    static func colorForResourceUsage(_ pct: Int) -> NSColor {
        if pct >= 90 { return NSColor.systemRed }
        if pct >= 75 { return NSColor.systemOrange }
        if pct >= 60 { return NSColor.systemYellow }
        return NSColor.systemGreen
    }

    static func makeBarTitle(models: [ModelQuota], daemonOnline: Bool, cacheFormatted: String, cacheMB: Double, cpu: Int, gpu: Int, ram: Int, historyCPU: [Int], historyGPU: [Int], historyRAM: [Int], credits: String?) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let pctFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let sepFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        let sep = NSAttributedString(string: "  |  ", attributes: [
            .font: sepFont, .foregroundColor: NSColor.tertiaryLabelColor
        ])

        // 1. Cache
        let cacheColor = colorForCacheMB(cacheMB)
        let cacheStr = NSAttributedString(string: cacheFormatted, attributes: [
            .font: pctFont, .foregroundColor: cacheColor
        ])
        result.append(cacheStr)
        result.append(sep)

        // 2. Models
        if models.isEmpty {
            if !daemonOnline {
                let offStr = NSAttributedString(string: "OFF", attributes: [
                    .font: pctFont, .foregroundColor: NSColor.tertiaryLabelColor
                ])
                result.append(offStr)
                result.append(sep)
            }
        } else {
            let grouped = groupModels(models, isMenuBar: true)
            for g in grouped {
                let color = colorForPercentage(g.pct)

                let formattedPctStr = "\(g.pct)%"
                let pctAttachment = makeCenteredBlock(text: formattedPctStr, font: pctFont, color: color, width: 38)
                result.append(NSAttributedString(attachment: pctAttachment))
                result.append(sep)
            }
        }

        if let cr = credits {
            let crStr = NSAttributedString(string: "\(cr) CR", attributes: [
                .font: pctFont, .foregroundColor: NSColor.systemYellow
            ])
            result.append(crStr)
            result.append(sep)
        }

        // 3. Stats
        let stats: [(String, Int, [Int], NSColor)] = [
            ("CPU", cpu, historyCPU, colorForResourceUsage(cpu)),
            ("GPU", gpu, historyGPU, colorForResourceUsage(gpu)),
            ("RAM", ram, historyRAM, colorForResourceUsage(ram))
        ]
        for (idx, stat) in stats.enumerated() {
            let color = stat.3
            
            let sparkImg = makeSparkline(history: stat.2, color: color)
            let attachment = NSTextAttachment()
            attachment.image = sparkImg
            attachment.bounds = CGRect(x: 0, y: -1, width: sparkImg.size.width, height: sparkImg.size.height)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: " ", attributes: [.font: sepFont]))
            
            let formattedPctStr = "\(stat.1)%"
            let pctAttachment = makeCenteredBlock(text: formattedPctStr, font: pctFont, color: NSColor.labelColor, width: 38)
            result.append(NSAttributedString(attachment: pctAttachment))
            
            if idx < stats.count - 1 {
                result.append(sep)
            }
        }

        return result
    }

    static func groupModels(_ models: [ModelQuota], isMenuBar: Bool = false) -> [(name: String, pct: Int, secsLeft: Double)] {
        if isMenuBar {
            struct Group {
                let name: String
                let keywords: [String]
            }
            let groups = [
                Group(name: "Gemini", keywords: ["gemini", "pro", "flash", "3.5", "3.1"]),
                Group(name: "Claude/OSS", keywords: ["claude", "sonnet", "opus", "haiku", "oss", "llama", "mistral", "mixtral", "gemma", "qwen", "deepseek"])
            ]

            var result: [(name: String, pct: Int, secsLeft: Double)] = []
            for group in groups {
                let matching = models.filter { m in
                    let l = m.label.lowercased()
                    return group.keywords.contains(where: { l.contains($0) })
                }
                if !matching.isEmpty {
                    let minPct = Int(matching.map(\.remainingPercentage).min() ?? 0)
                    let minSecs = matching.map(\.secondsUntilReset).min() ?? 0
                    result.append((name: group.name, pct: minPct, secsLeft: minSecs))
                }
            }
            return result
        } else {
            var result: [(name: String, pct: Int, secsLeft: Double)] = []
            
            let getMatching: (@Sendable (ModelQuota) -> Bool) -> (minPct: Int, minSecs: Double)? = { predicate in
                let matching = models.filter(predicate)
                guard !matching.isEmpty else { return nil }
                let minPct = Int(matching.map(\.remainingPercentage).min() ?? 0)
                let minSecs = matching.map(\.secondsUntilReset).min() ?? 0
                return (minPct, minSecs)
            }
            
            // Gemini 3.5
            if let stats = getMatching({ $0.label.lowercased().contains("3.5") }) {
                result.append((name: "Gemini 3.5", pct: stats.minPct, secsLeft: stats.minSecs))
            }
            
            // Gemini 3.1 Pro
            if let stats = getMatching({ m in
                let l = m.label.lowercased()
                return (l.contains("3.1") || l.contains("pro")) && !l.contains("3.5")
            }) {
                result.append((name: "Gemini 3.1 Pro", pct: stats.minPct, secsLeft: stats.minSecs))
            }
            
            // Claude/OSS
            let claudeKeywords = ["claude", "sonnet", "opus", "haiku", "oss", "llama", "mistral", "mixtral", "gemma", "qwen", "deepseek"]
            if let stats = getMatching({ m in
                let l = m.label.lowercased()
                return claudeKeywords.contains(where: { l.contains($0) })
            }) {
                result.append((name: "Claude/OSS", pct: stats.minPct, secsLeft: stats.minSecs))
            }
            
            return result
        }
    }

    static func colorForPercentage(_ pct: Int) -> NSColor {
        if pct >= 80 { return NSColor.systemGreen }
        if pct >= 60 { return NSColor.systemYellow }
        if pct >= 40 { return NSColor.systemOrange }
        return NSColor.systemRed
    }

    static func colorForCacheMB(_ mb: Double) -> NSColor {
        if mb < 100 { return NSColor.systemGreen }
        if mb < 300 { return NSColor.systemYellow }
        if mb < 500 { return NSColor.systemOrange }
        return NSColor.systemRed
    }
}
