import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

/// 自动化层：封装 macOS 底层操作
@MainActor
final class AutomationLayer: ObservableObject {
    // MARK: - 屏幕捕获
    
    func captureScreen() async throws -> Data {
        // 使用 ScreenCaptureKit 捕获主屏幕
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "Automation", code: -1, userInfo: [NSLocalizedDescriptionKey: "无可用显示器"])
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 5
        
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let output = try await withCheckedThrowingContinuation { continuation in
            do {
                try stream.addStreamOutput(FrameCaptureDelegate(continuation: continuation), type: .screen, sampleHandlerQueue: .main)
                try stream.startCapture()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        let cgImage = output
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:]) ?? Data()
    }
    
    // MARK: - 窗口管理
    
    func getOpenWindows() async -> [Observation.WindowInfo] {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        
        return windowList.compactMap { dict in
            guard let ownerName = dict[kCGWindowOwnerName as String] as? String,
                  let windowTitle = dict[kCGWindowName as String] as? String,
                  let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat,
                  let layer = dict[kCGWindowLayer as String] as? Int,
                  layer == 0 else { return nil }
            
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            let isActive = (dict[kCGWindowAlpha as String] as? Double ?? 1.0) > 0.5
            
            return Observation.WindowInfo(appName: ownerName, windowTitle: windowTitle, bounds: bounds, isActive: isActive)
        }
    }
    
    func getActiveApplication() async -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
    
    // MARK: - 剪贴板与选中文本
    
    func getClipboard() async -> String? {
        NSPasteboard.general.string(forType: .string)
    }
    
    func getSelectedText() async -> String? {
        // 使用 Accessibility API 获取选中文本
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AXUIElement?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let element = focusedElement else { return nil }
        
        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        if textResult == .success, let text = selectedText as? String {
            return text
        }
        
        // 尝试获取选中范围
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        if rangeResult == .success, let rangeValue = selectedRange as? AXValue {
            var range = CFRange()
            AXValueGetValue(rangeValue, .cfRange, &range)
            var textValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue) == .success,
               let fullText = textValue as? String {
                let start = fullText.index(fullText.startIndex, offsetBy: range.location)
                let end = fullText.index(start, offsetBy: range.length)
                return String(fullText[start..<end])
            }
        }
        return nil
    }
    
    func setClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    // MARK: - 鼠标操作
    
    func click(x: Double, y: Double) async throws {
        let point = CGPoint(x: x, y: y)
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    func doubleClick(x: Double, y: Double) async throws {
        try await click(x: x, y: y)
        try await Task.sleep(nanoseconds: 100_000_000)
        try await click(x: x, y: y)
    }
    
    func rightClick(x: Double, y: Double) async throws {
        let point = CGPoint(x: x, y: y)
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right)
        mouseDown?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 50_000_000)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    func moveMouse(to point: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
    
    func drag(from: CGPoint, to: CGPoint) async throws {
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: from, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // 移动到目标位置
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: to, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: to, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    func scroll(dx: Double, dy: Double) async throws {
        let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)
    }
    
    // MARK: - 键盘操作
    
    func type(text: String) async throws {
        for char in text {
            let keyCode = keyCodeForCharacter(char)
            let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms per char
        }
    }
    
    func pressKey(_ key: String) async throws {
        let keyCode = keyCodeForSpecialKey(key)
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
    
    func pressHotKey(modifiers: CGEventFlags, key: UInt16) {
        let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
        down?.flags = modifiers
        down?.post(tap: .cghidEventTap)
        
        let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
        up?.flags = modifiers
        up?.post(tap: .cghidEventTap)
    }
    
    // MARK: - 应用控制
    
    func openApplication(named name: String) async throws {
        if let url = NSWorkspace.shared.urlForApplication(withName: name) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            throw NSError(domain: "Automation", code: -1, userInfo: [NSLocalizedDescriptionKey: "找不到应用: \(name)"])
        }
    }
    
    func closeApplication(named name: String) async throws {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: name) {
            app.terminate()
        }
    }
    
    func activateApplication(named name: String) async throws {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: name) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
    
    // MARK: - 文件操作
    
    func openFile(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
    
    func saveFile(at path: String, content: String) async throws {
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func readFile(at path: String) async throws -> String {
        let url = URL(fileURLWithPath: path)
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    // MARK: - Shell 命令
    
    func runShellCommand(_ command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - 辅助方法
    
    private func keyCodeForCharacter(_ char: Character) -> CGKeyCode {
        // 简化：仅支持 ASCII 字符
        let keyMap: [Character: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38,
            "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
            "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
            " ": 49, "\n": 36, "\t": 48
        ]
        return keyMap[char.lowercased().first!] ?? 0
    }
    
    private func keyCodeForSpecialKey(_ key: String) -> CGKeyCode {
        let keyMap: [String: CGKeyCode] = [
            "enter": 36, "return": 36, "tab": 48, "space": 49, "escape": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
            "delete": 51, "backspace": 51, "home": 115, "end": 119,
            "pageup": 116, "pagedown": 121
        ]
        return keyMap[key.lowercased()] ?? 0
    }
}

// MARK: - ScreenCaptureKit 帧捕获代理
private class FrameCaptureDelegate: NSObject, SCStreamOutput {
    let continuation: CheckedContinuation<CGImage, Error>
    
    init(continuation: CheckedContinuation<CGImage, Error>) {
        self.continuation = continuation
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let imageBuffer = sampleBuffer.imageBuffer else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            continuation.resume(returning: cgImage)
        } else {
            continuation.resume(throwing: NSError(domain: "FrameCapture", code: -1, userInfo: nil))
        }
    }
}