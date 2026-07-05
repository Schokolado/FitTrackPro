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

// MARK: - Dashboard Grid Layout

struct DashboardCardSizeKey: LayoutValueKey {
    static let defaultValue: DashboardCardSize = .small
}

extension View {
    func dashboardCardSize(_ size: DashboardCardSize) -> some View {
        self.layoutValue(key: DashboardCardSizeKey.self, value: size)
    }
}

struct DashboardGridLayout: Layout {
    var spacing: CGFloat = 16
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let boundsWidth = proposal.width ?? 350
        let smallWidth = (boundsWidth - spacing) / 2
        
        var currentY: CGFloat = 0
        var currentX: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let sizeType = subview[DashboardCardSizeKey.self]
            let itemWidth = sizeType == .large ? boundsWidth : smallWidth
            
            // Wrap if it doesn't fit
            if currentX + itemWidth > boundsWidth + 1 {
                currentY += rowHeight + spacing
                currentX = 0
                rowHeight = 0
            }
            
            let itemSize = subview.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            rowHeight = max(rowHeight, itemSize.height)
            
            currentX += itemWidth + spacing
        }
        
        return CGSize(width: boundsWidth, height: currentY + rowHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let boundsWidth = bounds.width
        let smallWidth = (boundsWidth - spacing) / 2
        
        var currentY: CGFloat = bounds.minY
        var currentX: CGFloat = bounds.minX
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let sizeType = subview[DashboardCardSizeKey.self]
            let itemWidth = sizeType == .large ? boundsWidth : smallWidth
            
            if currentX + itemWidth > bounds.maxX + 1 {
                currentY += rowHeight + spacing
                currentX = bounds.minX
                rowHeight = 0
            }
            
            let pSize = ProposedViewSize(width: itemWidth, height: nil)
            let itemSize = subview.sizeThatFits(pSize)
            
            subview.place(at: CGPoint(x: currentX, y: currentY), anchor: .topLeading, proposal: pSize)
            
            rowHeight = max(rowHeight, itemSize.height)
            currentX += itemWidth + spacing
        }
    }
}
