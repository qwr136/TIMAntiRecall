import Foundation

@objc(TIMAntiRecallRecordBridge)
public final class TIMAntiRecallRecordBridge: NSObject {
    private static func timantirecallTypeName(_ mirror: Mirror) -> String {
        return String(reflecting: mirror.subjectType)
    }
    private static func timantirecallNameMatches(_ name: String, _ leaf: String) -> Bool {
        return name.hasSuffix("." + leaf) || name.contains("." + leaf + "<")
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
