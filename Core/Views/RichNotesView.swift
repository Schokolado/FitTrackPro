import SwiftUI
import UIKit

// MARK: - Rich Notes Parser

enum RichNotesParser {
    /// Parses inline formatting: **bold**, *italic*, ~~strikethrough~~, `code`,
    /// <u>underline</u>, [title](url) links, and auto-detected bare URLs.
    static func parseInline(_ input: String) -> AttributedString {
        guard !input.isEmpty else { return AttributedString("") }
        
        var attr: AttributedString
        if let parsed = try? AttributedString(
            markdown: input,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            attr = parsed
        } else {
            attr = AttributedString(input)
        }
        
        // Parse <u>...</u> underline tags (preserving nested markdown formatting)
        let underlinePattern = "<u>(.*?)</u>"
        if let regex = try? NSRegularExpression(pattern: underlinePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let plain = String(attr.characters)
            let nsRange = NSRange(plain.startIndex..<plain.endIndex, in: plain)
            let matches = regex.matches(in: plain, options: [], range: nsRange)
            
            for match in matches.reversed() {
                guard let fullRange = Range(match.range(at: 0), in: plain),
                      let innerRange = Range(match.range(at: 1), in: plain),
                      let attrFullStart = AttributedString.Index(fullRange.lowerBound, within: attr),
                      let attrFullEnd = AttributedString.Index(fullRange.upperBound, within: attr),
                      let attrInnerStart = AttributedString.Index(innerRange.lowerBound, within: attr),
                      let attrInnerEnd = AttributedString.Index(innerRange.upperBound, within: attr) else {
                    continue
                }
                
                var innerAttr = AttributedString(attr[attrInnerStart..<attrInnerEnd])
                innerAttr.underlineStyle = .single
                attr.replaceSubrange(attrFullStart..<attrFullEnd, with: innerAttr)
            }
        }
        
        // Auto-detect bare URLs that are not already markdown links
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let plain = String(attr.characters)
            let nsRange = NSRange(plain.startIndex..<plain.endIndex, in: plain)
            let matches = detector.matches(in: plain, options: [], range: nsRange)
            
            for match in matches {
                guard let url = match.url,
                      let strRange = Range(match.range, in: plain),
                      let attrStart = AttributedString.Index(strRange.lowerBound, within: attr),
                      let attrEnd = AttributedString.Index(strRange.upperBound, within: attr) else {
                    continue
                }
                if attr[attrStart..<attrEnd].link == nil {
                    attr[attrStart..<attrEnd].link = url
                }
            }
        }
        
        // Style links consistently
        for run in attr.runs {
            if run.link != nil {
                attr[run.range].foregroundColor = .brand
                attr[run.range].underlineStyle = .single
            }
        }
        
        return attr
    }
    
    /// Converts multi-line formatted notes into a single compact AttributedString for 2-line previews.
    static func parseCompactPreview(_ input: String) -> AttributedString {
        let lines = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "---" && $0 != "***" }
        
        let normalized = lines.map { line -> String in
            if line.hasPrefix("### ") {
                return "**\(line.dropFirst(4))**"
            } else if line.hasPrefix("## ") {
                return "**\(line.dropFirst(3))**"
            } else if line.hasPrefix("# ") {
                return "**\(line.dropFirst(2))**"
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                return "• \(line.dropFirst(2))"
            }
            return line
        }.joined(separator: "\n")
        
        return parseInline(normalized)
    }
}

// MARK: - Rich Notes Display View

struct RichNotesView: View {
    let text: String
    var baseFont: Font = .body
    var textColor: Color = .primary
    
