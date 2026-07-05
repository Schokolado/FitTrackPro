import SwiftUI

struct TestView: View {
    var body: some View {
        Text("Test")
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 24))
    }
}
