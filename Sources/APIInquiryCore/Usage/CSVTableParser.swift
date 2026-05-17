import Foundation

enum CSVTableParser {
    static func parseRows(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInQuotes = false
        var index = text.startIndex

        func finishField() {
            row.append(field)
            field = ""
        }

        func finishRow() {
            finishField()
            if !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                rows.append(row)
            }
            row = []
        }

        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)

            if character == "\"" {
                if isInQuotes, nextIndex < text.endIndex, text[nextIndex] == "\"" {
                    field.append("\"")
                    index = text.index(after: nextIndex)
                    continue
                }

                isInQuotes.toggle()
                index = nextIndex
                continue
            }

            if character == ",", !isInQuotes {
                finishField()
                index = nextIndex
                continue
            }

            if isLineBreak(character), !isInQuotes {
                if character == "\r", nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    index = text.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
                finishRow()
                continue
            }

            field.append(character)
            index = nextIndex
        }

        if isInQuotes {
            throw UsageImportError.invalidCSV("The CSV contains an unterminated quoted field.")
        }

        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        return rows
    }

    private static func isLineBreak(_ character: Character) -> Bool {
        character == "\n" || character == "\r" || character == "\r\n"
    }
}