    var body: some View {
        let lines = text.components(separatedBy: "\n")
        
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, rawLine in
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                
                if trimmed.isEmpty {
                    Spacer().frame(height: 6)
                } else if trimmed == "---" || trimmed == "***" {
                    Divider()
                        .padding(.vertical, 4)
                } else if trimmed.hasPrefix("### ") {
                    let content = String(trimmed.dropFirst(4))
                    Text(RichNotesParser.parseInline(content))
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                } else if trimmed.hasPrefix("## ") {
                    let content = String(trimmed.dropFirst(3))
                    Text(RichNotesParser.parseInline(content))
                        .font(.headline.bold())
                        .foregroundColor(.primary)
                        .padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                } else if trimmed.hasPrefix("# ") {
                    let content = String(trimmed.dropFirst(2))
                    Text(RichNotesParser.parseInline(content))
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                    let content = String(trimmed.dropFirst(2))
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(baseFont.bold())
                            .foregroundColor(.brand)
                        Text(RichNotesParser.parseInline(content))
                            .font(baseFont)
                            .foregroundColor(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(RichNotesParser.parseInline(rawLine))
                        .font(baseFont)
                        .foregroundColor(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.brand)
    }
}

// MARK: - Rich Notes Editor

final class RichTextEditorController {
    weak var textView: UITextView?
    
    func selectedText() -> String {
        guard let tv = textView,
              let current = tv.text,
              let range = Range(tv.selectedRange, in: current),
              !range.isEmpty else {
            return ""
        }
        return String(current[range])
    }
    
    func wrapSelection(prefix: String, suffix: String, placeholder: String, updateBinding: (String) -> Void) {
        guard let tv = textView else { return }
        let current = tv.text ?? ""
        let nsRange = tv.selectedRange
        
        guard let swiftRange = Range(nsRange, in: current) else { return }
        
        if nsRange.length > 0 {
            let selected = String(current[swiftRange])
            let replacement = prefix + selected + suffix
            let newText = current.replacingCharacters(in: swiftRange, with: replacement)
            tv.text = newText
            updateBinding(newText)
            
            let newStart = nsRange.location + (prefix as NSString).length
            let newLen = (selected as NSString).length
            tv.selectedRange = NSRange(location: newStart, length: newLen)
        } else {
            let replacement = prefix + placeholder + suffix
            let newText = current.replacingCharacters(in: swiftRange, with: replacement)
            tv.text = newText
            updateBinding(newText)
            
            let newStart = nsRange.location + (prefix as NSString).length
            let newLen = (placeholder as NSString).length
            tv.selectedRange = NSRange(location: newStart, length: newLen)
        }
        tv.becomeFirstResponder()
    }
    
    func toggleLinePrefix(_ prefix: String, updateBinding: (String) -> Void) {
        guard let tv = textView else { return }
        let current = (tv.text ?? "") as NSString
        let nsRange = tv.selectedRange
        let lineRange = current.lineRange(for: NSRange(location: nsRange.location, length: 0))
        let lineText = current.substring(with: lineRange)
        
        let knownPrefixes = ["### ", "## ", "# ", "- "]
        var cleanedLine = lineText
        var removedPrefixLen = 0
        var wasSamePrefix = false
        
        for known in knownPrefixes {
            if cleanedLine.hasPrefix(known) {
                cleanedLine = String(cleanedLine.dropFirst(known.count))
                removedPrefixLen = (known as NSString).length
                if known == prefix {
                    wasSamePrefix = true
                }
                break
            }
        }
        
        let updatedLine = wasSamePrefix ? cleanedLine : (prefix + cleanedLine)
        let addedPrefixLen = wasSamePrefix ? 0 : (prefix as NSString).length
        
        let newText = current.replacingCharacters(in: lineRange, with: updatedLine)
        tv.text = newText
        updateBinding(newText)
        
        let newCursorLocation = max(lineRange.location, nsRange.location - removedPrefixLen + addedPrefixLen)
        tv.selectedRange = NSRange(location: min(newCursorLocation, (newText as NSString).length), length: 0)
        tv.becomeFirstResponder()
    }
    
    func insertText(_ snippet: String, updateBinding: (String) -> Void) {
        guard let tv = textView else { return }
        let current = tv.text ?? ""
        let nsRange = tv.selectedRange
        guard let swiftRange = Range(nsRange, in: current) else { return }
        
        let newText = current.replacingCharacters(in: swiftRange, with: snippet)
        tv.text = newText
        updateBinding(newText)
        
        let newPos = nsRange.location + (snippet as NSString).length
        tv.selectedRange = NSRange(location: newPos, length: 0)
        tv.becomeFirstResponder()
    }
}

private struct RichUITextView: UIViewRepresentable {
    @Binding var text: String
    let controller: RichTextEditorController
    
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.textColor = .label
        tv.isEditable = true
        tv.isScrollEnabled = true
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        tv.text = text
        controller.textView = tv
        return tv
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        controller.textView = uiView
        if uiView.text != text {
            let selected = uiView.selectedRange
            uiView.text = text
            let maxLen = (text as NSString).length
            uiView.selectedRange = NSRange(location: min(selected.location, maxLen), length: 0)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichUITextView
        init(_ parent: RichUITextView) {
            self.parent = parent
        }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }
    }
}

struct RichNotesEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 180
    var placeholder: String = "Notizen hier eingeben..."
    
