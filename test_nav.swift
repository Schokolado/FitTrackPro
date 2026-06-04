import SwiftUI

struct TestView: View {
    @State private var openId: String = ""
    var body: some View {
        NavigationStack {
            VStack {
                Button("Open") { openId = "123" }
            }
            .navigationDestination(isPresented: Binding(
                get: { !openId.isEmpty },
                set: { if !$0 { openId = "" } }
            )) {
                Text("Detail \(openId)")
            }
        }
    }
}
