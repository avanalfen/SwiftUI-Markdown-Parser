import SwiftUI

// Top-level view that takes an array of MarkdownElements and renders them in a vertical stack
struct MarkdownView: View {
    let elements: [MarkdownElement]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<elements.count, id: \.self) { index in
                MarkdownElementView(element: elements[index])
            }
        }
    }
}

// View that renders a single MarkdownElement, handling different types recursively
struct MarkdownElementView: View {
    let element: MarkdownElement

    var body: some View {
        switch element {
        case .header(let level, let text):
            renderTextSpans(text, font: headerFont(for: level))

        case .paragraph(let text):
            renderTextSpans(text, font: .body)
            
        case .list(let items, let isOrdered):
            VStack(alignment: .leading) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    let prefix = isOrdered ? "\(index + 1). " : " •"
                    if let firstElement = item.content.first {
                        VStack(alignment: .leading) {
                            HStack(alignment: .top) {
                                Text(prefix).frame(width: 30, alignment: .leading)
                                    .font(.subheadline)
                                MarkdownElementView(element: firstElement)
                            }
                            ForEach(1..<item.content.count, id: \.self) { subIndex in
                                MarkdownElementView(element: item.content[subIndex])
                                    .padding(.leading, 30)
                            }
                        }
                    } else {
                        Text(prefix)
                    }
                }
            }
            
        case .divider:
            Divider()
        }
    }
    
    // Helper function to render an array of TextSpan into a combined Text view with styles
    private func renderTextSpans(_ spans: [TextSpan], font: Font) -> Text {
        var result = Text("")
        for span in spans {
            let text = Text(span.text).font(font)
            if span.style == .bold {
                result = result + text.bold()
            } else if span.style == .italic {
                result = result + text.italic()
            } else if span.style == .boldItalic {
                result = result + text.bold().italic()
            } else {
                result = result + text
            }
        }
        return result
    }

    private func headerFont(for level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        case 5: return .subheadline
        case 6: return .caption
        default: return .body
        }
    }
}

// Preview provider for testing the view in Xcode
struct MarkdownView_Previews: PreviewProvider {
    static var previews: some View {
        let parser = MarkdownParser()
        let markdown = """
        # Header 1 with **bold**
        *Italic* text with **bold** part
        - List item 1
            - Nested item
                - Second Nested item
            Nested text without bullet
        - List item 2
        ---
        1. ***Bold Italic*** item 1
        2. Ordered item 2
        """
        let elements = parser.parse(markdown: markdown)
        return MarkdownView(elements: elements)
            .padding()
    }
}
