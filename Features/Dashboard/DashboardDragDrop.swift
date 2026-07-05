import SwiftUI
import UniformTypeIdentifiers

// MARK: - Jiggle Modifier

struct JiggleModifier: ViewModifier {
    var isEnabled: Bool
    
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isEnabled && isAnimating ? 1.0 : (isEnabled ? -1.0 : 0)))
            .animation(
                isEnabled ? Animation.easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default,
                value: isAnimating
            )
            .onAppear {
                if isEnabled {
                    // Random slight delay so they don't all jiggle exactly in sync
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.1)) {
                        isAnimating = true
                    }
                }
            }
            .onChange(of: isEnabled) { enabled in
                if enabled {
                    isAnimating = true
                } else {
                    isAnimating = false
                }
            }
    }
}

extension View {
    func jiggle(isEnabled: Bool) -> some View {
        self.modifier(JiggleModifier(isEnabled: isEnabled))
    }
}

// MARK: - Drop Delegate

struct DashboardDropDelegate: DropDelegate {
    let item: DashboardCardType
    @Binding var currentDraggedItem: DashboardCardType?
    var layoutManager: DashboardLayoutManager
    
    static var lastMoveTime: TimeInterval = 0
    
    func dropEntered(info: DropInfo) {
        if let current = currentDraggedItem, current != item {
            let now = Date().timeIntervalSince1970
            if now - DashboardDropDelegate.lastMoveTime < 0.3 { return }
            DashboardDropDelegate.lastMoveTime = now
            
            withAnimation(.default) {
                layoutManager.moveCard(from: current, to: item)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        currentDraggedItem = nil
        layoutManager.save()
        return true
    }
}
