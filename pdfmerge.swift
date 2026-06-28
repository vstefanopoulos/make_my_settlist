// pdfmerge — merge all PDFs in a directory into one file using macOS PDFKit
//
// Build universal binary (requires Xcode or CLT):
//   xcrun swiftc -O pdfmerge.swift -target arm64-apple-macos12  -o pdfmerge-arm64
//   xcrun swiftc -O pdfmerge.swift -target x86_64-apple-macos12 -o pdfmerge-x86_64
//   lipo -create pdfmerge-arm64 pdfmerge-x86_64 -output pdfmerge
//
// Then attach the resulting `pdfmerge` binary to a GitHub Release.

import Foundation
import PDFKit

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: pdfmerge <src_dir> <output.pdf>\n", stderr)
    exit(1)
}

let srcDir    = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

// Natural sort key: splits "03 My Song.pdf" into ["03", " my song.pdf"]
// so numeric chunks compare by value, not lexicographically.
func naturalSortKey(_ s: String) -> [String] {
    var parts: [String] = []
    var buf = ""
    var inDigit = false
    for ch in s.lowercased() {
        let d = ch.isNumber
        if buf.isEmpty || d == inDigit {
            buf.append(ch)
        } else {
            parts.append(buf)
            buf = String(ch)
        }
        inDigit = d
    }
    if !buf.isEmpty { parts.append(buf) }
    return parts
}

func naturalLess(_ a: String, _ b: String) -> Bool {
    let ka = naturalSortKey(a), kb = naturalSortKey(b)
    for (pa, pb) in zip(ka, kb) {
        if pa == pb { continue }
        if let ia = Int(pa), let ib = Int(pb) { return ia < ib }
        return pa < pb
    }
    return ka.count < kb.count
}

guard let entries = try? FileManager.default.contentsOfDirectory(atPath: srcDir) else {
    fputs("Error: cannot read directory \(srcDir)\n", stderr)
    exit(1)
}

let pdfNames = entries
    .filter  { $0.lowercased().hasSuffix(".pdf") }
    .sorted  { naturalLess($0, $1) }

guard !pdfNames.isEmpty else {
    fputs("Warning: no PDFs found in \(srcDir)\n", stderr)
    exit(1)
}

let merged = PDFDocument()
let baseURL = URL(fileURLWithPath: srcDir)

for name in pdfNames {
    let url = baseURL.appendingPathComponent(name)
    guard let doc = PDFDocument(url: url) else {
        fputs("Warning: could not open \(name) — skipping\n", stderr)
        continue
    }
    for i in 0..<doc.pageCount {
        if let page = doc.page(at: i) {
            merged.insert(page, at: merged.pageCount)
        }
    }
}

guard merged.pageCount > 0 else {
    fputs("Error: no pages collected\n", stderr)
    exit(1)
}

if !merged.write(to: URL(fileURLWithPath: outputPath)) {
    fputs("Error: failed to write \(outputPath)\n", stderr)
    exit(1)
}
