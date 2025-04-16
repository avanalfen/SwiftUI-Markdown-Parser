import Foundation

// MARK: - Markdown Parser

/// A class that parses Markdown text into a tree structure of MarkdownElement objects.
class MarkdownParser {

    /// Parses the given Markdown string into an array of Markdown elements.
    /// - Parameter markdown: The Markdown text to parse.
    /// - Returns: An array of top-level Markdown elements.
    func parse(markdown: String) -> [MarkdownElement] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return parseBlocks(lines: lines, minIndentation: 0)
    }

    /// Parses a subset of lines into Markdown elements based on a minimum indentation level.
    /// - Parameters:
    ///   - lines: The array of text lines to parse.
    ///   - minIndentation: The minimum indentation level for blocks in this scope.
    /// - Returns: An array of parsed Markdown elements.
    private func parseBlocks(lines: [String], minIndentation: Int) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let indentation = getIndentation(line)

            // Stop if indentation is less than the minimum (outside current block)
            if indentation < minIndentation {
                break
            }

            let trimmedLine = line.dropFirst(indentation).trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty {
                i += 1
                continue
            }

            // Parse headers (e.g., # Header)
            if let header = parseHeader(trimmedLine) {
                let textSpans = parseInline(header.text)
                elements.append(.header(level: header.level, text: textSpans))
                i += 1
            }
            // Parse lists (bulleted or numbered)
            else if let listType = parseListMarker(trimmedLine) {
                var listItems: [ListItem] = []
                while i < lines.count {
                    let currentLine = lines[i]
                    let currentIndentation = getIndentation(currentLine)
                    if currentIndentation != indentation {
                        break
                    }
                    let currentTrimmed = currentLine.dropFirst(currentIndentation).trimmingCharacters(in: .whitespaces)
                    if let currentListType = parseListMarker(currentTrimmed), currentListType == listType {
                        // Extract content after the list marker
                        let markerLength = currentTrimmed.prefix(while: { !$0.isWhitespace }).count + 1
                        let initialContent = String(currentLine.dropFirst(currentIndentation + markerLength)).trimmingCharacters(in: .whitespaces)
                        var itemContent: [MarkdownElement] = []
                        if !initialContent.isEmpty {
                            itemContent.append(.paragraph(text: parseInline(initialContent)))
                        }
                        i += 1
                        // Parse nested content with greater indentation
                        let subMinIndentation = indentation + 2
                        let subLines = lines[i...].prefix(while: { getIndentation($0) >= subMinIndentation })
                        let subElements = parseBlocks(lines: Array(subLines), minIndentation: subMinIndentation)
                        itemContent.append(contentsOf: subElements)
                        i += subLines.count
                        listItems.append(ListItem(content: itemContent))
                    } else {
                        break
                    }
                }
                elements.append(.list(items: listItems, isOrdered: listType == .ordered))
            }
            // Parse dividers (e.g., ---)
            else if isDivider(trimmedLine) {
                elements.append(.divider)
                i += 1
            }
            // Parse paragraphs
            else {
                var paragraphLines: [String] = []
                let currentLine = lines[i]
                let currentIndentation = getIndentation(currentLine)
                if currentIndentation < minIndentation {
                    break
                }
                let currentTrimmed = currentLine.dropFirst(currentIndentation).trimmingCharacters(in: .whitespaces)
                if currentTrimmed.isEmpty {
                    break
                }
                paragraphLines.append(String(currentTrimmed))
                i += 1
                let paragraphText = paragraphLines.joined(separator: " ")
                elements.append(.paragraph(text: parseInline(paragraphText)))
            }
        }
        return elements
    }

    /// Calculates the number of leading spaces in a line.
    /// - Parameter line: The text line to analyze.
    /// - Returns: The number of leading spaces.
    private func getIndentation(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    /// Parses a header line if it matches the pattern (e.g., # Header).
    /// - Parameter line: The line to parse.
    /// - Returns: A tuple with the header level and text, or nil if not a header.
    private func parseHeader(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        for char in line {
            if char == "#" {
                level += 1
            } else if char == " " {
                break
            } else {
                return nil
            }
        }
        if level > 0 && level <= 6 {
            let textStart = line.index(line.startIndex, offsetBy: level + 1)
            let text = String(line[textStart...]).trimmingCharacters(in: .whitespaces)
            return (level, text)
        }
        return nil
    }

    /// Determines if a line starts with a list marker and its type.
    /// - Parameter line: The line to parse.
    /// - Returns: The list type (ordered or unordered) or nil if not a list item.
    private func parseListMarker(_ line: String) -> ListType? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if ["- ", "* ", "+ "].contains(where: trimmed.hasPrefix) {
            return .unordered
        } else {
            let components = trimmed.split(separator: " ", maxSplits: 1)
            if components.count == 2, let _ = Int(components[0]), components[0].hasSuffix(".") {
                return .ordered
            }
        }
        return nil
    }

    /// Checks if a line is a divider.
    /// - Parameter line: The line to check.
    /// - Returns: True if the line is a divider (---, ***, ___).
    private func isDivider(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return ["---", "***", "___"].contains(trimmed)
    }

    /// Parses inline text for formatting (e.g., bold with ** or __, italic with * or _).
    /// - Parameter text: The text to parse.
    /// - Returns: An array of text spans with styles.
    private func parseInline(_ text: String) -> [TextSpan] {
        var spans: [TextSpan] = []
        var currentText = ""
        var inBold = false
        var inItalic = false
        var i = text.startIndex

        while i < text.endIndex {
            if text[i...].hasPrefix("**") || text[i...].hasPrefix("__") {
                if !currentText.isEmpty {
                    let style = getCurrentStyle(inBold: inBold, inItalic: inItalic)
                    spans.append(TextSpan(text: currentText, style: style))
                    currentText = ""
                }
                inBold.toggle()
                i = text.index(i, offsetBy: 2)
            } else if text[i...].hasPrefix("*") || text[i...].hasPrefix("_") {
                if !currentText.isEmpty {
                    let style = getCurrentStyle(inBold: inBold, inItalic: inItalic)
                    spans.append(TextSpan(text: currentText, style: style))
                    currentText = ""
                }
                inItalic.toggle()
                i = text.index(i, offsetBy: 1)
            } else {
                currentText.append(text[i])
                i = text.index(after: i)
            }
        }
        if !currentText.isEmpty {
            let style = getCurrentStyle(inBold: inBold, inItalic: inItalic)
            spans.append(TextSpan(text: currentText, style: style))
        }
        return spans
    }

    /// Determines the current text style based on the bold and italic flags.
    /// - Parameters:
    ///   - inBold: Whether the text is currently in bold.
    ///   - inItalic: Whether the text is currently in italic.
    /// - Returns: The appropriate TextStyle.
    private func getCurrentStyle(inBold: Bool, inItalic: Bool) -> TextStyle {
        if inBold && inItalic {
            return .boldItalic
        } else if inBold {
            return .bold
        } else if inItalic {
            return .italic
        } else {
            return .plain
        }
    }
}

// MARK: - Data Model

/// Represents a Markdown element in the tree structure.
enum MarkdownElement {
    case header(level: Int, text: [TextSpan])
    case paragraph(text: [TextSpan])
    case list(items: [ListItem], isOrdered: Bool)
    case divider
}

/// Represents a single item within a list, which can contain multiple elements (e.g., text, sublists).
struct ListItem {
    let content: [MarkdownElement]
}

/// Represents a span of text with a specific style (e.g., plain, bold, italic, boldItalic).
struct TextSpan {
    let text: String
    let style: TextStyle
}

/// Defines the style of a text span.
enum TextStyle {
    case plain
    case bold
    case italic
    case boldItalic
}

/// Indicates whether a list is ordered or unordered.
enum ListType {
    case unordered
    case ordered
}
