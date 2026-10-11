//
//  CodeEditor.swift
//  Scope
//
//  A plain-text code editor with zsh highlighting. SwiftUI's TextEditor can't colour
//  ranges, so this wraps NSTextView. Smart quotes, dashes and text replacement are
//  switched off: they would silently corrupt shell code.
//

import AppKit
import SwiftUI

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.setAccessibilityLabel(accessibilityLabel)

        textView.string = text
        context.coordinator.highlight(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Skip while an input method is composing, and when the change came from the user typing.
        guard textView.string != text, !textView.hasMarkedText() else { return }
        let selection = textView.selectedRange()
        textView.string = text
        textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        context.coordinator.highlight(textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor

        init(_ parent: CodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            highlight(textView)
        }

        func highlight(_ textView: NSTextView) {
            let storage = textView.textStorage
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

            storage?.beginEditing()
            storage?.setAttributes([.font: font, .foregroundColor: NSColor.labelColor], range: fullRange)
            for span in ZshHighlighter.spans(in: textView.string) {
                storage?.addAttribute(.foregroundColor, value: Self.color(for: span.kind), range: span.range)
            }
            storage?.endEditing()

            textView.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor]
        }

        private static func color(for kind: ZshHighlighter.Kind) -> NSColor {
            switch kind {
            case .comment: .secondaryLabelColor
            case .string: .systemGreen
            case .variable: .systemCyan
            case .keyword: .systemPurple
            }
        }
    }
}
