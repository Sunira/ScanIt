import SwiftUI

/// The floating teal button that starts a scan.
struct ScanButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "viewfinder")
                .font(.system(size: 26, weight: .semibold))
                .frame(width: Metrics.scanButtonSize, height: Metrics.scanButtonSize)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Scan a document")
    }
}

#Preview {
    ScanButton {}
}
