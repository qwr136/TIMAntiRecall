import Foundation

// No @objc on record: production must read inherited Swift storage via Mirror.
class NTAIOBaseCellViewModel: NSObject {
    var record: OCMsgRecord
    init(record: OCMsgRecord) { self.record = record; super.init() }
}
class NTAIOMessageCellViewModel: NTAIOBaseCellViewModel {}
class ChatMessageCellViewModel: NTAIOMessageCellViewModel {}
class NTAIOChatMessageCellViewModel: NTAIOMessageCellViewModel {}
class NTAIOGrayTipsCellModel: ChatMessageCellViewModel {}
class RecallNotiCellViewModel: ChatMessageCellViewModel {}

private enum TIMAntiRecallInvalidTypes {
    class NTAIOBaseCellViewModel: NSObject {
        var record: NSObject?
        init(record: NSObject?) { self.record = record; super.init() }
    }
    class NTAIOMessageCellViewModel: NTAIOBaseCellViewModel {}
}

@objc(TIMAntiRecallSwiftFixture)
final class TIMAntiRecallSwiftFixture: NSObject {
    @objc(timantirecall_message:)
    static func timantirecall_message(_ record: OCMsgRecord) -> NSObject {
        ChatMessageCellViewModel(record: record)
    }
    @objc(timantirecall_ntMessage:)
    static func timantirecall_ntMessage(_ record: OCMsgRecord) -> NSObject {
        NTAIOMessageCellViewModel(record: record)
    }
    @objc(timantirecall_ntChat:)
    static func timantirecall_ntChat(_ record: OCMsgRecord) -> NSObject {
        NTAIOChatMessageCellViewModel(record: record)
    }
    @objc(timantirecall_gray:)
    static func timantirecall_gray(_ record: OCMsgRecord) -> NSObject {
        NTAIOGrayTipsCellModel(record: record)
    }
    @objc(timantirecall_recallNotice:)
    static func timantirecall_recallNotice(_ record: OCMsgRecord) -> NSObject {
        RecallNotiCellViewModel(record: record)
    }
    @objc(timantirecall_baseOnly:)
    static func timantirecall_baseOnly(_ record: OCMsgRecord) -> NSObject {
        NTAIOBaseCellViewModel(record: record)
    }
    @objc(timantirecall_invalidRecord:)
    static func timantirecall_invalidRecord(_ record: NSObject?) -> NSObject {
        TIMAntiRecallInvalidTypes.NTAIOMessageCellViewModel(record: record)
    }
}
