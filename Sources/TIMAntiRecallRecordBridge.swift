import Foundation
import UIKit

@objc(TIMAntiRecallRecordBridge)
public final class TIMAntiRecallRecordBridge: NSObject {
    private static func timantirecallTypeName(_ mirror: Mirror) -> String {
        return String(reflecting: mirror.subjectType)
    }
    private static func timantirecallNameMatches(_ name: String, _ leaf: String) -> Bool {
        return name.hasSuffix("." + leaf) || name.contains("." + leaf + "<")
    }
    // Target NTAIOBaseCellView stores an optional Swift viewModel. Read the
    // current reference at UIKit layout/window boundaries, including Swift calls
    // which do not dispatch through the Objective-C bindViewModel: thunk.
    @objc(timantirecall_currentModelForView:)
    public static func timantirecall_currentModel(forView view: AnyObject) -> AnyObject? {
        var cursor: Mirror? = Mirror(reflecting: view)
        var levels = 0
        while let mirror = cursor, levels < 16 {
            levels += 1
            if timantirecallNameMatches(timantirecallTypeName(mirror), "NTAIOBaseCellView") {
                let fields = mirror.children.prefix(64).filter { $0.label == "viewModel" }
                guard fields.count == 1 else { return nil }
                let value = fields[0].value
                let optional = Mirror(reflecting: value)
                if optional.displayStyle == .optional {
                    guard let child = optional.children.first else { return nil }
                    return child.value as? NSObject
                }
                return value as? NSObject
            }
            cursor = mirror.superclassMirror
        }
        return nil
    }
    // TIM 4.1.0.81 NTAIOCellView descriptor 0x10b5ef3bc stores content/avatar.
    // Return the live UIKit objects, never guess a bubble from labels or pixels.
    @objc(timantirecall_replayViewsForRow:)
    public static func timantirecall_replayViews(forRow row: UIView) -> [String: UIView]? {
        var cursor: Mirror? = Mirror(reflecting: row)
        var levels = 0
        while let mirror = cursor, levels < 16 {
            levels += 1
            if timantirecallNameMatches(timantirecallTypeName(mirror), "NTAIOCellView") {
                var result: [String: UIView] = [:]
                for field in mirror.children.prefix(64) {
                    guard let label = field.label, ["content", "avatar", "title", "status", "checkView", "tailContainerView"].contains(label) else { continue }
                    var value = field.value
                    let optional = Mirror(reflecting: value)
                    if optional.displayStyle == .optional {
                        guard let child = optional.children.first else { continue }
                        value = child.value
                    }
                    guard result[label] == nil, let view = value as? UIView,
                          view !== row, view.isDescendant(of: row) else { return nil }
                    result[label] = view
                }
                return result["content"] == nil ? nil : result
            }
            cursor = mirror.superclassMirror
        }
        return nil
    }
    // NTAIOChatBaseViewController.chatContext is inherited Swift storage, not an ObjC getter.
    @objc(timantirecall_replayChatContextForController:)
    public static func timantirecall_replayChatContext(forController controller: UIViewController) -> NSObject? {
        var cursor: Mirror? = Mirror(reflecting: controller)
        var levels = 0
        var isChat = false
        while let mirror = cursor, levels < 16 {
            levels += 1
            let name = timantirecallTypeName(mirror)
            if timantirecallNameMatches(name, "NTAIOChatViewController") { isChat = true }
            if isChat && timantirecallNameMatches(name, "NTAIOChatBaseViewController") {
                let fields = mirror.children.prefix(64).filter { $0.label == "chatContext" }
                guard fields.count == 1 else { return nil }
                var value = fields[0].value
                let optional = Mirror(reflecting: value)
                if optional.displayStyle == .optional {
                    guard let child = optional.children.first else { return nil }
                    value = child.value
                }
                guard timantirecallNameMatches(timantirecallTypeName(Mirror(reflecting: value)), "AIOChatContext") else { return nil }
                return value as? NSObject
            }
            cursor = mirror.superclassMirror
        }
        return nil
    }
    @objc(timantirecall_observeReplayScroll:changed:)
    public static func timantirecall_observeReplayScroll(_ scroll: UIScrollView, changed: @escaping () -> Void) -> NSObject {
        return scroll.observe(\.contentOffset, options: [.old, .new]) { _, change in
            if let old = change.oldValue, let new = change.newValue, old != new { changed() }
        }
    }
    // Called only at a validated NT bind boundary on the main thread. Mirror
    // performs the reference load/retain; no Swift offsets or private ABI calls.
    @objc(timantirecall_recordForViewModel:)
    public static func timantirecall_record(forViewModel model: AnyObject) -> AnyObject? {
        var cursor: Mirror? = Mirror(reflecting: model)
        var levels = 0
        var normalMessage = false
        var result: NSObject?
        while let mirror = cursor, levels < 16 {
            levels += 1
            let name = timantirecallTypeName(mirror)
            if name.contains("GrayTip") || name.contains("RecallNoti") { return nil }
            if timantirecallNameMatches(name, "NTAIOMessageCellViewModel") ||
               timantirecallNameMatches(name, "NTAIOChatMessageCellViewModel") {
                normalMessage = true
            }
            if timantirecallNameMatches(name, "NTAIOBaseCellViewModel") {
                for child in mirror.children.prefix(64) where child.label == "record" {
                    if result != nil { return nil }
                    result = child.value as? NSObject
                }
            }
            cursor = mirror.superclassMirror
        }
        guard normalMessage, let record = result,
              let recordClass = NSClassFromString("OCMsgRecord"), record.isKind(of: recordClass) else { return nil }
        return record
    }
}