    @State private var showPreview = false
    @State private var controller = RichTextEditorController()
    @State private var showingLinkAlert = false
    @State private var linkTitle = ""
    @State private var linkURL = "https://"
    
    var body: some View {
        VStack(spacing: 8) {
            // Mode Switcher & Formatting Bar
            HStack(spacing: 8) {
                Picker("", selection: $showPreview) {
                    Text("Bearbeiten").tag(false)
                    Text("Vorschau").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                
                Spacer()
            }
            
            if !showPreview {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        formatButton(label: "H1", isBold: true) {
                            controller.toggleLinePrefix("# ") { text = $0 }
                        }
                        formatButton(label: "H2", isBold: true) {
                            controller.toggleLinePrefix("## ") { text = $0 }
                        }
                        
                        Divider().frame(height: 20)
                        
                        formatIconButton(systemName: "bold") {
                            controller.wrapSelection(prefix: "**", suffix: "**", placeholder: "Fetter Text") { text = $0 }
                        }
                        formatIconButton(systemName: "italic") {
                            controller.wrapSelection(prefix: "*", suffix: "*", placeholder: "Kursiv") { text = $0 }
                        }
                        formatIconButton(systemName: "underline") {
                            controller.wrapSelection(prefix: "<u>", suffix: "</u>", placeholder: "Unterstrichen") { text = $0 }
                        }
                        
                        Divider().frame(height: 20)
                        
                        formatIconButton(systemName: "list.bullet") {
                            controller.toggleLinePrefix("- ") { text = $0 }
                        }
                        formatIconButton(systemName: "link") {
                            let selected = controller.selectedText()
                            linkTitle = selected
                            linkURL = "https://"
                            showingLinkAlert = true
                        }
                        formatIconButton(systemName: "minus") {
                            controller.insertText("\n---\n") { text = $0 }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
            
            // Editor or Live Preview
            if showPreview {
                ScrollView {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Keine Notizen für Vorschau.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    } else {
                        RichNotesView(text: text)
                            .padding(12)
                    }
                }
                .frame(minHeight: minHeight)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    RichUITextView(text: $text, controller: controller)
                }
                .frame(minHeight: minHeight)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
        .alert("Link einfügen", isPresented: $showingLinkAlert) {
            TextField("Titel (optional)", text: $linkTitle)
            TextField("URL (z.B. https://...)", text: $linkURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
            Button("Abbrechen", role: .cancel) { }
            Button("Einfügen") {
                let cleanURL = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanURL.isEmpty else { return }
                let cleanTitle = linkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let snippet = cleanTitle.isEmpty ? cleanURL : "[\(cleanTitle)](\(cleanURL))"
                controller.insertText(snippet) { text = $0 }
            }
        } message: {
            Text("Füge einen klickbaren Link zu deinen Notizen hinzu.")
        }
    }
    
    private func formatButton(label: String, isBold: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isBold ? .bold : .medium))
                .foregroundColor(.primary)
                .frame(minWidth: 32, minHeight: 30)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(7)
        }
        .buttonStyle(.borderless)
    }
    
    private func formatIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(minWidth: 32, minHeight: 30)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(7)
        }
        .buttonStyle(.borderless)
    }
}
