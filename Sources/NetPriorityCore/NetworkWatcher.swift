import Foundation
import SystemConfiguration

public final class NetworkWatcher {
    private var store: SCDynamicStore?
    private let queue = DispatchQueue(label: "io.github.wmwgz.netpriority.watcher")
    private var debounceWorkItem: DispatchWorkItem?
    private let onChange: () -> Void

    public init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    public func start() {
        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: SCDynamicStoreCallBack = { _, _, info in
            guard let info else { return }
            let watcher = Unmanaged<NetworkWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.scheduleNotify()
        }

        guard let created = SCDynamicStoreCreate(nil, "io.github.wmwgz.netpriority.watcher" as CFString, callback, &context) else {
            return
        }
        store = created

        let keys = [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6",
            "Setup:/Network/Global/IPv4"
        ] as CFArray

        let patterns = [
            "State:/Network/Interface/.*/IPv4",
            "State:/Network/Interface/.*/Link",
            "Setup:/Network/Service/.*/IPv4"
        ] as CFArray

        SCDynamicStoreSetNotificationKeys(created, keys, patterns)
        SCDynamicStoreSetDispatchQueue(created, queue)
    }

    public func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        if let store {
            SCDynamicStoreSetDispatchQueue(store, nil)
        }
        store = nil
    }

    private func scheduleNotify() {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.onChange()
            }
        }
        debounceWorkItem = item
        queue.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    deinit {
        stop()
    }
}
