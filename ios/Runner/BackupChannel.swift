import Flutter
import UIKit

class BackupChannel: NSObject, UIDocumentPickerDelegate {
    private let channelName = "app.backup"
    private var result: FlutterResult?
    private var dbPath: String?
    private var mode: String? // "export" or "import"

    // Resolved when needed: with the UIScene lifecycle, no window exists yet
    // when the channel is created.
    private var presenter: UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.windows.first { $0.isKeyWindow }?.rootViewController
    }

    init(messenger: FlutterBinaryMessenger) {
        super.init()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard self.result == nil else {
            result(FlutterError(code: "BUSY", message: "Another operation in progress", details: nil))
            return
        }
        switch call.method {
        case "exportDb":
            guard let args = call.arguments as? [String: Any], let path = args["dbPath"] as? String else {
                result(FlutterError(code: "ARGS", message: "Missing dbPath", details: nil))
                return
            }
            self.dbPath = path
            self.mode = "export"
            self.result = result
            let suggestedName = args["suggestedName"] as? String ?? "ltc_backup.db"
            let picker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                // Only allow file export, not folder selection
                picker = UIDocumentPickerViewController(forExporting: [URL(fileURLWithPath: path)], asCopy: true)
                picker.shouldShowFileExtensions = true
            } else {
                picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .exportToService)
            }
            picker.allowsMultipleSelection = false
            picker.delegate = self
            picker.modalPresentationStyle = .formSheet
            presenter?.present(picker, animated: true, completion: nil)
        case "importDb":
            guard let args = call.arguments as? [String: Any], let path = args["dbPath"] as? String else {
                result(FlutterError(code: "ARGS", message: "Missing dbPath", details: nil))
                return
            }
            self.dbPath = path
            self.mode = "import"
            self.result = result
            let picker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
            } else {
                picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
            }
            picker.allowsMultipleSelection = false
            picker.delegate = self
            picker.modalPresentationStyle = .formSheet
            presenter?.present(picker, animated: true, completion: nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishWithError(FlutterError(code: "CANCELLED", message: "User cancelled", details: nil))
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let mode = self.mode, let dbPath = self.dbPath else {
            finishWithError(FlutterError(code: "NO_URL", message: "No URL or state", details: nil))
            return
        }
        do {
            if mode == "export" {
                // If user picked a folder, write inside it; if a file, overwrite it.
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    let dest = url.appendingPathComponent("ltc_backup.db")
                    let data = try Data(contentsOf: URL(fileURLWithPath: dbPath))
                    try data.write(to: dest, options: .atomic)
                    finishWithSuccess(true)
                } else {
                    let data = try Data(contentsOf: URL(fileURLWithPath: dbPath))
                    try data.write(to: url, options: .atomic)
                    finishWithSuccess(true)
                }
            } else {
                let data = try Data(contentsOf: url)
                try data.write(to: URL(fileURLWithPath: dbPath), options: .atomic)
                finishWithSuccess(true)
            }
        } catch {
            finishWithError(FlutterError(code: "IO", message: error.localizedDescription, details: nil))
        }
    }

    private func finishWithSuccess(_ value: Any?) {
        result?(value)
        cleanup()
    }

    private func finishWithError(_ error: FlutterError) {
        result?(error)
        cleanup()
    }

    private func cleanup() {
        result = nil
        dbPath = nil
        mode = nil
    }
}
